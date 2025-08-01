-- Comprehensive Gait Demonstration Script
-- Showcases various robot topologies, gaits, and movement patterns

local Object = require('object')
local Vec3 = require('vec3')
local GaitGenerator = require('gait.gait_generator')
local RobotTopologies = require('robot_topologies')
local MovementPatterns = require('movement_patterns')

-- Global demonstration state
local demo_state = {
    initialized = false,
    current_topology = "hexapod",
    current_gait = "tripod",
    current_pattern = nil,
    robot_config = nil,
    gait_generator = nil,
    pattern_start_time = 0,
    demo_start_time = 0,
    update_count = 0,
    
    -- Demo configuration
    topology_cycle_time = 180.0,  -- seconds per topology
    gait_cycle_time = 45.0,       -- seconds per gait
    pattern_cycle_time = 60.0,    -- seconds per movement pattern
    
    -- Available configurations
    topologies = {"hexapod", "quadruped", "octopod", "tripod", "spider"},
    current_topology_index = 1,
    current_gait_index = 1,
    current_pattern_index = 1,
    
    -- Performance tracking
    performance_stats = {
        avg_computation_time = 0,
        max_computation_time = 0,
        stability_margin = 0,
        gait_transitions = 0,
        distance_traveled = 0
    }
}

function initialize_demonstration()
    gcs:send_text(6, "Initializing Ardumatic Gait Demonstration System...")
    
    -- Start with hexapod
    demo_state.current_topology = demo_state.topologies[1]
    setup_current_topology()
    
    demo_state.initialized = true
    demo_state.demo_start_time = millis()
    
    gcs:send_text(6, string.format("Demo started with %s topology using %s gait", 
                                  demo_state.current_topology, demo_state.current_gait))
end

function setup_current_topology()
    local topology_name = demo_state.current_topology
    
    -- Create robot configuration
    if topology_name == "hexapod" then
        demo_state.robot_config = RobotTopologies.create_hexapod("demo_hexapod", 1.0)
    elseif topology_name == "quadruped" then
        demo_state.robot_config = RobotTopologies.create_quadruped("demo_quadruped", 1.0)
    elseif topology_name == "octopod" then
        demo_state.robot_config = RobotTopologies.create_octopod("demo_octopod", 1.0)
    elseif topology_name == "tripod" then
        demo_state.robot_config = RobotTopologies.create_tripod("demo_tripod", 1.0)
    elseif topology_name == "spider" then
        demo_state.robot_config = RobotTopologies.create_spider("demo_spider", 1.0)
    else
        demo_state.robot_config = RobotTopologies.create_hexapod("demo_default", 1.0)
    end
    
    -- Get optimal parameters for this topology
    local params = RobotTopologies.get_gait_parameters(topology_name, 1.0)
    
    -- Create gait generator with topology-specific parameters
    demo_state.gait_generator = GaitGenerator.new(demo_state.robot_config, {
        step_height = params.step_height,
        step_length = params.step_length,
        cycle_time = params.cycle_time,
        body_height = params.body_height,
        ground_clearance = params.ground_clearance,
        stability_margin = 25.0,
        max_velocity = params.max_velocity,
        max_turn_rate = params.max_turn_rate,
        default_gait = "tripod",
        enable_stability_check = true,
        auto_gait_selection = true,
        transition_time = 2.0,
        enable_performance_monitoring = true,
        enable_debug_visualization = true
    })
    
    -- Start the gait generator
    demo_state.gait_generator:start()
    
    -- Get recommended gaits for this topology
    local recommended_gaits = RobotTopologies.get_recommended_gaits(topology_name)
    demo_state.current_gait = recommended_gaits[1] or "tripod"
    demo_state.current_gait_index = 1
    demo_state.gait_generator:set_gait_pattern(demo_state.current_gait, true)
    
    -- Set up initial movement pattern
    demo_state.current_pattern = MovementPatterns.create_topology_optimized_pattern(topology_name, demo_state.pattern_cycle_time)
    demo_state.current_pattern_index = 1
    demo_state.pattern_start_time = millis()
    
    gcs:send_text(6, string.format("Configured %s with %d legs, using %s gait", 
                                  topology_name, 
                                  #demo_state.gait_generator:get_gait_state():get_leg_names(),
                                  demo_state.current_gait))
end

