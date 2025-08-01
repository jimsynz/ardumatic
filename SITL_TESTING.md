# SITL Testing for Ardumatic

This document describes how to test the Ardumatic kinematic solver using ArduPilot's Software-in-the-Loop (SITL) simulation environment.

## Overview

The SITL testing framework allows you to:
- Test Lua script integration with ArduPilot without physical hardware
- Validate kinematic solver functionality in a simulated environment
- Run automated regression tests
- Debug script behavior with full ArduPilot context

## Prerequisites

### Required Software

1. **ArduPilot Source Code**
   ```bash
   git clone https://github.com/ArduPilot/ardupilot.git
   cd ardupilot
   git submodule update --init --recursive
   ```

2. **Python 3** (3.6 or later)
   ```bash
   # Ubuntu/Debian
   sudo apt install python3 python3-pip
   
   # macOS
   brew install python3
   ```

3. **ArduPilot Build Dependencies**
   ```bash
   # Ubuntu/Debian
   sudo apt install build-essential ccache g++ gawk git make wget
   
   # Follow ArduPilot's setup guide for your platform:
   # https://ardupilot.org/dev/docs/building-setup-linux.html
   ```

### Environment Setup

The test harness will automatically try to find ArduPilot in common locations:
- `../../../github.com/ArduPilot/ardupilot` (common GitHub checkout structure)
- `../../ardupilot` or `../ardupilot` (relative to project)
- `~/ardupilot` (home directory)
- `/opt/ardupilot` (system installation)

1. **Set ArduPilot Path** (optional, overrides auto-detection):
   ```bash
   export ARDUPILOT_PATH=/path/to/your/ardupilot
   ```

2. **Build ArduPilot SITL** (first time only):
   ```bash
   cd $ARDUPILOT_PATH
   ./waf configure --board sitl
   ./waf rover  # Build Rover SITL binary
   ```

## Running SITL Tests

### Quick Start

Run SITL tests using the shell scripts:

```bash
# Run basic kinematic solver tests
ARDUPILOT_PATH=/path/to/ardupilot ./tools/run_sitl_tests.sh

# Run comprehensive gait generator tests
ARDUPILOT_PATH=/path/to/ardupilot ./tools/run_gait_sitl_tests.sh

# With custom timeout
ARDUPILOT_PATH=/path/to/ardupilot TIMEOUT=60 ./tools/run_gait_sitl_tests.sh

# With custom speedup factor
ARDUPILOT_PATH=/path/to/ardupilot SPEEDUP=5 ./tools/run_gait_sitl_tests.sh
```

### Test Types

**Basic Kinematic Tests** (`run_sitl_tests.sh`):
- Module loading and basic functionality
- Vector math and object creation
- Kinematic chain assembly
- FABRIK solver convergence
- Basic integration with ArduPilot

**Gait Generator Tests** (`run_gait_sitl_tests.sh`):
- Gait generator creation and configuration
- Gait pattern switching (tripod, wave, etc.)
- Motion command processing
- Stability analysis integration
- Performance monitoring
- Real-time gait updates

## Test Structure

### What Gets Tested

**Basic Kinematic Tests** validate:

1. **Module Loading**: All Lua modules load correctly in ArduPilot
2. **Basic Operations**: Vector math, object creation, basic functionality
3. **Kinematic Chain**: Link and joint creation, chain assembly
4. **FABRIK Solver**: Inverse kinematics solving with convergence testing
5. **Integration**: Proper interaction with ArduPilot's Lua environment

**Gait Generator Tests** validate:

1. **Gait System Initialization**: Robot configuration and gait generator creation
2. **Gait Control**: Start/stop functionality and state management
3. **Pattern Switching**: Smooth transitions between gait patterns (tripod, wave, etc.)
4. **Motion Processing**: Velocity and turn rate command handling
5. **Real-time Updates**: Continuous gait generation with proper timing
6. **Configuration Management**: Parameter setting and retrieval
7. **Stability Integration**: Stability analysis and margin calculation
8. **Performance Monitoring**: Computation time and efficiency tracking

