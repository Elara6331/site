+++
title = "Experimenting with the Milk-V Duo RISC-V Single Board Computer"
date = "2023-12-12"
summary = "My experiments with the Milk-V Duo and how I wrote a Linux GPIO library in Zig"
tags = ["milk-v", "duo", "risc-v", "zig"]
+++

## Introduction

I recently got a few [Milk-V Duo](https://milkv.io/duo) boards to play with and thought I'd share my experience with them here.

The boards have a similar form factor to the Raspberry Pi Pico, but they run a full Linux distribution rather than custom firmware like the pico.

The first thing I wanted to try was using the GPIO pins just like you would on a pico or any microcontroller. The way Milk-V expects you to do this is using their modified version of the `wiringX` library, which directly writes to memory mapped registers.

That's not the recommended way to access GPIO on Linux because it's error-prone and insecure. Instead, Linux provides special interfaces to control GPIO.

There's the deprecated sysfs interface which you use by writing text to files in `/sys`, for example, `echo 440 > /sys/class/gpio/export` would allow you to access pin 440. This interface has several problems. For one, there's no way to know if a program is currently using the pin, so you could end up with two programs trying to control the same pin. Also, when the programs finish, they have to manually unexport the pins, and if they don't, they'll stay exported even after the program exits.

That problem was solved by the character device interface. Linux provides character device files at `/dev/gpiochipX`, on which you can use special `ioctl` commands, in order to control the GPIO pins. Once a program closes the file or exits, Linux automatically releases all the GPIO lines it was using.

Later, it was decided that the API was inadequate, so there's a v2 character device API, which is what I wanted to use. The recommended way to do that is using `libgpiod`, which is a C library that invokes the various syscalls for you and provides a clean API.

However, that didn't sound fun. I'd just be importing a C library, and besides, I was really bored of using C and wanted to learn a new low-level language, like [Zig](https://ziglang.org/). So, I decided that in order to learn Zig, I'd implement a GPIO library in it as my first project. A bit complicated for a first project, but very fun.

## Writing the GPIO library

I started by searching for examples of using the character device API. Unfortunately, what little information I could find was for the deprecated v1 API which, to be fair, still works, but I wanted to use the v2 API, so I decided to read the kernel's source code to figure out how these ioctls worked. Specifically, I found the [`gpio.h`](https://github.com/torvalds/linux/blob/v5.10/include/uapi/linux/gpio.h#L500) file in Linux kernel 5.10 (the first version that implements the v2 API).

That file has very good descriptions of what the various structs and fields are meant to be used for, but it doesn't provide any actual examples of how to use the API. I decided to just try it anyway.

I started by rewriting each struct as a Zig `extern` struct. In the process, I learned a lot of interesting stuff about Zig, such as `packed` structs, for example, which make bit sets really easy to implement because each `bool` is stored as one bit, so you can just have a struct of `bool` fields that will act as a bit set.

I also learned a lot about Zig's type system as I had to do things like accept an unknown number of offsets to request from the chip, use enums, unions, etc.

Eventually, I finished that and started implementing the actual syscalls. The kernel represents ioctls as macros, such as `_IOWR(0xB4, 0x05, struct gpio_v2_line_info)`. This macro contains the ioctl type (`0xB4`), the ioctl number (`0x05`), and the type which gets sent or received (`struct gpio_v2_line_info`). The kernel uses all of these in order to calculate an ioctl ID that you use when running the syscall.

Zig provides functions to do the same thing. For example, the `_IOWR` macro above becomes `std.os.linux.IOCTL.IOWR(0xB4, 0x05, LineInfo)`. I used that to implement each of the ioctls implemented by the gpio interface.

Doing this gave me a low-level base upon which I could build my public API.

However, I later found out that I misinterpreted the API. Requesting GPIO lines requires offsets, while operations on GPIO lines, such as setting the values or config, requires indices. An index corresponds to the index of the offset in the request. For example, if you request the offsets `[22 20 21]`, then `22` will be `0`, `20` will be `1`, and `21` will be `2`.

Because I didn't realize this, my GPIO library wasn't working, so I decided to compile a Go program using the [gpiod library](https://github.com/warthog618/gpiod) and then used `strace` to analyze the syscalls it made and see how they were different from mine. That's when I noticed that it was using indices rather than offsets. Once I fixed that, my library finally started working, so I finished writing it, set up zig package manager so it could be used by others, and published it.

Here are the links to my Zig GPIO library:

- Gitea: https://gitea.elara.ws/Elara6331/zig-gpio
- GitHub: https://github.com/Elara6331/zig-gpio

## Using `zig-gpio` with the Milk-V Duo

The first thing I wanted to try was to make the Duo's LED blink, which is like the "Hello World" of GPIO projects.

To do that, I needed to know which chip controlled the LED and what offset it was at. Unfortunately, there's no documentation for that. However, there is an example script that uses the deprecated sysfs interface to blink the LED. That script uses pin `440` as the LED, which I correlated with `gpiochip` values in sysfs to determine that the LED was offset 22 on `/dev/gpiochip2`.

I tried it, and it worked! The LED was blinking using entirely my code, which made me really excited. (I'm probably the only person in the world who gets excited over a blinking LED)

So now I needed the rest of the GPIO offsets so I could do some more testing

### Finding the Milk-V Duo GPIO offsets

Since Milk-V doesn't provide any documentation about the offsets, I had to look further. I found the [GPIO Operation Guide](https://doc.sophgo.com/cvitek-develop-docs/master/docs_latest_release/CV180x_CV181x/en/01.software/OSDRV/Peripheral_Driver_Operation_Guide/build/html/7_GPIO_Operation_Guide.html) from the manufacturer of the chip that the Duo used, which let me know how to figure out the GPIO offsets and which chip they belong to.

To do that, I had to look at the Duo's [schematic](https://github.com/milkv-duo/duo-files/blob/main/hardware/duo/duo-schematic-v1.2.pdf), which had the prefixes `GPIO`, `GPIOA`, `GPIOC`, and `PWR_GPIO`.

I assumed `GPIOA` would correspond to `gpiochip0`, so I tried it with offset 28, which corresponds to `GP0` on the official Duo pinout. Sure enough, my multimeter showed that it was blinking.

Next, I assumed that `GPIOC` would correspond to `gpiochip2` (since `C` is the third letter), and tried that, and it worked again!

Since 0 and 2 are known, I assumed `GPIO` with no letter would be `gpiochip1`. However, when I tried it, nothing happened, so I decided to check `gpiochip4`, and that did work. It turns out `PWR_GPIO` is also `gpiochip4`, so I'm not sure why there's a difference in the naming.

Anyway, I used this to calculate all the GPIO offsets, which I'll provide below for anyone who wants to use them.

### GPIO offset table

| Pin Name 	 | Offset | Chip      |
|------------|--------|-----------|
| GP0      	 | 28     | gpiochip0 |
| GP1      	 | 29     | gpiochip0 |
| GP2      	 | 26     | gpiochip4 |
| GP3      	 | 25     | gpiochip4 |
| GP4      	 | 19     | gpiochip4 |
| GP5      	 | 20     | gpiochip4 |
| GP6      	 | 23     | gpiochip4 |
| GP7      	 | 22     | gpiochip4 |
| GP8      	 | 21     | gpiochip4 |
| GP9      	 | 18     | gpiochip4 |
| GP10     	 | 9      | gpiochip2 |
| GP11     	 | 10     | gpiochip2 |
| GP12     	 | 16     | gpiochip0 |
| GP13     	 | 17     | gpiochip0 |
| GP14     	 | 14     | gpiochip0 |
| GP15     	 | 15     | gpiochip0 |
| GP16     	 | 23     | gpiochip0 |
| GP17     	 | 24     | gpiochip0 |
| GP18     	 | 22     | gpiochip0 |
| GP19     	 | 25     | gpiochip0 |
| GP20     	 | 27     | gpiochip0 |
| GP21     	 | 26     | gpiochip0 |
| GP22     	 | 4      | gpiochip4 |
| GP25 (LED) | 22     | gpiochip2 |

## Conclusion

The Milk-V Duo is a really fun board to play with, and I encourage anyone who's interested in Linux and embedded programming to get one and try it out. You'll probably learn a lot and it'll be a lot of fun!

They cost only $9, and you can usually find them for as low as $5. All you need is a USB-C cable and a microSD card. No serial adapter or debugger is required (though a serial adapter is nice to have for troubleshooting boot issues).