+++
title = "Nordic DFU over BLE"
date = "2023-07-14"
summary = "Using Nordic Semiconductor's DFU protocol over Bluetooth Low Energy"
tags = ["pine64", "pinetime", "ble", "itd"]
+++

I maintain a project called [ITD](https://gitea.elara.ws/Elara6331/itd), a companion app for Pine64's [PineTime](https://www.pine64.org/pinetime/) smartwatch. The PineTime uses a Nordic nRF52832 SoC and implements the Nordic DFU protocol. I found the documentation for this protocol on Nordic's site to be severely lacking and had to resort to digging through source code to implement it properly. In this article, I'll explain exactly how to upgrade your firmware over BLE using the information that I've learned.

## Concepts

### Control Point characteristic

All DFU commands will be written to the control point characteristic. Responses will be received as notifications. The ID of the control point characteristic is `00001531-1212-efde-1523-785feabcd123`.

### Packet characteristic

The packet characteristic is where the data for the firmware upgrade will be sent, such as the initialization packet and the firmware image itself. The ID of the packet characteristic is `00001532-1212-efde-1523-785feabcd123`

### Segment Size and Receipt Interval

The segment size is the size of each firmware packet sent to the packet characteristic. The receipt interval is the amount of packets that will be sent before a receipt packet is returned. The maximum segment size is 20 bytes, and the optimal receipt interval has been experimentally determined to be 10.

### Receipt Packet

Every time the receipt interval is reached, a receipt packet is sent as a notification on the control point characteristic. This packet always starts with an opcode (`0x11`), followed by a little-endian uint32 encoding the total size in bytes of the firmware image that has been received. You can compare this with the amount of bytes you've sent to make sure that no packets have been lost.

## Upgrade Process

All integers used in the process will be encoded little-endian

### Preparation

To prepare for a firmware upgrade, start by enabling notifications on the control point characteristic so that you can receive responses from the device you're upgrading.

### Initialization

To start the firmware upgrade, write the start command (`[0x01 0x04]`) to the control point.

Next, you'll need to write the size of the firmware image in bytes to the *packet characteristic*. The size packet includes three sizes: one for the SoftDevice, one for the bootloader, and one for the firmware. Since we're just upgrading the firmware in this case, we only need to worry about the last number and the rest can be set to 0. Each size is a uint32. That means the packet should contain 8 zeros followed by 4 bytes encoding the size of the firmware. For example, if your firmware image is 412488 bytes, your size packet might look like this:

```
[0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0xB8 0x62 0x06 0x00]
```

Once the size packet has been sent, wait for your device to send the successful start response (`[0x10 0x01 0x01]`) as a notification on the control point.

Once the start response has been received, you'll need to send the initialization packet. This should be included in a DFU zip package as a `.dat` file. Start by writing `[0x02 0x00]` to the control point, which tells your device that you're about to write the init packet. Then, write the contents of the init packet to the *packet characteristic*, and then write `[0x02 0x01]` to the control point, which signals that you've finished writing the packet. Now, you'll need to wait for the device to process the init packet and send back `[0x10 0x02 0x01]`, indicating that the packet was accepted.

Next, set the receipt interval by writing `[0x08 <interval>]` to the control point. If you use the optimal interval mentioned in this article (10), your command will be `[0x08 0x0A]`.

Your device should now be ready to receive the new firmware!

### Flashing the firmware

Start by writing `[0x03]` to the control point, which tells your device that you're about to send the firmware image.

Now comes the interesting part: actually sending the firmware image. Split the image into 20-byte chunks and write each chunk one at a time to the *packet characteristic*. Every time you write 10 packets (or whatever you've set your receipt interval to), wait for the device to process them and send back a notification starting with `0x11` on the control point. That notification is a receipt packet. Verify that the size it returns matches the amount of bytes you've sent. If it does, you can continue writing more packets. If not, some packets were lost and you'll need to restart the process.

Once you've finished sending the firmware image, wait for the watch to send `[0x10 0x03 0x01]` on the control point. That indicates that the firmware has been received successfully.

### Finishing

Once the firmware has been successfully received, you'll need to activate it and reset the device.

First, write `[0x04]` to the control point. This tells your device to validate the firmware and make sure it matches the CRC in the init packet. If this is successful, you should receive `[0x10 0x04 0x01]` from the control point.

Once the firmware is successfully validated, write `[0x05]` to the control point, which tells your device to activate the new firmware and reset.

That's it! Your device should reboot running the new firmware. Some firmware (such as InfiniTime for the PineTime) requires you to manually validate the firmware in their settings or they'll revert on the next reboot, so make sure to remember to do that if your device requires it.