### Test Scenarios

The test script creates several scenarios:

- **Simple 2-link arm**: Basic FABRIK solving
- **Reachability testing**: Target positions within and outside workspace
- **Convergence validation**: Solver accuracy and iteration limits
- **Error handling**: Invalid inputs and edge cases

## Understanding Test Output

### Success Indicators

```
✅ SUCCESS: All tests passed!
Tests run: 8
Tests passed: 8
Tests failed: 0
```

### Failure Indicators

```
❌ FAILURE: Some tests failed
Tests run: 8
Tests passed: 6
Tests failed: 2

Test Messages:
  FAIL: fabrik_solve - FABRIK solver failed to converge
  FAIL: fabrik_accuracy - End effector distance from target: 0.25
```

### Verbose Output

With `--verbose` flag, you'll see:
- SITL startup messages
- Real-time test execution
- Detailed ArduPilot log output
- Script loading and execution traces

## Troubleshooting

### Common Issues

1. **ArduPilot Not Found**
   ```
   Error: ArduPilot not found. Please set ARDUPILOT_PATH environment variable
   ```
   **Solution**: Set `ARDUPILOT_PATH` or install ArduPilot in a standard location.

2. **SITL Build Missing**
   ```
   Error: SITL binary not found
   ```
   **Solution**: Build ArduPilot SITL:
   ```bash
   cd $ARDUPILOT_PATH
   ./waf configure --board sitl
   ./waf rover
   ```

3. **Script Loading Errors**
   ```
   FAIL: Module 'fabrik' not found
   ```
   **Solution**: Check that all Lua files are present in `src/` directory.

4. **Test Timeout**
   ```
   ❌ TIMEOUT: Tests did not complete within the time limit
   ```
   **Solution**: Increase timeout with `--timeout` option or check for infinite loops.

### Debug Mode

For detailed debugging:

```bash
# Run the test script directly to see all output
ARDUPILOT_PATH=/path/to/ardupilot ./tools/run_sitl_tests.sh 2>&1 | tee sitl_debug.log
```

### Manual SITL Testing

To test manually with SITL:

```bash
# Start SITL with your scripts
cd $ARDUPILOT_PATH
./Tools/autotest/sim_vehicle.py -v Rover -L CMAC --console --map

# In MAVProxy console:
# Check if scripts loaded
script list

# Monitor script output
# (Scripts send messages via gcs:send_text())
```

## Customizing Tests

### Adding New Test Cases

Edit `tools/run_sitl_tests.sh` and modify the Lua test script generation to add new test functions:

```lua
function test_my_new_feature()
    -- Your test code here
    local result = my_kinematic_function()
    log_test_result("my_test", result == expected_value, "Test description")
end
```

Then add the function call to `run_tests()`:

```lua
function run_tests()
    -- ... existing tests ...
    test_my_new_feature()
    -- ...
end
```

## Integration with CI/CD

### Drone CI Integration

The project includes comprehensive Drone CI integration with efficient ArduPilot caching:

**Two Pipeline Architecture:**
1. **Main Build Pipeline**: Runs unit tests, linting, and basic validation
2. **SITL Tests Pipeline**: Runs integration tests with ArduPilot SITL

**Key Features:**
- **Smart Caching**: ArduPilot source and build artifacts are cached between runs
- **Parallel Execution**: SITL tests run in parallel with main build for faster feedback
- **Incremental Builds**: Only rebuilds ArduPilot when necessary
- **Architecture-Aware**: Cache keys include architecture for multi-platform support

**Cache Strategy:**
```yaml
# ArduPilot cache includes:
# - Full source code with submodules
# - Compiled SITL binary (ardurover)
# - Build configuration and dependencies
cache_key: 'ardupilot-v4.5.0-sitl-rover-{{ arch }}'
```

