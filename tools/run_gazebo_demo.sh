#!/bin/bash
# Gazebo-only Gait Visualization Demo
# Shows the robot models and terrains without requiring ArduPilot SITL

set -e

# Configuration
TERRAIN=${TERRAIN:-flat}
DURATION=${DURATION:-60}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

cleanup() {
    # Handle Gazebo cleanup (may be one or two processes on macOS)
    if [ -n "$GAZEBO_SERVER_PID" ] && kill -0 "$GAZEBO_SERVER_PID" 2>/dev/null; then
        log "Terminating Gazebo server process (PID: $GAZEBO_SERVER_PID)..."
        kill "$GAZEBO_SERVER_PID" 2>/dev/null || true
        wait "$GAZEBO_SERVER_PID" 2>/dev/null || true
    fi
    
    if [ -n "$GAZEBO_GUI_PID" ] && kill -0 "$GAZEBO_GUI_PID" 2>/dev/null; then
        log "Terminating Gazebo GUI process (PID: $GAZEBO_GUI_PID)..."
        kill "$GAZEBO_GUI_PID" 2>/dev/null || true
        wait "$GAZEBO_GUI_PID" 2>/dev/null || true
    fi
    
    if [ -n "$GAZEBO_PID" ] && kill -0 "$GAZEBO_PID" 2>/dev/null; then
        log "Terminating Gazebo process (PID: $GAZEBO_PID)..."
        kill "$GAZEBO_PID" 2>/dev/null || true
        wait "$GAZEBO_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT

show_usage() {
    echo "Gazebo Gait Visualization Demo"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --terrain TYPE       Terrain type: flat, rough, slope (default: flat)"
    echo "  --duration SECONDS   Demo duration in seconds (default: 60)"
    echo "  --help               Show this help message"
    echo ""
    echo "This demo shows the terrain environments where your gait generator would operate."
    echo "For full gait simulation, use run_gait_demo.sh with ArduPilot SITL."
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --terrain)
                TERRAIN="$2"
                shift 2
                ;;
            --duration)
                DURATION="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

validate_environment() {
    # Check Gazebo installation
    if ! command -v gz >/dev/null 2>&1; then
        error "Gazebo not found. Please install Gazebo Garden or Harmonic."
        exit 1
    fi
    
    # Check terrain file exists
    local terrain_file="worlds/${TERRAIN}_terrain.sdf"
    if [ ! -f "$terrain_file" ]; then
        error "Terrain file not found: $terrain_file"
        error "Available terrains: flat, rough, slope"
        exit 1
    fi
    
    success "Environment validation passed"
}

start_gazebo_demo() {
    local terrain_file="worlds/${TERRAIN}_terrain.sdf"
    
    log "Starting Gazebo visualization demo with $TERRAIN terrain..."
    log "This shows the environment where your gait generator would operate"
    
    # Detect operating system
    local os_type=$(uname -s)
    
    if [ "$os_type" = "Darwin" ]; then
        # macOS: Start server and GUI separately
        log "Detected macOS - starting Gazebo server and GUI separately..."
        
        # Start Gazebo server
        gz sim -v3 -s -r "$terrain_file" &
        GAZEBO_SERVER_PID=$!
        
        # Wait a moment for server to start
        sleep 3
        
        # Start Gazebo GUI
        gz sim -v3 -g &
        GAZEBO_GUI_PID=$!
        
        # Set main PID for monitoring
        GAZEBO_PID=$GAZEBO_SERVER_PID
        
        log "Gazebo server started with PID: $GAZEBO_SERVER_PID"
        log "Gazebo GUI started with PID: $GAZEBO_GUI_PID"
        
    else
        # Linux: Start normally
        gz sim -v3 "$terrain_file" &
        GAZEBO_PID=$!
        log "Gazebo started with PID: $GAZEBO_PID"
    fi
    
    success "Gazebo visualization demo started!"
    
    echo
    echo "🎮 Gazebo Controls:"
    echo "  - Mouse: Rotate view"
    echo "  - Scroll: Zoom in/out"
    echo "  - Right-click + drag: Pan"
    echo "  - Ctrl+R: Reset view"
    echo
    echo "🌍 Terrain Features:"
    case $TERRAIN in
        flat)
            echo "  - Smooth, level surface for basic gait testing"
            echo "  - Reference markers (red=X axis, green=Y axis)"
            echo "  - Grid pattern for movement tracking"
            ;;
        rough)
            echo "  - Scattered rocks and obstacles"
            echo "  - Small elevation changes and hills"
            echo "  - Debris and uneven surfaces"
            echo "  - Tests obstacle avoidance and stability"
            ;;
        slope)
            echo "  - Various inclined surfaces"
            echo "  - Ramps and valleys"
            echo "  - Different slope angles"
            echo "  - Tests climbing ability and balance"
            ;;
    esac
    echo
    echo "🤖 In the full demo with ArduPilot SITL, you would see:"
    echo "  - Hexapod, quadruped, octopod, tripod, and spider robots"
    echo "  - Various gait patterns: tripod, wave, trot, bound, gallop"
    echo "  - Movement patterns: circles, figure-8, straight lines, random walk"
    echo "  - Real-time gait adaptation and stability analysis"
    echo
    
    # Monitor for the specified duration
    log "Demo will run for $DURATION seconds..."
    log "Press Ctrl+C to exit early"
    
    local start_time=$(date +%s)
    while [ $(($(date +%s) - start_time)) -lt "$DURATION" ]; do
        # Check if Gazebo is still running (handle macOS dual-process setup)
        local gazebo_running=false
        if [ -n "$GAZEBO_SERVER_PID" ] && kill -0 "$GAZEBO_SERVER_PID" 2>/dev/null; then
            gazebo_running=true
        elif [ -n "$GAZEBO_PID" ] && kill -0 "$GAZEBO_PID" 2>/dev/null; then
            gazebo_running=true
        fi
        
        if [ "$gazebo_running" = false ]; then
            log "Gazebo closed by user"
            break
        fi
        sleep 5
    done
    
    success "Gazebo visualization demo completed!"
}

main() {
    echo "Ardumatic Gazebo Visualization Demo"
    echo "==================================="
    
    parse_arguments "$@"
    validate_environment
    start_gazebo_demo
    
    echo
    echo "To run the full gait demonstration with robot simulation:"
    echo "  1. Install and build ArduPilot SITL"
    echo "  2. Set ARDUPILOT_PATH environment variable"
    echo "  3. Run: ./tools/run_gait_demo.sh"
    echo
    success "Demo completed!"
}

main "$@"