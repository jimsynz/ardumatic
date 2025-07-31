# Ardumatic

[![Build Status](https://drone.harton.dev/api/badges/james/ardumatic/status.svg?ref=refs/heads/main)](https://drone.harton.dev/james/ardumatic)
[![Hippocratic License HL3-FULL](https://img.shields.io/static/v1?label=Hippocratic%20License&message=HL3-FULL&labelColor=5e2751&color=bc8c3d)](https://firstdonoharm.dev/version/3/0/full.html)

Ardumatic is a small forward and inverse kinematics library suitable for use
inside Ardupilot.

It uses the [FABRIK](https://doi.org/10.1016/j.gmod.2011.05.003) algorithm to
get quickly generate inverse kinematic solutions.

## Testing

Ardumatic includes comprehensive testing for both standalone functionality and ArduPilot integration:

### Unit Tests
```bash
# Run Lua unit tests
busted
```

### SITL Integration Tests
Test the kinematic solver within ArduPilot's Software-in-the-Loop simulator:

```bash
# Run SITL integration tests
ARDUPILOT_PATH=/path/to/ardupilot ./tools/run_sitl_tests.sh
```

For detailed SITL testing information, see [SITL_TESTING.md](SITL_TESTING.md).

### All Tests
```bash
# Run unit tests
busted

# Run SITL integration tests
ARDUPILOT_PATH=/path/to/ardupilot ./tools/run_sitl_tests.sh
```

## Development

### Prerequisites
- Lua 5.1+ (ArduPilot compatible)
- Busted (for unit testing)
- Python 3.6+ (for SITL testing)
- ArduPilot source code (for SITL testing)

### Quick Start
```bash
# Install dependencies
luarocks install --deps-only

# Run unit tests
busted

# Run SITL integration tests (requires ArduPilot)
ARDUPILOT_PATH=/path/to/ardupilot ./tools/run_sitl_tests.sh

# Lint code
luacheck src/
```

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

## Github Mirror

This repository is mirrored [on Github](https://github.com/jimsynz/ardumatic)
from it's primary location [on my Forgejo instance](https://harton.dev/james/ardumatic).
Feel free to raise issues and open PRs on Github.

## License

This software is licensed under the terms of the
[HL3-FULL](https://firstdonoharm.dev), see the `LICENSE.md` file included with
this package for the terms.

This license actively proscribes this software being used by and for some
industries, countries and activities. If your usage of this software doesn't
comply with the terms of this license, then [contact me](mailto:james@harton.nz)
with the details of your use-case to organise the purchase of a license - the
cost of which may include a donation to a suitable charity or NGO.
