-- Ardumatic 3-DOF Hexapod Gait Control via ArduPilot Servo Outputs
-- Integrates gait generation algorithms with servo control for Gazebo simulation

-- Load required modules
local RobotTopologies = require('robot_topologies')
local GaitGenerator = require('gait.gait_generator')
local StaticGaits = require('gait.patterns.static_gaits')
local DynamicGaits = require('gait.patterns.dynamic_gaits')
local Vec3 = require('vec3')

-- Servo channel assignments for hexapod (18 servos total)
local SERVO_CHANNELS = {
    front_right = {coxa = 1, femur = 2, tibia = 3},
    middle_right = {coxa = 4, femur = 5, tibia = 6},
    rear_right = {coxa = 7, femur = 8, tibia = 9},
    front_left = {coxa = 10, femur = 11, tibia = 12},
    middle_left = {coxa = 13, femur = 14, tibia = 15},
    rear_left = {coxa = 16, femur = 17, tibia = 18}
}

-- Leg geometry (matching robot_topologies.lua)
local LEG_GEOMETRY = {
    coxa_length = 0.04,   -- 40mm
    femur_length = 0.09,  -- 90mm  
    tibia_length = 0.12   -- 120mm
}

-- Global state
local gait_state = {
    initialized = false,
    start_time = 0,
    current_time = 0,
    robot_config = nil,
    gait_generator = nil,
    current_gait = "tripod",
    gait_phase = 0.0,
    cycle_time = 3.0,     -- 3 second gait cycle for better visibility
    step_height = 0.03,   -- 3cm step height
    step_length = 0.05,   -- 5cm step length
    body_height = 0.15,   -- 15cm body height
    demo_phase = 1,
    phase_start_time = 0
}

function log_message(level, message)
    gcs:send_text(level, message)
end

function initialize_gait_system()
    log_message(6, "Initializing Ardumatic 3-DOF Hexapod Gait Control...")
    
    -- Create hexapod configuration
    gait_state.robot_config = RobotTopologies.create_hexapod("demo_hexapod", 1.0)
    
    -- Initialize gait generator
    gait_state.gait_generator = GaitGenerator.new(gait_state.robot_config)
    
    -- Configure servo outputs for position control (18 servos)
    for leg_name, channels in pairs(SERVO_CHANNELS) do
        for joint_name, channel in pairs(channels) do
            -- Set servo function to manual control
            param:set_and_save(string.format("SERVO%d_FUNCTION", channel), 1) -- Manual/PassThru
            param:set_and_save(string.format("SERVO%d_MIN", channel), 1000)
            param:set_and_save(string.format("SERVO%d_MAX", channel), 2000)
            param:set_and_save(string.format("SERVO%d_TRIM", channel), 1500)
        end
        log_message(6, string.format("Configured 3 servos for %s leg", leg_name))
    end
    
    gait_state.initialized = true
    gait_state.start_time = millis()
    gait_state.phase_start_time = gait_state.start_time
    
    log_message(6, "3-DOF Hexapod gait control system initialized!")
    log_message(6, string.format("Starting with %s gait, cycle time: %.1fs", 
                                gait_state.current_gait, gait_state.cycle_time))
end

