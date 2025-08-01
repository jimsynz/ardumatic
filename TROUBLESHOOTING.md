# Troubleshooting Ardumatic Gait Demonstrations

This guide helps resolve common issues when running the gait demonstration system.

## Quick Diagnosis

Run the setup test first to identify issues:
```bash
./tools/test_setup.sh
```

## Common Issues and Solutions

### 1. "ARDUPILOT_PATH not set"

**Problem**: ArduPilot environment variable is missing.

**Solution**:
```bash
# Find your ArduPilot installation
export ARDUPILOT_PATH=/path/to/your/ardupilot

# Add to your shell profile for persistence
echo 'export ARDUPILOT_PATH=/path/to/your/ardupilot' >> ~/.bashrc
source ~/.bashrc
```

**Alternative**: Use the Gazebo-only demo:
```bash
./tools/run_gazebo_demo.sh --terrain flat --duration 120
```

### 2. "ArduPilot SITL binary not found"

**Problem**: ArduPilot SITL hasn't been built.

**Solution**:
```bash
cd $ARDUPILOT_PATH
./waf configure --board sitl
./waf rover
```

### 3. "Gazebo not found"

**Problem**: Gazebo isn't installed or not in PATH.

**Solutions**:

**macOS with Homebrew**:
```bash
brew install gz-harmonic
```

**Ubuntu 22.04**:
```bash
sudo apt update
sudo apt install gz-harmonic
```

**Check installation**:
```bash
gz sim --version
```

### 4. "Gazebo process terminated unexpectedly"

**Problem**: Gazebo crashes on startup.

**Possible Causes & Solutions**:

**Graphics Issues**:
```bash
# Check OpenGL support
glxinfo | grep OpenGL  # Linux
system_profiler SPDisplaysDataType  # macOS

# Try software rendering
export LIBGL_ALWAYS_SOFTWARE=1
./tools/run_gazebo_demo.sh
```

**World File Issues**:
```bash
# Test world file directly
gz sim worlds/flat_terrain.sdf

# Check for syntax errors
xmllint --noout worlds/flat_terrain.sdf
```

**Resource Issues**:
```bash
# Close other applications
# Reduce simulation complexity
./tools/run_gait_demo.sh --speedup 1 --duration 60
```

### 5. "Demonstration script may not have loaded properly"

**Problem**: Lua scripts aren't loading in ArduPilot SITL.

**Solutions**:

**Check Lua Scripting Support**:
```bash
# Verify ArduPilot was built with Lua support
$ARDUPILOT_PATH/build/sitl/bin/ardurover --help | grep -i lua
```

**Enable Lua Scripting**:
```bash
# In MAVProxy or Mission Planner:
param set SCR_ENABLE 1
param set SCR_HEAP_SIZE 200000
param set SCR_VM_I_COUNT 100000
```

**Check Script Syntax**:
```bash
# Test Lua syntax
lua -c examples/gait_demonstration.lua
```

### 6. Performance Issues

**Problem**: Simulation runs slowly or stutters.

**Solutions**:

**Reduce Simulation Load**:
```bash
# Lower speedup factor
./tools/run_gait_demo.sh --speedup 1

# Use simpler terrain
./tools/run_gait_demo.sh --terrain flat

# Shorter duration
./tools/run_gait_demo.sh --duration 60
```

**System Optimization**:
```bash
# Close unnecessary applications
# Check system resources
top  # Linux/macOS
htop  # If available

# Check disk space
df -h
```

### 7. "World file not found"

**Problem**: Terrain files are missing.

**Solution**:
```bash
# Check if world files exist
ls -la worlds/

# Recreate if missing
git checkout worlds/
```

### 8. Script Permission Issues

**Problem**: Scripts aren't executable.

**Solution**:
```bash
chmod +x tools/*.sh
```

## Alternative Testing Methods

### 1. Gazebo-Only Visualization
```bash
# Just show the terrain environments
./tools/run_gazebo_demo.sh --terrain rough --duration 120
```

### 2. Unit Tests Only
```bash
# Test core functionality without simulation
luarocks test
```

### 3. SITL Tests Only
```bash
# Test Lua integration without Gazebo
./tools/run_gait_sitl_tests.sh
```

### 4. Manual Testing
```bash
# Start components separately for debugging

# Terminal 1: Start Gazebo
gz sim worlds/flat_terrain.sdf

# Terminal 2: Start SITL
cd /tmp/test_dir
$ARDUPILOT_PATH/Tools/autotest/sim_vehicle.py -v Rover -L CMAC --no-mavproxy

# Terminal 3: Monitor logs
tail -f /tmp/test_dir/logs/SITL.log
```

## Debug Information Collection

### Collect System Information
```bash
# System info
uname -a
gz sim --version
$ARDUPILOT_PATH/build/sitl/bin/ardurover --version

# Graphics info (Linux)
glxinfo | head -20

# Graphics info (macOS)
system_profiler SPDisplaysDataType | head -20
```

### Collect Logs
```bash
# Run with verbose logging
./tools/run_gait_demo.sh --terrain flat --duration 60 2>&1 | tee debug.log

# Check specific log files
ls -la /tmp/ardumatic_demo_*/
cat /tmp/ardumatic_demo_*/sitl.log
cat /tmp/ardumatic_demo_*/gazebo.log
```

## Environment-Specific Issues

### macOS Issues
- **Rosetta 2**: Ensure native ARM64 versions on M1/M2 Macs
- **Security**: Allow Gazebo through macOS security settings
- **Homebrew**: Use `brew install gz-harmonic` not `gazebo`

### Linux Issues
- **Graphics Drivers**: Ensure proper OpenGL drivers installed
- **Permissions**: Check user permissions for /dev/input devices
- **Dependencies**: Install all required system libraries

### Virtual Machine Issues
- **3D Acceleration**: Enable 3D acceleration in VM settings
- **Memory**: Allocate sufficient RAM (4GB+ recommended)
- **Graphics**: May need software rendering mode

## Getting Help

### Check Logs First
1. Run `./tools/test_setup.sh` for quick diagnosis
2. Check generated log files in temp directories
3. Look for specific error messages

### Provide Information When Asking for Help
- Operating system and version
- Gazebo version (`gz sim --version`)
- ArduPilot version
- Complete error messages
- Steps that led to the issue

### Useful Commands for Debugging
```bash
# Test individual components
gz sim --version
lua -v
$ARDUPILOT_PATH/build/sitl/bin/ardurover --help

# Check processes
ps aux | grep gz
ps aux | grep ardurover

# Check network ports
netstat -an | grep 5760
lsof -i :5760
```

## Fallback Options

If full simulation doesn't work:

1. **Use Gazebo-only demo** for terrain visualization
2. **Run unit tests** to verify core gait algorithms
3. **Use SITL tests** to verify ArduPilot integration
4. **Manual testing** with individual components

The core gait generation algorithms work independently of the visualization system!