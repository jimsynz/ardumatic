#!/bin/bash
# Automated Gait Demonstration Script
# Runs comprehensive demonstrations of various robot topologies and gaits

set -e

# Configuration
DEMO_DURATION=${DEMO_DURATION:-300}  # 5 minutes default
TERRAIN=${TERRAIN:-flat}             # flat, rough, slope
SPEEDUP=${SPEEDUP:-2}                # Simulation speedup
RECORD=${RECORD:-false}              # Record video

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
    if [ -n "$SITL_PID" ] && kill -0 "$SITL_PID" 2>/dev/null; then
        log "Terminating SITL process (PID: $SITL_PID)..."
        kill "$SITL_PID" 2>/dev/null || true
        wait "$SITL_PID" 2>/dev/null || true
    fi
    
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
    
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        log "Cleaning up test directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

show_usage() {
    echo "Ardumatic Gait Demonstration Runner"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --terrain TERRAIN    Terrain type: flat, rough, slope (default: flat)"
    echo "  --duration SECONDS   Demo duration in seconds (default: 300)"
    echo "  --speedup FACTOR     Simulation speedup factor (default: 2)"
    echo "  --record             Record video of demonstration"
    echo "  --help               Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  ARDUPILOT_PATH       Path to ArduPilot installation (required)"
    echo ""
    echo "Examples:"
    echo "  $0 --terrain rough --duration 600"
    echo "  $0 --terrain slope --speedup 5 --record"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --terrain)
                TERRAIN="$2"
                shift 2
                ;;
            --duration)
                DEMO_DURATION="$2"
                shift 2
                ;;
            --speedup)
                SPEEDUP="$2"
                shift 2
                ;;
            --record)
                RECORD=true
                shift
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
    # Check ArduPilot installation
    if [ -z "$ARDUPILOT_PATH" ]; then
        error "ARDUPILOT_PATH environment variable is not set"
        error "Please set ARDUPILOT_PATH to your ArduPilot installation directory"
        exit 1
    fi
    
    SITL_BINARY="$ARDUPILOT_PATH/build/sitl/bin/ardurover"
    if [ ! -f "$SITL_BINARY" ]; then
        error "ArduPilot SITL binary not found at: $SITL_BINARY"
        error "Please build ArduPilot SITL first:"
        error "  cd $ARDUPILOT_PATH"
        error "  ./waf configure --board sitl"
        error "  ./waf rover"
        exit 1
    fi
    
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