function update_gait_phase()
    local elapsed = (gait_state.current_time - gait_state.phase_start_time) / 1000.0
    
    -- Change gait every 45 seconds
    if elapsed > 45.0 then
        gait_state.demo_phase = gait_state.demo_phase + 1
        gait_state.phase_start_time = gait_state.current_time
        
        local gaits = {"tripod", "wave", "ripple"}
        local gait_index = ((gait_state.demo_phase - 1) % #gaits) + 1
        gait_state.current_gait = gaits[gait_index]
        
        log_message(6, string.format("Demo Phase %d: Switching to %s gait", 
                                    gait_state.demo_phase, gait_state.current_gait))
    end
    
    -- Update gait phase (0.0 to 1.0 over cycle_time)
    local cycle_elapsed = (gait_state.current_time - gait_state.start_time) / 1000.0
    gait_state.gait_phase = (cycle_elapsed / gait_state.cycle_time) % 1.0
end

function calculate_leg_phases()
    -- Generate gait pattern based on current gait type
    local leg_phases = {}
    
    if gait_state.current_gait == "tripod" then
        -- Tripod gait: alternating triangles
        leg_phases = {
            front_right = gait_state.gait_phase,
            middle_left = gait_state.gait_phase,
            rear_right = gait_state.gait_phase,
            front_left = (gait_state.gait_phase + 0.5) % 1.0,
            middle_right = (gait_state.gait_phase + 0.5) % 1.0,
            rear_left = (gait_state.gait_phase + 0.5) % 1.0
        }
    elseif gait_state.current_gait == "wave" then
        -- Wave gait: sequential leg movement
        leg_phases = {
            front_right = gait_state.gait_phase,
            middle_right = (gait_state.gait_phase + 0.167) % 1.0,
            rear_right = (gait_state.gait_phase + 0.333) % 1.0,
            rear_left = (gait_state.gait_phase + 0.5) % 1.0,
            middle_left = (gait_state.gait_phase + 0.667) % 1.0,
            front_left = (gait_state.gait_phase + 0.833) % 1.0
        }
    elseif gait_state.current_gait == "ripple" then
        -- Ripple gait: modified wave
        leg_phases = {
            front_right = gait_state.gait_phase,
            middle_right = (gait_state.gait_phase + 0.2) % 1.0,
            rear_right = (gait_state.gait_phase + 0.4) % 1.0,
            rear_left = (gait_state.gait_phase + 0.6) % 1.0,
            middle_left = (gait_state.gait_phase + 0.8) % 1.0,
            front_left = (gait_state.gait_phase + 0.1) % 1.0
        }
    end
    
    return leg_phases
end

function phase_to_foot_position(phase)
    -- Convert gait phase (0.0-1.0) to foot position relative to leg base
    -- Creates an elliptical stepping motion
    
    local x, y, z
    
    if phase < 0.5 then
        -- Swing phase: foot moves forward and up
        local swing_progress = phase * 2.0  -- 0.0 to 1.0
        x = -gait_state.step_length/2 + (gait_state.step_length * swing_progress)
        y = 0  -- No lateral movement for now
        z = -gait_state.body_height + (gait_state.step_height * math.sin(swing_progress * math.pi))
    else
        -- Stance phase: foot moves backward on ground
        local stance_progress = (phase - 0.5) * 2.0  -- 0.0 to 1.0
        x = gait_state.step_length/2 - (gait_state.step_length * stance_progress)
        y = 0
        z = -gait_state.body_height
    end
    
    return Vec3.new(x, y, z)
end

function inverse_kinematics_3dof(target_pos)
    -- Simple 3-DOF inverse kinematics for hexapod leg
    -- target_pos is relative to leg base (coxa joint)
    
    local x, y, z = target_pos.x, target_pos.y, target_pos.z
    
    -- Coxa angle (rotation around Z-axis)
    local coxa_angle = math.atan2(y, x)
    
    -- Distance from coxa joint to target in XY plane
    local r_xy = math.sqrt(x*x + y*y) - LEG_GEOMETRY.coxa_length
    
    -- Distance from femur joint to target
    local r = math.sqrt(r_xy*r_xy + z*z)
    
    -- Clamp to reachable workspace
    local max_reach = LEG_GEOMETRY.femur_length + LEG_GEOMETRY.tibia_length
    local min_reach = math.abs(LEG_GEOMETRY.femur_length - LEG_GEOMETRY.tibia_length)
    r = math.max(min_reach, math.min(max_reach, r))
    
    -- Femur and tibia angles using law of cosines
    local cos_tibia = (LEG_GEOMETRY.femur_length*LEG_GEOMETRY.femur_length + 
                       LEG_GEOMETRY.tibia_length*LEG_GEOMETRY.tibia_length - r*r) /
                      (2 * LEG_GEOMETRY.femur_length * LEG_GEOMETRY.tibia_length)
    cos_tibia = math.max(-1, math.min(1, cos_tibia))  -- Clamp to valid range
    local tibia_angle = math.acos(cos_tibia) - math.pi  -- Negative for extension
    
    local cos_femur = (LEG_GEOMETRY.femur_length*LEG_GEOMETRY.femur_length + r*r - 
                       LEG_GEOMETRY.tibia_length*LEG_GEOMETRY.tibia_length) /
                      (2 * LEG_GEOMETRY.femur_length * r)
    cos_femur = math.max(-1, math.min(1, cos_femur))
    local femur_angle = math.acos(cos_femur) + math.atan2(-z, r_xy)
    
    return {
        coxa = coxa_angle,
        femur = femur_angle,
        tibia = tibia_angle
    }
end

function update_servo_outputs()
    local leg_phases = calculate_leg_phases()
    
    -- Convert leg phases to joint angles and output to servos
    for leg_name, phase in pairs(leg_phases) do
        local channels = SERVO_CHANNELS[leg_name]
        if channels then
            -- Calculate target foot position for this leg
            local foot_pos = phase_to_foot_position(phase)
            
            -- Calculate joint angles using inverse kinematics
            local joint_angles = inverse_kinematics_3dof(foot_pos)
            
            -- Convert angles to servo PWM and output
            for joint_name, angle in pairs(joint_angles) do
                local channel = channels[joint_name]
                if channel then
                    -- Convert angle (-π to +π) to servo PWM (1000-2000)
                    local angle_normalized = (angle + math.pi) / (2 * math.pi)
                    angle_normalized = math.max(0.0, math.min(1.0, angle_normalized))
                    
                    local servo_pwm = 1000 + (angle_normalized * 1000)
                    
                    -- Output to servo
                    SRV_Channels:set_output_pwm_chan_timeout(channel - 1, servo_pwm, 100)
                end
            end
        end
    end
end

function update()
    gait_state.current_time = millis()
    
    if not gait_state.initialized then
        if gait_state.current_time > 5000 then  -- Wait 5 seconds for system startup
            initialize_gait_system()
        end
        return update, 1000
    end
    
    -- Update gait timing and phase
    update_gait_phase()
    
    -- Calculate and output servo positions
    update_servo_outputs()
    
    -- Log status every 10 seconds
    local elapsed = (gait_state.current_time - gait_state.start_time) / 1000.0
    if math.floor(elapsed) % 10 == 0 and math.floor(elapsed * 10) % 100 == 0 then
        log_message(6, string.format("3-DOF Gait: %s, Phase: %.2f, Elapsed: %.1fs", 
                                    gait_state.current_gait, gait_state.gait_phase, elapsed))
    end
    
    return update, 50  -- 20Hz update rate
end

log_message(6, "Ardumatic 3-DOF Hexapod Gait Servo Control Script Loaded")
return update, 2000  -- Initial 2-second delay