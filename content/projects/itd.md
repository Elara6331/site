+++
title = "ITD"
date = "2022-09-13"
summary = "Linux companion daemon for the PineTime smartwatch"
weight = 30
+++

[ITD](https://gitea.arsenm.dev/Arsen6331/itd) (short for [InfiniTime](https://github.com/InfiniTimeOrg/InfiniTime) Daemon) is my biggest and most-used project so far. It is a companion daemon that runs on Linux for the PineTime smartwatch. This means it the same thing as the Watch app on iOS, but on Linux instead of iOS and for the PineTime instead of the Apple Watch.

It runs in the background, managing Bluetooth communication with the watch. When it starts, it exposes a UNIX socket where it accepts API requests from the frontends I've built. I have a CLI frontend called `itctl` and a GUI frontend called `itgui`.

ITD implements all features exposed by the InfiniTime firmware, and even some that are not out yet or have no frontend on the watch. The only feature not implemented is navigation, which I skipped because there is no standard for it on Linux.

I've worked with developers of the InfiniTime firmware to design and add new features to the firmware, and to ITD. Developers of the firmware have also used ITD to test new features they were implementing.

My companion is mentioned in many places, including the InfiniTime README, Pine64's wiki pages for PineTime, and several blog posts from Pine64 (the manufacturer of the PineTime).

Recently, thanks to the amazing [GoReleaser](https://github.com/goreleaser/goreleaser), I have begun releasing Linux packages such as `.deb`, `.rpm`, and `.apk` (Alpine Linux, not Android) automatically whenever a new release is created.

This project combines a lot of my knowledge into a single project. It uses SQLite to store metrics such as step count, heart rate, etc., it uses Bluetooth Low-Energy to communicate with the watch, DBus to communicate with the Bluetooth daemon, UNIX sockets for Inter-Process Communication between the frontends and the daemon, it even uses a custom RPC library I built specifically for it.