**Pipeline Flow:**
```
┌─────────────────┐    ┌──────────────────┐
│   Main Build    │    │   SITL Tests     │
│                 │    │                  │
│ • Unit Tests    │    │ • Setup ArduPilot│
│ • Linting       │    │ • Build SITL     │
│ • Validation    │    │ • Integration    │
└─────────────────┘    └──────────────────┘
        │                       │
        └───────┬───────────────┘
                │
        ┌───────▼────────┐
        │   Complete     │
        └────────────────┘
```

### Performance Benefits

**Without Caching:**
- ArduPilot clone: ~2-3 minutes
- Submodule init: ~1-2 minutes  
- SITL build: ~3-5 minutes
- **Total: 6-10 minutes per run**

**With Caching:**
- Cache restore: ~30 seconds
- Incremental updates: ~30 seconds
- SITL tests: ~1-2 minutes
- **Total: 2-3 minutes per run**

**Cache Efficiency:**
- ArduPilot source (~500MB) cached between runs
- SITL binary (~4MB) cached and reused
- Build dependencies cached
- Only rebuilds when ArduPilot version changes

### Local Development Workflow

```bash
# Quick test during development
busted && ARDUPILOT_PATH=/path/to/ardupilot ./tools/run_sitl_tests.sh

# Full test suite before commit
busted
ARDUPILOT_PATH=/path/to/ardupilot ./tools/run_sitl_tests.sh

# Debug failing tests (if needed)
ARDUPILOT_PATH=/path/to/ardupilot ./tools/run_sitl_tests.sh
```

### Monitoring CI Pipeline

**Pipeline Status:**
- Main build pipeline runs unit tests and linting
- SITL pipeline runs integration tests in parallel
- Both must pass for successful build

**Cache Monitoring:**
- Check cache hit rates in Drone CI logs
- Monitor ArduPilot cache size and efficiency
- Update cache keys when ArduPilot version changes

**Troubleshooting CI Issues:**
```bash
# Test locally what CI runs
ARDUPILOT_PATH=/path/to/ardupilot ./tools/run_sitl_tests.sh

# Check ArduPilot build locally
cd /path/to/ardupilot
./waf configure --board sitl
./waf rover
```

## Performance Considerations

- **Test Duration**: Basic tests run in ~30-60 seconds
- **Resource Usage**: SITL uses moderate CPU and memory
- **Parallel Testing**: Multiple SITL instances can run simultaneously on different ports
- **Speedup Factor**: Tests run at 10x real-time by default

## Advanced Usage

### Custom SITL Parameters

Modify the test harness to set specific ArduPilot parameters:

```python
# In sitl_test.py, add to _generate_test_script():
-- Set custom parameters
param:set_and_save("SCR_HEAP_SIZE", 200000)  -- Increase script memory
param:set_and_save("SCR_ENABLE", 1)          -- Ensure scripting enabled
```

### Multiple Test Scenarios

Create different test configurations:

```bash
# Test different kinematic configurations
./tools/run_sitl_tests.sh --frame rover        # Standard rover
./tools/run_sitl_tests.sh --frame balancebot   # Balance bot
./tools/run_sitl_tests.sh --frame rover-skid   # Skid-steer rover
```

## Contributing

When adding new features to Ardumatic:

1. Add corresponding SITL tests
2. Ensure tests pass before submitting PRs
3. Update test documentation for new functionality
4. Consider edge cases and error conditions

## Further Reading

- [ArduPilot SITL Documentation](https://ardupilot.org/dev/docs/sitl-simulator-software-in-the-loop.html)
- [ArduPilot Lua Scripting](https://ardupilot.org/dev/docs/common-lua-scripts.html)
- [ArduPilot AutoTest Framework](https://ardupilot.org/dev/docs/the-ardupilot-autotest-framework.html)