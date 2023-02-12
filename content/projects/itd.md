+++
title = "ITD"
date = "2022-09-13"
summary = "Linux companion daemon for the PineTime smartwatch"
weight = 30
+++

# ITD - InfiniTime Daemon

[ITD](https://gitea.arsenm.dev/Arsen6331/itd), short for InfiniTime Daemon, is one of my biggest and most-used projects. It's a companion daemon for the PineTime smartwatch on Linux, functioning similarly to the Watch app on iOS, but on Linux and for the PineTime instead of the Apple Watch.

The daemon runs in the background and manages Bluetooth communication with the watch. Upon startup, it exposes a UNIX socket to accept API requests from the frontends, including `itctl` (a CLI frontend) and `itgui` (a GUI frontend).

ITD implements all features exposed by the InfiniTime firmware, including some not yet available or without frontends on the watch.

I've collaborated with InfiniTime firmware developers to design and add new features to both the firmware and ITD, and they've also used ITD to test new features they were implementing. ITD is mentioned in various places, such as the InfiniTime README, Pine64's wiki pages for PineTime, and blog posts from Pine64 (the manufacturer of the PineTime).

This project showcases a lot of my knowledge, utilizing SQLite for storing metrics (e.g., step count, heart rate), Bluetooth Low-Energy for communication with the watch, DBus for communication with the Bluetooth daemon and various other system components, UNIX sockets for Inter-Process Communication between frontends and the daemon, and several REST APIs to get information such as weather and location.