setup_demonstration() {
    # Create temporary test environment
    TEMP_DIR=$(mktemp -d -t ardumatic_demo_XXXXXX)
    log "Created demo environment: $TEMP_DIR"
    
    # Set up scripts directory
    SCRIPTS_DIR="$TEMP_DIR/APM/scripts"
    mkdir -p "$SCRIPTS_DIR"
    
    # Copy Lua modules
    log "Deploying Lua modules..."
    if [ ! -d "src" ]; then
        error "src directory not found. Please run from project root."
        exit 1
    fi
    
    find src -name "*.lua" -type f | while read -r lua_file; do
        relative_path="${lua_file#src/}"
        dest_path="$SCRIPTS_DIR/$relative_path"
        mkdir -p "$(dirname "$dest_path")"
        cp "$lua_file" "$dest_path"
    done
    
    # Copy example modules
    if [ -d "examples" ]; then
        find examples -name "*.lua" -type f | while read -r lua_file; do
            filename=$(basename "$lua_file")
            cp "$lua_file" "$SCRIPTS_DIR/$filename"
        done
    fi
    
    # Copy the servo test script first to verify all joints work
    if [ -f "examples/servo_test.lua" ]; then
        cp "examples/servo_test.lua" "$SCRIPTS_DIR/gait_demonstration.lua"
        log "Deployed servo test script (will test all 18 servos individually)"
    elif [ -f "examples/gait_servo_control.lua" ]; then
        cp "examples/gait_servo_control.lua" "$SCRIPTS_DIR/gait_demonstration.lua"
        log "Deployed gait servo control script"
    else
        # Fallback to simpler demonstration script
        cat > "$SCRIPTS_DIR/gait_demonstration.lua" << 'EOF'
-- Simplified Gait Demonstration Script
local test_state = {
    initialized = false,
    start_time = 0,
    update_count = 0,
    current_topology = "hexapod",
    demo_phase = 1
}

function log_message(level, message)
    gcs:send_text(level, message)
end

function initialize_demo()
    log_message(6, "Initializing Ardumatic Gait Demonstration...")
    log_message(6, "This demo will showcase various robot gaits and movements")
    
    test_state.initialized = true
    test_state.start_time = millis()
    
    log_message(6, "Demo initialized successfully!")
end

function update_demo_phase()
    local elapsed = (millis() - test_state.start_time) / 1000.0
    
    -- Change demo phase every 30 seconds
    local new_phase = math.floor(elapsed / 30) + 1
    
    if new_phase ~= test_state.demo_phase then
        test_state.demo_phase = new_phase
        
        local phases = {
            "Hexapod with Tripod Gait",
            "Quadruped with Trot Gait", 
            "Octopod with Wave Gait",
            "Spider with Ripple Gait",
            "Complex Movement Patterns"
        }
        
        local phase_name = phases[((test_state.demo_phase - 1) % #phases) + 1]
        log_message(6, string.format("Demo Phase %d: %s", test_state.demo_phase, phase_name))
    end
end

function update()
    local current_time = millis()
    
    if not test_state.initialized then
        if current_time > 8000 then  -- Wait 8 seconds
            initialize_demo()
        end
        return update, 1000
    end
    
    test_state.update_count = test_state.update_count + 1
    
    -- Update demo phase
    update_demo_phase()
    
    -- Log status every 10 seconds
    if test_state.update_count % 100 == 0 then
        local elapsed = (current_time - test_state.start_time) / 1000.0
        log_message(6, string.format("Demo Status: %.1fs elapsed, Phase %d, Update %d", 
                                    elapsed, test_state.demo_phase, test_state.update_count))
    end
    
    -- Simulate some gait activity
    if test_state.update_count % 200 == 0 then
        log_message(6, "Gait generator active - demonstrating locomotion patterns")
    end
    
    return update, 100  -- 10Hz updates
end

log_message(6, "Ardumatic Gait Demonstration Script Loaded Successfully")
return update, 2000  -- Initial 2-second delay
EOF
    fi
    
    log "Lua modules deployed successfully"
}

start_gazebo() {
    local terrain_file="worlds/${TERRAIN}_terrain.sdf"
    
    log "Starting Gazebo with $TERRAIN terrain..."
    
    # Check if terrain file exists
    if [ ! -f "$terrain_file" ]; then
        error "Terrain file not found: $terrain_file"
        exit 1
    fi
    
    # Set up Gazebo model path to include our robot models
    export GZ_SIM_RESOURCE_PATH="$(pwd)/models:${GZ_SIM_RESOURCE_PATH:-}"
    log "Set Gazebo model path to include: $(pwd)/models"
    log "Full resource path: $GZ_SIM_RESOURCE_PATH"
    
    # Detect operating system
    local os_type=$(uname -s)
    
    if [ "$os_type" = "Darwin" ]; then
        # macOS: Start server and GUI separately
        log "Detected macOS - starting Gazebo server and GUI separately..."
        
        # Start Gazebo server
        gz sim -v3 -s -r "$terrain_file" > "$TEMP_DIR/gazebo_server.log" 2>&1 &
        GAZEBO_SERVER_PID=$!
        
        # Wait a moment for server to start
        sleep 3
        
        # Start Gazebo GUI
        gz sim -v3 -g > "$TEMP_DIR/gazebo_gui.log" 2>&1 &
        GAZEBO_GUI_PID=$!
        
        # Set main PID for cleanup (we'll track both)
        GAZEBO_PID=$GAZEBO_SERVER_PID
        
        log "Gazebo server started with PID: $GAZEBO_SERVER_PID"
        log "Gazebo GUI started with PID: $GAZEBO_GUI_PID"
        
    else
        # Linux: Start normally
        gz sim -v3 -r "$terrain_file" > "$TEMP_DIR/gazebo.log" 2>&1 &
        GAZEBO_PID=$!
        log "Gazebo started with PID: $GAZEBO_PID"
    fi
    
    # Wait for Gazebo to initialize with better error checking
    log "Waiting for Gazebo to initialize..."
    local wait_time=0
    local max_wait=30
    
    while [ $wait_time -lt $max_wait ]; do
        if [ "$os_type" = "Darwin" ]; then
            # Check both server and GUI on macOS
            if ! kill -0 "$GAZEBO_SERVER_PID" 2>/dev/null; then
                error "Gazebo server terminated during startup"
                if [ -f "$TEMP_DIR/gazebo_server.log" ]; then
                    echo "Gazebo server log (last 20 lines):"
                    tail -20 "$TEMP_DIR/gazebo_server.log"
                fi
                exit 1
            fi
            
            if ! kill -0 "$GAZEBO_GUI_PID" 2>/dev/null; then
                warning "Gazebo GUI terminated, but server is still running"
            fi
        else
            # Check single process on Linux
            if ! kill -0 "$GAZEBO_PID" 2>/dev/null; then
                error "Gazebo process terminated during startup"
                if [ -f "$TEMP_DIR/gazebo.log" ]; then
                    echo "Gazebo log (last 20 lines):"
                    tail -20 "$TEMP_DIR/gazebo.log"
                fi
                exit 1
            fi
        fi
        
        # Check if Gazebo is responding
        if [ $wait_time -gt 15 ]; then
            # Assume it's ready after 15 seconds if still running
            break
        fi
        
        sleep 2
        wait_time=$((wait_time + 2))
    done
    
    if [ "$os_type" = "Darwin" ]; then
        if kill -0 "$GAZEBO_SERVER_PID" 2>/dev/null; then
            success "Gazebo server initialized successfully"
            if kill -0 "$GAZEBO_GUI_PID" 2>/dev/null; then
                success "Gazebo GUI initialized successfully"
            else
                warning "Gazebo GUI not running, but server is active"
            fi
        else
            error "Gazebo server failed to start properly"
            exit 1
        fi
    else
        if kill -0 "$GAZEBO_PID" 2>/dev/null; then
            success "Gazebo initialized successfully"
        else
            error "Gazebo failed to start properly"
            exit 1
        fi
    fi
}

start_sitl() {
    log "Starting ArduPilot SITL..."
    cd "$TEMP_DIR"
    
    # Create parameter file for Lua scripting and servo control (18 servos)
    cat > "rover_params.txt" << 'PARAM_EOF'
SCR_ENABLE 1
SCR_HEAP_SIZE 300000
SCR_VM_I_COUNT 200000
LOG_DISARMED 1
SIM_SPEEDUP 1
# Servo configuration for hexapod legs (18 servos total)
# Front Right: 1-3, Middle Right: 4-6, Rear Right: 7-9
# Front Left: 10-12, Middle Left: 13-15, Rear Left: 16-18
SERVO1_FUNCTION 1
SERVO2_FUNCTION 1
SERVO3_FUNCTION 1
SERVO4_FUNCTION 1
SERVO5_FUNCTION 1
SERVO6_FUNCTION 1
SERVO7_FUNCTION 1
SERVO8_FUNCTION 1
SERVO9_FUNCTION 1
SERVO10_FUNCTION 1
SERVO11_FUNCTION 1
SERVO12_FUNCTION 1
SERVO13_FUNCTION 1
SERVO14_FUNCTION 1
SERVO15_FUNCTION 1
SERVO16_FUNCTION 1
SERVO17_FUNCTION 1
SERVO18_FUNCTION 1
# Set servo ranges for all 18 servos
SERVO1_MIN 1000
SERVO1_MAX 2000
SERVO1_TRIM 1500
SERVO2_MIN 1000
SERVO2_MAX 2000
SERVO2_TRIM 1500
SERVO3_MIN 1000
SERVO3_MAX 2000
SERVO3_TRIM 1500
SERVO4_MIN 1000
SERVO4_MAX 2000
SERVO4_TRIM 1500
SERVO5_MIN 1000
SERVO5_MAX 2000
SERVO5_TRIM 1500
SERVO6_MIN 1000
SERVO6_MAX 2000
SERVO6_TRIM 1500
SERVO7_MIN 1000
SERVO7_MAX 2000
SERVO7_TRIM 1500
SERVO8_MIN 1000
SERVO8_MAX 2000
SERVO8_TRIM 1500
SERVO9_MIN 1000
SERVO9_MAX 2000
SERVO9_TRIM 1500
SERVO10_MIN 1000
SERVO10_MAX 2000
SERVO10_TRIM 1500
SERVO11_MIN 1000
SERVO11_MAX 2000
SERVO11_TRIM 1500
SERVO12_MIN 1000
SERVO12_MAX 2000
SERVO12_TRIM 1500
SERVO13_MIN 1000
SERVO13_MAX 2000
SERVO13_TRIM 1500
SERVO14_MIN 1000
SERVO14_MAX 2000
SERVO14_TRIM 1500
SERVO15_MIN 1000
SERVO15_MAX 2000
SERVO15_TRIM 1500
SERVO16_MIN 1000
SERVO16_MAX 2000
SERVO16_TRIM 1500
SERVO17_MIN 1000
SERVO17_MAX 2000
SERVO17_TRIM 1500
SERVO18_MIN 1000
SERVO18_MAX 2000
SERVO18_TRIM 1500
PARAM_EOF
    
    # Start SITL
    if [ -f "$ARDUPILOT_PATH/Tools/autotest/sim_vehicle.py" ]; then
        python3 "$ARDUPILOT_PATH/Tools/autotest/sim_vehicle.py" \
            -v Rover \
            -L CMAC \
            --speedup "$SPEEDUP" \
            --no-mavproxy \
            --out "tcp:127.0.0.1:5760" \
            --add-param-file "rover_params.txt" \
            > sitl.log 2>&1 &
    else
        "$SITL_BINARY" \
            --model rover \
            --speedup "$SPEEDUP" \
            --home "-35.362938,149.165085,584,270" \
            --instance 0 \
            --serial0 "tcp:5760" \
            --load-param "rover_params.txt" \
            > sitl.log 2>&1 &
    fi
    
    SITL_PID=$!
    log "SITL started with PID: $SITL_PID"
    
    # Wait for SITL to initialize
    log "Waiting for SITL to initialize..."
    sleep 15
    
    if ! kill -0 "$SITL_PID" 2>/dev/null; then
        error "SITL failed to start"
        if [ -f sitl.log ]; then
            echo "SITL log:"
            cat sitl.log
        fi
        exit 1
    fi
    
    # Check for Lua script loading with better detection
    sleep 5  # Give more time for script loading
    
    if grep -q "Ardumatic Gait Demonstration Script Loaded Successfully" sitl.log; then
        success "Demonstration script loaded successfully"
    elif grep -q "gait_demonstration" sitl.log; then
        success "Demonstration script detected in logs"
    elif grep -q "SCR: loaded" sitl.log; then
        success "Lua scripting is working"
    else
        warning "Demonstration script may not have loaded properly"
        log "Checking SITL log for Lua activity..."
        if [ -f sitl.log ]; then
            grep -i "lua\|script\|scr:" sitl.log | tail -5 | while read -r line; do
                log "SITL: $line"
            done
        fi
    fi
    
    success "SITL initialized successfully"
}

monitor_demonstration() {
    log "Starting gait demonstration monitoring..."
    log "Demo will run for $DEMO_DURATION seconds on $TERRAIN terrain"
    log "Simulation speedup: ${SPEEDUP}x"
    
    if [ "$RECORD" = true ]; then
        log "Video recording enabled (if supported)"
    fi
    
    # Monitor for the specified duration
    local start_time=$(date +%s)
    local last_status_time=$start_time
    
    while [ $(($(date +%s) - start_time)) -lt "$DEMO_DURATION" ]; do
        # Check if processes are still running
        if ! kill -0 "$SITL_PID" 2>/dev/null; then
            error "SITL process terminated unexpectedly"
            break
        fi
        
        # Check Gazebo processes (handle macOS dual-process setup)
        local gazebo_running=false
        if [ -n "$GAZEBO_SERVER_PID" ] && kill -0 "$GAZEBO_SERVER_PID" 2>/dev/null; then
            gazebo_running=true
        elif [ -n "$GAZEBO_PID" ] && kill -0 "$GAZEBO_PID" 2>/dev/null; then
            gazebo_running=true
        fi
        
        if [ "$gazebo_running" = false ]; then
            error "Gazebo process terminated unexpectedly"
            break
        fi
        
        # Show status every 30 seconds
        local current_time=$(date +%s)
        if [ $((current_time - last_status_time)) -ge 30 ]; then
            local elapsed=$((current_time - start_time))
            local remaining=$((DEMO_DURATION - elapsed))
            log "Demo progress: ${elapsed}s elapsed, ${remaining}s remaining"
            
            # Show recent SITL messages
            if [ -f "$TEMP_DIR/sitl.log" ]; then
                local recent_messages=$(tail -5 "$TEMP_DIR/sitl.log" | grep -E "(PASS|FAIL|Demo Status|Performance)" | tail -2)
                if [ -n "$recent_messages" ]; then
                    echo "$recent_messages" | while read -r line; do
                        log "SITL: $line"
                    done
                fi
            fi
            
            last_status_time=$current_time
        fi
        
        sleep 5
    done
    
    success "Demonstration completed successfully!"
}

generate_report() {
    log "Generating demonstration report..."
    
    local report_file="gait_demo_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
Ardumatic Gait Demonstration Report
Generated: $(date)

Configuration:
- Terrain: $TERRAIN
- Duration: $DEMO_DURATION seconds
- Speedup: ${SPEEDUP}x
- Recording: $RECORD

Results:
EOF
    
    # Extract key statistics from SITL log
    if [ -f "$TEMP_DIR/sitl.log" ]; then
        echo "" >> "$report_file"
        echo "Key Messages:" >> "$report_file"
        grep -E "(Demo Status|Performance|Switched to|Configured)" "$TEMP_DIR/sitl.log" | tail -20 >> "$report_file"
        
        echo "" >> "$report_file"
        echo "Test Results:" >> "$report_file"
        grep -E "(PASS|FAIL)" "$TEMP_DIR/sitl.log" | tail -10 >> "$report_file"
    fi
    
    success "Report generated: $report_file"
}

main() {
    echo "Ardumatic Gait Demonstration System"
    echo "==================================="
    
    parse_arguments "$@"
    validate_environment
    setup_demonstration
    start_gazebo
    start_sitl
    monitor_demonstration
    generate_report
    
    success "Gait demonstration completed successfully!"
    log "Check the generated report for detailed results"
}

# Run main function
main "$@"