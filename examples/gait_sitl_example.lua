-- Ardumatic Gait Generator SITL Example
-- Demonstrates gait generation for a hexapod robot in ArduPilot SITL
-- This script shows how to integrate the gait generator with ArduPilot's control systems

local Object = require('object')
local Vec3 = require('vec3')
local RobotConfig = require('robot_config')
local GaitGenerator = require('gait.gait_generator')
local ServoMapper = require('servo_mapper')

-- Global state
local robot_state = {
    initialized = false,
    robot_config = nil,
    gait_generator = nil,
    servo_mapper = nil,
    last_update = 0,
    update_interval = 50,  -- 50ms = 20Hz update rate
    current_mode = "manual",  -- manual, auto, waypoint
    target_velocity = Vec3.zero(),
    target_turn_rate = 0.0,
    gait_pattern = "tripod",
    performance_stats = {
        update_count = 0,
        avg_computation_time = 0,
        last_stability_margin = 0
    }
}

function create_hexapod_config()
    local config = RobotConfig.new("sitl_hexapod")
    
    -- Hexapod leg positions (in mm from body center)
    local leg_positions = {
        front_right = {x = 80, y = -60, z = 0, servo_base = 1},
        middle_right = {x = 0, y = -80, z = 0, servo_base = 7},
        rear_right = {x = -80, y = -60, z = 0, servo_base = 13},
        rear_left = {x = -80, y = 60, z = 0, servo_base = 19},
        middle_left = {x = 0, y = 80, z = 0, servo_base = 25},
        front_left = {x = 80, y = 60, z = 0, servo_base = 31}
    }
    
    for leg_name, pos in pairs(leg_positions) do
        local leg_origin = Vec3.new(pos.x, pos.y, pos.z)
        
        -- 3-DOF leg: coxa (hip), femur (thigh), tibia (shin)
        -- Coxa joint - horizontal rotation
        config:add_joint(leg_name .. "_coxa", "revolute", leg_origin, Vec3.new(0, 0, 1))
        config:add_link(leg_name .. "_coxa_link", 40, Vec3.new(1, 0, 0))
        
        -- Femur joint - vertical rotation
        config:add_joint(leg_name .. "_femur", "revolute", Vec3.new(40, 0, 0), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_femur_link", 90, Vec3.new(0, 0, -1))
        
        -- Tibia joint - vertical rotation
        config:add_joint(leg_name .. "_tibia", "revolute", Vec3.new(0, 0, -90), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_tibia_link", 120, Vec3.new(0, 0, -1))
        
        -- Define the kinematic chain
        config:add_chain(leg_name, {
            leg_name .. "_coxa",
            leg_name .. "_femur", 
            leg_name .. "_tibia"
        })
        
        -- Store servo mapping info
        config:set_metadata(leg_name .. "_servo_base", pos.servo_base)
    end
    
    return config
end

function create_servo_mapper()
    local mapper = ServoMapper.new()
    
    -- Map each leg's joints to servo channels
    local leg_names = {"front_right", "middle_right", "rear_right", "rear_left", "middle_left", "front_left"}
    
    for i, leg_name in ipairs(leg_names) do
        local servo_base = (i - 1) * 6 + 1  -- 6 servos per leg, starting from channel 1
        
        -- Map joints to servo channels
        mapper:add_mapping(leg_name .. "_coxa", servo_base, {
            min_angle = -45,
            max_angle = 45,
            min_pwm = 1000,
            max_pwm = 2000,
            reverse = false
        })
        
        mapper:add_mapping(leg_name .. "_femur", servo_base + 1, {
            min_angle = -90,
            max_angle = 90,
            min_pwm = 1000,
            max_pwm = 2000,
            reverse = false
        })
        
        mapper:add_mapping(leg_name .. "_tibia", servo_base + 2, {
            min_angle = -135,
            max_angle = 45,
            min_pwm = 1000,
            max_pwm = 2000,
            reverse = true  -- Tibia typically needs reversal
        })
    end
    
    return mapper
end

function initialize_robot()
    gcs:send_text(6, "Initializing Ardumatic Hexapod Gait System...")
    
    -- Create robot configuration
    robot_state.robot_config = create_hexapod_config()
    
    -- Create servo mapper
    robot_state.servo_mapper = create_servo_mapper()
    
    -- Create gait generator with comprehensive configuration
    robot_state.gait_generator = GaitGenerator.new(robot_state.robot_config, {
        step_height = 30.0,        -- mm
        step_length = 60.0,        -- mm
        cycle_time = 2.0,          -- seconds
        body_height = 100.0,       -- mm above ground
        ground_clearance = 8.0,    -- mm minimum clearance
        stability_margin = 25.0,   -- mm margin for stability
        max_velocity = 80.0,       -- mm/s maximum forward velocity
        max_turn_rate = 0.3,       -- rad/s maximum turn rate
        default_gait = robot_state.gait_pattern,
        enable_stability_check = true,
        auto_gait_selection = true,
        transition_time = 1.5,     -- seconds for gait transitions
        enable_performance_monitoring = true,
        enable_debug_visualization = true
    })
    
    -- Start the gait generator
    robot_state.gait_generator:start()
    
    gcs:send_text(6, string.format("Hexapod initialized with %s gait pattern", robot_state.gait_pattern))
    gcs:send_text(6, string.format("Available gaits: %s", table.concat(robot_state.gait_generator:get_available_gaits(), ", ")))
    
    robot_state.initialized = true
    robot_state.last_update = millis()
end

function get_motion_command()
    -- In a real implementation, this would read from RC channels or mission commands
    -- For SITL testing, we'll simulate different motion patterns
    
    local current_time = millis() / 1000.0
    local motion_command = {
        velocity = Vec3.zero(),
        turn_rate = 0.0,
        body_pose = Vec3.zero()
    }
    
    -- Simple test pattern: forward motion with periodic turns
    local cycle_time = 20.0  -- 20 second cycle
    local phase = (current_time % cycle_time) / cycle_time
    
    if phase < 0.4 then
        -- Forward motion
        motion_command.velocity = Vec3.new(50, 0, 0)  -- 50mm/s forward
    elseif phase < 0.6 then
        -- Turn right
        motion_command.turn_rate = 0.2  -- 0.2 rad/s
    elseif phase < 0.8 then
        -- Forward motion
        motion_command.velocity = Vec3.new(40, 20, 0)  -- Forward and right
    else
        -- Turn left
        motion_command.turn_rate = -0.15  -- -0.15 rad/s
    end
    
    return motion_command
end

function update_servos(leg_targets)
    if not robot_state.servo_mapper then
        return
    end
    
    -- Get joint angles from kinematic chains
    local chains = robot_state.robot_config:build_chains()
    
    for leg_name, target_pos in pairs(leg_targets) do
        local chain = chains[leg_name]
        if chain then
            -- Get joint angles from the solved chain
            local joint_angles = chain:get_joint_angles()
            
            -- Map joint angles to servo commands
            for i, angle in ipairs(joint_angles) do
                local joint_names = {leg_name .. "_coxa", leg_name .. "_femur", leg_name .. "_tibia"}
                local joint_name = joint_names[i]
                
                if joint_name then
                    local servo_channel, pwm_value = robot_state.servo_mapper:map_joint_to_servo(joint_name, angle)
                    if servo_channel and pwm_value then
                        -- Set servo output (ArduPilot function)
                        SRV_Channels:set_output_pwm(servo_channel, pwm_value)
                    end
                end
            end
        end
    end
end

function log_performance_stats()
    local stats = robot_state.performance_stats
    local gait_stats = robot_state.gait_generator:get_performance_statistics()
    
    if gait_stats then
        gcs:send_text(6, string.format("Gait Performance: %.2fms avg, %.1fmm stability, %s pattern",
            gait_stats.avg_computation_time or 0,
            stats.last_stability_margin,
            robot_state.gait_generator:get_gait_pattern()))
    end
end

function handle_gcs_commands()
    -- In a real implementation, this would handle MAVLink commands
    -- For SITL, we can simulate command changes
    
    local current_time = millis() / 1000.0
    
    -- Simulate gait pattern changes every 30 seconds
    if math.floor(current_time / 30) % 2 == 0 then
        if robot_state.gait_pattern ~= "tripod" then
            robot_state.gait_pattern = "tripod"
            robot_state.gait_generator:set_gait_pattern("tripod", true)
            gcs:send_text(6, "Switched to tripod gait")
        end
    else
        if robot_state.gait_pattern ~= "wave" then
            robot_state.gait_pattern = "wave"
            robot_state.gait_generator:set_gait_pattern("wave", true)
            gcs:send_text(6, "Switched to wave gait")
        end
    end
end

function update()
    local current_time = millis()
    
    -- Initialize on first run
    if not robot_state.initialized then
        if current_time > 3000 then  -- Wait 3 seconds for ArduPilot to stabilize
            initialize_robot()
        end
        return update, 100
    end
    
    -- Check if it's time for an update
    if current_time - robot_state.last_update < robot_state.update_interval then
        return update, 10  -- Check again in 10ms
    end
    
    local dt = (current_time - robot_state.last_update) / 1000.0
    robot_state.last_update = current_time
    
    -- Handle GCS commands
    handle_gcs_commands()
    
    -- Get motion command
    local motion_command = get_motion_command()
    
    -- Update gait generator
    local start_time = millis()
    local leg_targets = robot_state.gait_generator:update(dt, motion_command)
    local computation_time = millis() - start_time
    
    -- Update performance statistics
    robot_state.performance_stats.update_count = robot_state.performance_stats.update_count + 1
    robot_state.performance_stats.avg_computation_time = 
        (robot_state.performance_stats.avg_computation_time * 0.9) + (computation_time * 0.1)
    robot_state.performance_stats.last_stability_margin = 
        robot_state.gait_generator:get_last_stability_margin()
    
    -- Update servo outputs
    if leg_targets then
        update_servos(leg_targets)
    end
    
    -- Log performance stats every 5 seconds
    if robot_state.performance_stats.update_count % 100 == 0 then
        log_performance_stats()
    end
    
    -- Generate debug output every 10 seconds
    if robot_state.performance_stats.update_count % 200 == 0 then
        local debug_output = robot_state.gait_generator:generate_debug_output("summary")
        if debug_output and debug_output ~= "" then
            gcs:send_text(6, "Debug: " .. debug_output)
        end
    end
    
    return update, 10  -- Run again in 10ms
end

-- Start the script
gcs:send_text(6, "Ardumatic Hexapod Gait SITL Example Started")
return update, 1000  -- Initial delay of 1 second