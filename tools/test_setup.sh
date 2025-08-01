#!/bin/bash
# Test Setup Script - Validates the demonstration environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

echo "Ardumatic Demonstration Setup Test"
echo "=================================="

# Test 1: Check ArduPilot
log "Testing ArduPilot SITL..."
if [ -z "$ARDUPILOT_PATH" ]; then
    error "ARDUPILOT_PATH not set"
    echo "Please set: export ARDUPILOT_PATH=/path/to/ardupilot"
    exit 1
else
    success "ARDUPILOT_PATH set to: $ARDUPILOT_PATH"
fi

SITL_BINARY="$ARDUPILOT_PATH/build/sitl/bin/ardurover"
if [ -f "$SITL_BINARY" ]; then
    success "ArduPilot SITL binary found"
else
    error "ArduPilot SITL binary not found at: $SITL_BINARY"
    exit 1
fi

# Test 2: Check Gazebo
log "Testing Gazebo..."
if command -v gz >/dev/null 2>&1; then
    success "Gazebo command found"
    GZ_VERSION=$(gz sim --version 2>/dev/null | head -1 || echo "Unknown version")
    log "Gazebo version: $GZ_VERSION"
else
    error "Gazebo not found"
    exit 1
fi

# Test 3: Check world files
log "Testing world files..."
for terrain in flat rough slope; do
    world_file="worlds/${terrain}_terrain.sdf"
    if [ -f "$world_file" ]; then
        success "World file found: $world_file"
    else
        error "World file missing: $world_file"
    fi
done

# Test 4: Check Lua modules
log "Testing Lua modules..."
if [ -d "src" ]; then
    lua_count=$(find src -name "*.lua" | wc -l)
    success "Found $lua_count Lua modules in src/"
else
    error "src/ directory not found"
fi

if [ -d "examples" ]; then
    example_count=$(find examples -name "*.lua" | wc -l)
    success "Found $example_count Lua examples"
else
    warning "examples/ directory not found"
fi

# Test 5: Quick Gazebo test
log "Testing Gazebo startup (5 second test)..."
TEMP_DIR=$(mktemp -d)
timeout 8s gz sim worlds/flat_terrain.sdf > "$TEMP_DIR/gz_test.log" 2>&1 &
GZ_PID=$!

sleep 5

if kill -0 "$GZ_PID" 2>/dev/null; then
    success "Gazebo started successfully"
    kill "$GZ_PID" 2>/dev/null || true
    wait "$GZ_PID" 2>/dev/null || true
else
    warning "Gazebo may have issues"
    if [ -f "$TEMP_DIR/gz_test.log" ]; then
        echo "Gazebo test log:"
        head -10 "$TEMP_DIR/gz_test.log"
    fi
fi

rm -rf "$TEMP_DIR"

# Test 6: Check script permissions
log "Testing script permissions..."
for script in tools/run_gait_demo.sh tools/quick_gait_test.sh; do
    if [ -x "$script" ]; then
        success "Script executable: $script"
    else
        warning "Script not executable: $script"
        log "Run: chmod +x $script"
    fi
done

echo
success "Setup test completed!"
echo
echo "To run demonstrations:"
echo "  ./tools/run_gait_demo.sh --terrain flat --duration 60"
echo "  ./tools/quick_gait_test.sh --topology hexapod --gait tripod"