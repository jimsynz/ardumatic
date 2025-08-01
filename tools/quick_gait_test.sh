#!/bin/bash
# Quick Gait Test Script
# Tests a specific robot topology with a specific gait pattern

set -e

# Default configuration
TOPOLOGY=${TOPOLOGY:-hexapod}
GAIT=${GAIT:-tripod}
PATTERN=${PATTERN:-circle}
DURATION=${DURATION:-60}
TERRAIN=${TERRAIN:-flat}

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

show_usage() {
    echo "Quick Gait Test Script"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --topology TYPE      Robot topology: hexapod, quadruped, octopod, tripod, spider"
    echo "  --gait PATTERN       Gait pattern: tripod, wave, trot, bound, etc."
    echo "  --pattern MOVEMENT   Movement pattern: circle, figure8, straight, random"
    echo "  --terrain TYPE       Terrain: flat, rough, slope"
    echo "  --duration SECONDS   Test duration (default: 60)"
    echo "  --help               Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --topology quadruped --gait trot --pattern figure8"
    echo "  $0 --topology spider --gait wave --terrain rough --duration 120"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --topology)
                TOPOLOGY="$2"
                shift 2
                ;;
            --gait)
                GAIT="$2"
                shift 2
                ;;
            --pattern)
                PATTERN="$2"
                shift 2
                ;;
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
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

create_test_script() {
    local script_file="$1"
    
    cat > "$script_file" << EOF
-- Quick Gait Test Script
local Object = require('object')
local Vec3 = require('vec3')
local GaitGenerator = require('gait.gait_generator')
local RobotTopologies = require('robot_topologies')
local MovementPatterns = require('movement_patterns')

local test_state = {
    initialized = false,
    robot_config = nil,
    gait_generator = nil,
    movement_pattern = nil,
    start_time = 0,
    update_count = 0
}

function initialize_test()
    gcs:send_text(6, "Initializing Quick Gait Test...")
    gcs:send_text(6, "Topology: $TOPOLOGY, Gait: $GAIT, Pattern: $PATTERN")
    
    -- Create robot configuration
    if "$TOPOLOGY" == "hexapod" then
        test_state.robot_config = RobotTopologies.create_hexapod("test_hexapod", 1.0)
    elseif "$TOPOLOGY" == "quadruped" then
        test_state.robot_config = RobotTopologies.create_quadruped("test_quadruped", 1.0)
    elseif "$TOPOLOGY" == "octopod" then
        test_state.robot_config = RobotTopologies.create_octopod("test_octopod", 1.0)
    elseif "$TOPOLOGY" == "tripod" then
        test_state.robot_config = RobotTopologies.create_tripod("test_tripod", 1.0)
    elseif "$TOPOLOGY" == "spider" then
        test_state.robot_config = RobotTopologies.create_spider("test_spider", 1.0)
    else
        test_state.robot_config = RobotTopologies.create_hexapod("test_default", 1.0)
    end
    
    -- Get parameters for this topology
    local params = RobotTopologies.get_gait_parameters("$TOPOLOGY", 1.0)
    
    -- Create gait generator
    test_state.gait_generator = GaitGenerator.new(test_state.robot_config, {
        step_height = params.step_height,
        step_length = params.step_length,
        cycle_time = params.cycle_time,
        body_height = params.body_height,
        ground_clearance = params.ground_clearance,
        max_velocity = params.max_velocity,
        max_turn_rate = params.max_turn_rate,
        default_gait = "$GAIT",
        enable_stability_check = true,
        enable_performance_monitoring = true
    })
    
    test_state.gait_generator:start()
    test_state.gait_generator:set_gait_pattern("$GAIT", false)
    
    -- Create movement pattern
    if "$PATTERN" == "circle" then
        test_state.movement_pattern = MovementPatterns.create_circle_pattern(200, 50, $DURATION)
    elseif "$PATTERN" == "figure8" then
        test_state.movement_pattern = MovementPatterns.create_figure8_pattern(250, 45, $DURATION)
    elseif "$PATTERN" == "straight" then
        test_state.movement_pattern = MovementPatterns.create_straight_line_pattern(400, 55, 4)
    elseif "$PATTERN" == "random" then
        test_state.movement_pattern = MovementPatterns.create_random_walk_pattern(40, 6, $DURATION)
    else
        test_state.movement_pattern = MovementPatterns.create_circle_pattern(200, 50, $DURATION)
    end
    
    test_state.initialized = true
    test_state.start_time = millis()
    
    gcs:send_text(6, "Quick test initialized successfully!")
end

function update()
    local current_time = millis()
    
    if not test_state.initialized then
        if current_time > 5000 then
            initialize_test()
        end
        return update, 100
    end
    
    test_state.update_count = test_state.update_count + 1
    local elapsed_time = (current_time - test_state.start_time) / 1000.0
    
    -- Check if test duration exceeded
    if elapsed_time > $DURATION then
        gcs:send_text(6, "Quick test completed after " .. elapsed_time .. " seconds")
        return update, 5000  -- Slow down updates
    end
    
    -- Get motion command
    local motion_command = test_state.movement_pattern:update(elapsed_time)
    
    -- Update gait generator
    local leg_targets = test_state.gait_generator:update(0.05, motion_command)
    
    -- Log status every 10 seconds
    if test_state.update_count % 200 == 0 then
        local stability = test_state.gait_generator:get_last_stability_margin()
        gcs:send_text(6, string.format("Test: %.1fs, Stability: %.1fmm, Pattern: %s", 
                                      elapsed_time, stability, test_state.movement_pattern.name))
    end
    
    return update, 50  -- 20Hz updates
end

gcs:send_text(6, "Quick Gait Test Script Loaded")
return update, 1000
EOF
}

main() {
    echo "Quick Gait Test Runner"
    echo "====================="
    
    parse_arguments "$@"
    
    log "Configuration:"
    log "  Topology: $TOPOLOGY"
    log "  Gait: $GAIT"
    log "  Pattern: $PATTERN"
    log "  Terrain: $TERRAIN"
    log "  Duration: ${DURATION}s"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d -t quick_gait_test_XXXXXX)
    SCRIPTS_DIR="$TEMP_DIR/APM/scripts"
    mkdir -p "$SCRIPTS_DIR"
    
    # Copy modules
    if [ -d "src" ]; then
        find src -name "*.lua" -type f | while read -r lua_file; do
            relative_path="${lua_file#src/}"
            dest_path="$SCRIPTS_DIR/$relative_path"
            mkdir -p "$(dirname "$dest_path")"
            cp "$lua_file" "$dest_path"
        done
    fi
    
    if [ -d "examples" ]; then
        find examples -name "*.lua" -type f | while read -r lua_file; do
            filename=$(basename "$lua_file")
            cp "$lua_file" "$SCRIPTS_DIR/$filename"
        done
    fi
    
    # Create test script
    create_test_script "$SCRIPTS_DIR/quick_test.lua"
    
    success "Test environment prepared in $TEMP_DIR"
    log "You can now run:"
    log "  1. Start Gazebo: gz sim -v4 -r worlds/${TERRAIN}_terrain.sdf"
    log "  2. Start SITL from $TEMP_DIR:"
    log "     ARDUPILOT_PATH=/path/to/ardupilot sim_vehicle.py -v ArduRover -f gazebo-rover --model JSON"
    log ""
    log "The test will run automatically for ${DURATION} seconds"
}

main "$@"