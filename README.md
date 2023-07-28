# Ardumatic

[![Build Status](https://drone.harton.nz/api/badges/james/ardumatic/status.svg?ref=refs/heads/main)](https://drone.harton.nz/james/ardumatic)

Ardumatic is a small forward and inverse kinematics library suitable for use
inside Ardupilot.

It uses the [FABRIK](https://doi.org/10.1016/j.gmod.2011.05.003) algorithm to
get quickly generate inverse kinematic solutions.

# TODO
 - ~~Implement FABRIK solver~~
 - Enable joint constraints when solving
 - Add keep-out zones and colission avoidance
 - Implement gait generator for n-legged robots

# Thanks to

This package couldn't exist without all the great people whose code I was able to read to get my head around what I was trying to do.

 - [@jmsjr](https://github.com/jmsjr) and [@alansley](https://github.com/alansley) for [caliko](https://github.com/FedUni/caliko).
 - [@TheComet](https://github.com/TheComet) for [ik](https://github.com/TheComet/ik)
 - [@EgoMoose](https://github.com/EgoMoose) for [FABRIK (inverse kinematics)](https://www.youtube.com/watch?v=UNoX65PRehA) and the [related Roblox code](https://github.com/EgoMooseOldProjects/ExampleDump/blob/master/Places/Inverse%20kinematics.rbxl)
 - All the amazing folks behind the [ArduPilot project](https://github.com/ArduPilot/ardupilot).

# License

This code is licensed under the terms of the Hippocratic License Version 2.1 as
outlined in the LICENSE file.
