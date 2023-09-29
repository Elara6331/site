+++
title = "Running HashiCorp Nomad and Consul on RISC-V"
date = "2023-08-04"
summary = "Discussing the process of getting Nomad and Consul running on a RISC-V computer and adding it to a cluster"
tags = ["pine64", "star64", "risc-v", "cluster"]
+++

I run a cluster of single board computer servers from my house. It mostly consists of `aarch64` machines with a few old `x86_64` machines I had lying around for the occasional service that doesn't run on ARM.

I've been interested in RISC-V for a while. I love the fact that it's an open ISA unlike x86 and ARM. I believe RISC-V has a lot of potential and I've wanted to develop software for it for a while.

Unfortunately, up until pretty recently, there hasn't been very much useful RISC-V hardware to use that wasn't prohibitively expensive. However, there has recently been a wave of new RISC-V SBCs, so I decided to try adding one to my cluster.

I decided to go with the [Star64](https://wiki.pine64.org/wiki/STAR64) from Pine64, mainly because I'm familiar with Pine64 and I'm already part of their developer community with my ITD project. I also wanted to play around with some of the features it has that other JH7110 boards don't, such as the built-in WiFi and Bluetooth and the PCIe slot.

## Getting things ready

My cluster runs [Nomad](https://www.nomadproject.io/) and [Consul](https://www.consul.io/) with the Docker driver, which means Nomad, Consul, and Docker must be installed on all nodes. That's usually pretty simple with Hashicorp's and Docker's APT repo, but their repos don't have any builds for `riscv64`. That's a pretty common occurence because of how new Linux on RISC-V is. Unfortunately, that means I'll have to build each of those projects from source or find them elsewhere.

Before that though, I have to choose a distro to run. Looking at the [Software Releases section](https://wiki.pine64.org/wiki/STAR64#Software_releases) in Pine64's wiki, there aren't very many options. As of the time of writing this article, the only options on the page are Yocto-based images, Armbian, and NixOS. Since all my nodes run Debian, I wanted to go with a Debian-based image, so I looked at Armbian. Unfortunately, it doesn't have a maintainer at the moment and the images are broken. Out of the two remaining options, I chose to go with the Yocto images instead of NixOS because they use `apt` like Debian, so I wouldn't have to use different package management commands for all my servers.

While I waited for my Star64 to arrive, I got excited and decided to work on getting Nomad and Consul ready for it early.

### Consul

I started with Consul because its docs have [instructions](https://developer.hashicorp.com/consul/docs/install#compiling-from-source) for cross-compiling and it seems to only require setting the `GOOS` and `GOARCH` environment variables.

So, I cloned the consul repo and ran

```bash
make GOOS=linux GOARCH=riscv64 dev
```

It downloaded some dependencies and started building, but eventually it returned some errors:

```text
# github.com/boltdb/bolt
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/db.go:101:13: undefined array length maxMapSize or missing type constraint
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/db.go:317:12: undefined: maxMapSize
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/db.go:335:10: undefined: maxMapSize
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/db.go:336:8: undefined: maxMapSize
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/db.go:795:2: pos declared and not used
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/bolt_unix.go:62:15: undefined array length maxMapSize or missing type constraint
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/bucket.go:135:15: undefined: brokenUnaligned
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/freelist.go:166:2: idx declared and not used
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/freelist.go:169:19: undefined array length maxAllocSize or missing type constraint
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/freelist.go:176:14: undefined array length maxAllocSize or missing type constraint
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/freelist.go:166:2: too many errors
make: *** [Makefile:163: dev-build] Error 1
```

The first thing I noticed is that these errors are for the `github.com/boltdb/bolt` package, which is unmaintained and doesn't have support for `riscv64`. However, Consul switched to a maintained fork with RISC-V support a while ago, so it was another dependency causing problems. I used `go mod why github.com/boltdb/bolt` to identify the culprit, which led me to `github.com/hashicorp/raft-boltdb`, so I went to its repo and it also switched to the maintained fork, but it still depended on boltdb in order to migrate old bolt databases to the new format. I submitted a [pull request](https://github.com/hashicorp/raft-boltdb/pull/37) to disable that functionality on unsupported platforms.

As of the time I'm writing this, the PR isn't merged yet, so I had to force Consul to use my fork. I did that by adding this replace directive to Consul's `go.mod` file, under the `go 1.20` directive:

```text
replace github.com/hashicorp/raft-boltdb/v2 => github.com/Elara6331/raft-boltdb/v2 v2.0.0-20230729002801-1a3bff1d87a7
```

Then I ran the make command again, and this time it compiled successfully, but I got a different error:

```text
cp: cannot stat '/home/elara/.go/bin/consul': No such file or directory
```

I noticed that Consul's makefile ran `go install` and then copied the resulting binary to the destination rather than just writing it directly to the destination. This is the command it ran:

```bash
CGO_ENABLED=0 go install -ldflags "-X github.com/hashicorp/consul/version.GitCommit=449e050741+CHANGES -X github.com/hashicorp/consul/version.BuildDate=2023-07-28T16:49:23Z " -tags ""
```

So, I decided to modify that command so that it would build the binary instead of installing it, which resulted in the following command:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=riscv64 go build -ldflags "-X github.com/hashicorp/consul/version.GitCommit=449e050741+CHANGES -X github.com/hashicorp/consul/version.BuildDate=2023-07-28T16:49:23Z " -tags "" -o ./bin/consul
```

Once that command completed, I looked in the `bin` directory and found a successfully-built RISC-V Consul binary.

Since I don't have my star64 yet, I had to test the binary using CPU emulation, so I used `qemu-user-static` and ran `./bin/consul version`, which returned:

```text
Consul v1.17.0-dev
Revision 449e050741+CHANGES
Build Date 2023-07-28T16:49:23Z
Protocol 2 spoken by default, understands 2 to 3 (agent will automatically use protocol >2 when speaking to compatible agents)
```

That means the binary is working properly!

### Nomad

Nomad can be cross-compiled as well, but it doesn't include any insructions in its documentation.

I cloned the nomad repo and followed the regular build instructions but with the `GOOS` and `GOARCH` variable set to target `riscv64`.

First, I ran the command that installs all the build depenedencies:

```bash
make GOOS=linux GOARCH=riscv64 bootstrap
```

That worked, so I moved on to the build command:

```bash
make GOOS=linux GOARCH=riscv64 dev 
```

After a while though, I got some errors:

```text
# runtime/cgo
gcc_riscv64.S: Assembler messages:
gcc_riscv64.S:17: Error: no such instruction: `sd x1,-200(sp)'
gcc_riscv64.S:18: Error: no such instruction: `addi sp,sp,-200'
...
```

These errors are from the assembler, and they indicate that Go tried to use the wrong C compiler for the target platform. This happened because Nomad has some C dependencies for things like process monitoring. It's pretty easily fixed though, I just needed to install a RISC-V cross-compiler and point Go to it. I run Arch Linux, so I just installed the [`riscv64-linux-gnu-gcc`](https://archlinux.org/packages/extra/x86_64/riscv64-linux-gnu-gcc/) package and then changed the command to point Go to it, like so:

```bash
make GOOS=linux GOARCH=riscv64 CC=/usr/bin/riscv64-linux-gnu-gcc CXX=/usr/bin/riscv64-linux-gnu-c++ AR=/usr/bin/riscv64-linux-gnu-gcc-ar dev
```

When I ran that though, I got some more errors:

```text
# github.com/boltdb/bolt
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/db.go:101:13: undefined array length maxMapSize or missing type constraint
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/db.go:317:12: undefined: maxMapSize
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/db.go:335:10: undefined: maxMapSize
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/db.go:336:8: undefined: maxMapSize
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/db.go:795:2: pos declared and not used
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/bolt_unix.go:62:15: undefined array length maxMapSize or missing type constraint
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/bucket.go:135:15: undefined: brokenUnaligned
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/freelist.go:166:2: idx declared and not used
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/freelist.go:169:19: undefined array length maxAllocSize or missing type constraint
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/freelist.go:176:14: undefined array length maxAllocSize or missing type constraint
../../../.go/pkg/mod/github.com/boltdb/bolt@v1.3.1/freelist.go:166:2: too many errors
make[1]: *** [GNUmakefile:93: pkg/linux_riscv64/nomad] Error 1
make: *** [GNUmakefile:262: dev] Error 2
```

These are the same errors consul returned for the boltdb package, so I just added the same replace directive and ran it again, and this time it built successfully!

I tried running it like I did with consul, using `qemu-user-static` for CPU emulation, but I got the following error:

```text
$ ./bin/nomad version
qemu-riscv64-static: Could not open '/lib/ld-linux-riscv64-lp64d.so.1': No such file or directory
```

This error indicates that the binary tried to load a `riscv64` linker library, but qemu couldn't find it. That's because Arch's `riscv64-linux-gnu-glibc` package installs the linker to `/usr/riscv64-linux-gnu/lib` rather than the usual `/lib`. So, to fix that, I just told qemu where to find the linker, and the binary worked!

```text
$ QEMU_LD_PREFIX=/usr/riscv64-linux-gnu/ ./bin/nomad version
Nomad v1.6.2-dev
BuildDate 2023-07-28T18:53:32Z
Revision 9e98d694a6230b904f931813b7d53622e9f128c9+CHANGES
```

### Docker

Luckily, someone else has already successfully run Docker on RISC-V and they've documented the process in their [github repo](https://github.com/carlosedp/riscv-bringup). They even provided a `.tar.gz` archive in the releases, which means I won't have to spend time getting Docker to build (thanks [@carlosedp](https://github.com/carlosedp)!).

## Running the stuff I just set up

It's been about a week and my Star64 is finally here. Now that everything is ready, it's time for the interesting part: actually running all of this on the node and seeing if it can properly join my cluster.

### Consul

Starting with Consul, I used `scp` to copy the binary I built to the `/usr/bin` directory on my Star64. Then, I copied the systemd services and configs in `.release/linux/package` to their corresponding directories and created a system user for consul using `useradd -r consul`.

I edited the configs to match the rest of my cluster and started consul with `sudo systemctl start consul`. A few seconds later, I saw this in my Consul dashboard:

![Screenshot of Star64 in Consul dashboard](/img/consul_star64.png)

which means Consul is working!

### Nomad

Just like with Consul, I used `scp` to copy the relevant files to the Star64, edited the configs, and started the Nomad service. Nomad doesn't need its own user, so no `useradd` was required.

A few seconds later, the Star64 joined the cluster and appeared in my dashboard!

![Screenshot of Star64 in Nomad dashboard](/img/nomad_star64.png)


### Docker

Docker is going to be more complex to install. I started similarly to Consul and Nomad: I downloaded the `.tar.gz`, extracted it, copied all the files inside to their proper locations, and added a group for it using `groupadd -r docker`. However, when I tried to start docker, I got some errors about my kernel's cgroup support, so I decided to check whether my kernel had the proper config options enabled for Docker.

To do that, I downloaded moby's [check-config.sh](https://github.com/moby/moby/blob/master/contrib/check-config.sh) script, which checks your kernel config to make sure it supports docker. I found that several required options were missing. That meant I had to compile a custom kernel, so I looked into how Yocto worked and built a new kernel. I won't get into that process here because it could be a whole separate article, but anyway, eventually I had some `.deb` packages with the new kernel. I installed those, rebooted, ran the script again, and this time, all the required options were enabled.

So now, I tried starting docker again and this time there was no error, so I tested it by running the `hello-world` container, and sure enough, it worked!

```text
root@star64:~/docker# docker run hello-world

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (riscv64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```

I've opened an [issue](https://github.com/Fishwaldo/meta-pine64/issues/13) for this and published the modified kernel packages [here](https://api.minio.elara.ws/risc-v/star64-kernel-debs.tar.gz) if anyone wants to try them.

## Using the node for something

Now that I've got the node added to my cluster, it's time to actually make it run a task. I'm going to be running a [Woodpecker CI](https://woodpecker-ci.org) agent on it so that I can test and build my software on RISC-V hardware.

### Setting up Woodpecker

Luckily, woodpecker's official [server](https://hub.docker.com/r/woodpeckerci/woodpecker-server) and [agent](https://hub.docker.com/r/woodpeckerci/woodpecker-agent) images both support RISC-V, so I don't need to change anything there. All I should need to do is add `woodpecker_agent = true` to my Nomad config file and restart Nomad, and it should start right up.

Sure enough, once I added the variable and restarted Nomad, Woodpecker Agent started immediately:

![Screenshot of Woodpecker Agent running on the Star64](/img/woodpecker-agent-star64.png)

### Running a CI job

Now that Woodpecker is running, I'm going to try running a CI job on it.

The job I'm going to run is the test job for my [pcre](https://gitea.elara.ws/Elara6331/pcre) library because it supports RISC-V and I'd like to try running its unit tests on actual RISC-V hardware.

My CI job is configured to run tests for `amd64` and `arm64`, so just add `riscv64` and it should work, right? Well, not quite. That job is using the official Go [docker image](https://hub.docker.com/_/golang) which doesn't have support for RISC-V, so I have to make my own image.

In order to do that, I made a new repo at [Elara6331/riscv-docker](https://gitea.elara.ws/Elara6331/riscv-docker) and added a custom dockerfile for Go that's based on the `alpine:edge` image, which does support RISC-V, and published the resulting image at [gitea.elara.ws/elara6331/golang](https://gitea.elara.ws/Elara6331/-/packages/container/golang/latest).

Then, I modified my CI config to run `riscv64` tests using the new image and pushed it. Here's the result:

![Screenshot of Woodpecker running a test job for PCRE on RISC-V](/img/woodpecker-riscv64-pcre.png)

The job runs successfully! You can see this result on my Woodpecker instance: https://ci.elara.ws/repos/49/pipeline/5.

That's pretty much it for this article, but I'm going to be doing lots of interesting stuff with this in the future and I'll be publishing more articles whenever I encounter anything interesting.