function cycle_to_next_gait()
    local topology_name = demo_state.current_topology
    local recommended_gaits = RobotTopologies.get_recommended_gaits(topology_name)
    
    demo_state.current_gait_index = (demo_state.current_gait_index % #recommended_gaits) + 1
    demo_state.current_gait = recommended_gaits[demo_state.current_gait_index]
    
    -- Transition to new gait
    demo_state.gait_generator:set_gait_pattern(demo_state.current_gait, true)
    demo_state.performance_stats.gait_transitions = demo_state.performance_stats.gait_transitions + 1
    
    gcs:send_text(6, string.format("Switched to %s gait (%d/%d)", 
                                  demo_state.current_gait, 
                                  demo_state.current_gait_index, 
                                  #recommended_gaits))
end

function cycle_to_next_pattern()
    local patterns = {
        MovementPatterns.create_circle_pattern(200, 50, demo_state.pattern_cycle_time),
        MovementPatterns.create_figure8_pattern(250, 45, demo_state.pattern_cycle_time),
        MovementPatterns.create_straight_line_pattern(400, 55, 4),
        MovementPatterns.create_speed_variation_pattern(25, 85, demo_state.pattern_cycle_time),
        MovementPatterns.create_random_walk_pattern(40, 6, demo_state.pattern_cycle_time),
        MovementPatterns.create_gait_showcase_pattern(demo_state.pattern_cycle_time)
    }
    
    demo_state.current_pattern_index = (demo_state.current_pattern_index % #patterns) + 1
    demo_state.current_pattern = patterns[demo_state.current_pattern_index]
    demo_state.pattern_start_time = millis()
    
    gcs:send_text(6, string.format("Switched to %s movement pattern (%d/%d)", 
                                  demo_state.current_pattern.name,
                                  demo_state.current_pattern_index,
                                  #patterns))
end

function cycle_to_next_topology()
    demo_state.current_topology_index = (demo_state.current_topology_index % #demo_state.topologies) + 1
    demo_state.current_topology = demo_state.topologies[demo_state.current_topology_index]
    
    gcs:send_text(6, string.format("Switching to %s topology (%d/%d)...", 
                                  demo_state.current_topology,
                                  demo_state.current_topology_index,
                                  #demo_state.topologies))
    
    -- Reconfigure for new topology
    setup_current_topology()
end

function get_current_motion_command()
    if not demo_state.current_pattern then
        return {
            velocity = Vec3.zero(),
            turn_rate = 0.0,
            body_pose = Vec3.zero()
        }
    end
    
    local pattern_elapsed = (millis() - demo_state.pattern_start_time) / 1000.0
    return demo_state.current_pattern:update(pattern_elapsed)
end

function update_performance_stats(computation_time)
    local stats = demo_state.performance_stats
    
    -- Update computation time statistics
    stats.avg_computation_time = (stats.avg_computation_time * 0.95) + (computation_time * 0.05)
    stats.max_computation_time = math.max(stats.max_computation_time, computation_time)
    
    -- Update stability margin
    if demo_state.gait_generator then
        stats.stability_margin = demo_state.gait_generator:get_last_stability_margin()
    end
    
    -- Estimate distance traveled (simplified)
    local motion_command = get_current_motion_command()
    if motion_command and motion_command.velocity then
        local speed = motion_command.velocity:length()
        stats.distance_traveled = stats.distance_traveled + (speed * 0.05)  -- 50ms updates
    end
end

function log_demonstration_status()
    local elapsed_time = (millis() - demo_state.demo_start_time) / 1000.0
    local stats = demo_state.performance_stats
    
    gcs:send_text(6, string.format("Demo Status: %s/%s, %.1fs elapsed, %.1fmm traveled", 
                                  demo_state.current_topology,
                                  demo_state.current_gait,
                                  elapsed_time,
                                  stats.distance_traveled))
    
    gcs:send_text(6, string.format("Performance: %.2fms avg, %.1fmm stability, %d transitions",
                                  stats.avg_computation_time,
                                  stats.stability_margin,
                                  stats.gait_transitions))
end

function handle_demonstration_cycling()
    local current_time = millis()
    local demo_elapsed = (current_time - demo_state.demo_start_time) / 1000.0
    local pattern_elapsed = (current_time - demo_state.pattern_start_time) / 1000.0
    
    -- Check if it's time to cycle gait
    local gait_cycle_elapsed = demo_elapsed % demo_state.gait_cycle_time
    if gait_cycle_elapsed < 0.1 and demo_state.update_count > 100 then  -- Avoid rapid cycling at start
        cycle_to_next_gait()
    end
    
    -- Check if it's time to cycle movement pattern
    if pattern_elapsed >= demo_state.pattern_cycle_time then
        cycle_to_next_pattern()
    end
    
    -- Check if it's time to cycle topology
    local topology_cycle_elapsed = demo_elapsed % demo_state.topology_cycle_time
    if topology_cycle_elapsed < 0.1 and demo_elapsed > 10.0 then  -- Avoid cycling too early
        cycle_to_next_topology()
    end
end

function update()
    local current_time = millis()
    
    -- Initialize on first run
    if not demo_state.initialized then
        if current_time > 5000 then  -- Wait 5 seconds for ArduPilot to stabilize
            initialize_demonstration()
        end
        return update, 100
    end
    
    demo_state.update_count = demo_state.update_count + 1
    
    -- Handle demonstration cycling
    handle_demonstration_cycling()
    
    -- Get motion command from current pattern
    local motion_command = get_current_motion_command()
    
    -- Update gait generator
    local start_time = millis()
    local leg_targets = demo_state.gait_generator:update(0.05, motion_command)  -- 50ms updates
    local computation_time = millis() - start_time
    
    -- Update performance statistics
    update_performance_stats(computation_time)
    
    -- Log status periodically
    if demo_state.update_count % 200 == 0 then  -- Every 10 seconds
        log_demonstration_status()
    end
    
    -- Generate debug output periodically
    if demo_state.update_count % 400 == 0 then  -- Every 20 seconds
        local debug_output = demo_state.gait_generator:generate_debug_output("summary")
        if debug_output and debug_output ~= "" then
            gcs:send_text(6, "Debug: " .. debug_output)
        end
    end
    
    return update, 50  -- 50ms update rate (20Hz)
end

-- Send startup message
gcs:send_text(6, "Ardumatic Gait Demonstration System Loaded")
gcs:send_text(6, "Will showcase multiple robot topologies, gaits, and movement patterns")

return update, 1000  -- Initial delay of 1 second