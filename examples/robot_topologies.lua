-- Robot Topology Definitions for Gait Generator Demonstrations
-- Defines various legged robot configurations for testing different gaits

local Vec3 = require('vec3')
local RobotConfig = require('robot_config')

local RobotTopologies = {}

--- Create a standard hexapod configuration
-- 6 legs arranged in typical insect pattern
function RobotTopologies.create_hexapod(name, scale)
    scale = scale or 1.0
    local config = RobotConfig.new(name or "hexapod")
    
    -- Hexapod leg positions (scaled)
    local leg_positions = {
        front_right = {x = 80 * scale, y = -60 * scale, z = 0, angle = -30},
        middle_right = {x = 0, y = -80 * scale, z = 0, angle = -90},
        rear_right = {x = -80 * scale, y = -60 * scale, z = 0, angle = -150},
        rear_left = {x = -80 * scale, y = 60 * scale, z = 0, angle = 150},
        middle_left = {x = 0, y = 80 * scale, z = 0, angle = 90},
        front_left = {x = 80 * scale, y = 60 * scale, z = 0, angle = 30}
    }
    
    for leg_name, pos in pairs(leg_positions) do
        local leg_origin = Vec3.new(pos.x, pos.y, pos.z)
        
        -- 3-DOF leg: coxa (hip), femur (thigh), tibia (shin)
        config:add_joint(leg_name .. "_coxa", "revolute", leg_origin, Vec3.new(0, 0, 1))
        config:add_link(leg_name .. "_coxa_link", 40 * scale, Vec3.new(1, 0, 0))
        
        config:add_joint(leg_name .. "_femur", "revolute", Vec3.new(40 * scale, 0, 0), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_femur_link", 90 * scale, Vec3.new(0, 0, -1))
        
        config:add_joint(leg_name .. "_tibia", "revolute", Vec3.new(0, 0, -90 * scale), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_tibia_link", 120 * scale, Vec3.new(0, 0, -1))
        
        config:add_chain(leg_name, {
            leg_name .. "_coxa",
            leg_name .. "_femur", 
            leg_name .. "_tibia"
        })
    end
    
    return config
end

--- Create a quadruped configuration
-- 4 legs in mammalian arrangement
function RobotTopologies.create_quadruped(name, scale)
    scale = scale or 1.0
    local config = RobotConfig.new(name or "quadruped")
    
    -- Quadruped leg positions
    local leg_positions = {
        front_right = {x = 60 * scale, y = -50 * scale, z = 0},
        front_left = {x = 60 * scale, y = 50 * scale, z = 0},
        rear_right = {x = -60 * scale, y = -50 * scale, z = 0},
        rear_left = {x = -60 * scale, y = 50 * scale, z = 0}
    }
    
    for leg_name, pos in pairs(leg_positions) do
        local leg_origin = Vec3.new(pos.x, pos.y, pos.z)
        
        -- 3-DOF leg with mammalian joint arrangement
        config:add_joint(leg_name .. "_shoulder", "revolute", leg_origin, Vec3.new(1, 0, 0))
        config:add_link(leg_name .. "_upper_leg", 50 * scale, Vec3.new(0, 0, -1))
        
        config:add_joint(leg_name .. "_elbow", "revolute", Vec3.new(0, 0, -50 * scale), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_lower_leg", 80 * scale, Vec3.new(0, 0, -1))
        
        config:add_joint(leg_name .. "_wrist", "revolute", Vec3.new(0, 0, -80 * scale), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_foot", 30 * scale, Vec3.new(0, 0, -1))
        
        config:add_chain(leg_name, {
            leg_name .. "_shoulder",
            leg_name .. "_elbow", 
            leg_name .. "_wrist"
        })
    end
    
    return config
end

--- Create an octopod configuration
-- 8 legs for maximum stability
function RobotTopologies.create_octopod(name, scale)
    scale = scale or 1.0
    local config = RobotConfig.new(name or "octopod")
    
    -- 8 legs arranged in circular pattern
    local leg_names = {
        "front_right", "front_mid_right", "rear_mid_right", "rear_right",
        "rear_left", "rear_mid_left", "front_mid_left", "front_left"
    }
    
    for i, leg_name in ipairs(leg_names) do
        local angle = (i - 1) * math.pi / 4  -- 45 degree spacing
        local radius = 70 * scale
        local x = radius * math.cos(angle)
        local y = radius * math.sin(angle)
        local leg_origin = Vec3.new(x, y, 0)
        
        -- 3-DOF leg
        config:add_joint(leg_name .. "_coxa", "revolute", leg_origin, Vec3.new(0, 0, 1))
        config:add_link(leg_name .. "_coxa_link", 35 * scale, Vec3.new(1, 0, 0))
        
        config:add_joint(leg_name .. "_femur", "revolute", Vec3.new(35 * scale, 0, 0), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_femur_link", 70 * scale, Vec3.new(0, 0, -1))
        
        config:add_joint(leg_name .. "_tibia", "revolute", Vec3.new(0, 0, -70 * scale), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_tibia_link", 90 * scale, Vec3.new(0, 0, -1))
        
        config:add_chain(leg_name, {
            leg_name .. "_coxa",
            leg_name .. "_femur", 
            leg_name .. "_tibia"
        })
    end
    
    return config
end

--- Create a tripod configuration
-- 3 legs for minimal walking
function RobotTopologies.create_tripod(name, scale)
    scale = scale or 1.0
    local config = RobotConfig.new(name or "tripod")
    
    -- 3 legs in triangular arrangement
    local leg_positions = {
        front = {x = 60 * scale, y = 0, z = 0},
        rear_right = {x = -40 * scale, y = -50 * scale, z = 0},
        rear_left = {x = -40 * scale, y = 50 * scale, z = 0}
    }
    
    for leg_name, pos in pairs(leg_positions) do
        local leg_origin = Vec3.new(pos.x, pos.y, pos.z)
        
        -- 3-DOF leg
        config:add_joint(leg_name .. "_coxa", "revolute", leg_origin, Vec3.new(0, 0, 1))
        config:add_link(leg_name .. "_coxa_link", 45 * scale, Vec3.new(1, 0, 0))
        
        config:add_joint(leg_name .. "_femur", "revolute", Vec3.new(45 * scale, 0, 0), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_femur_link", 100 * scale, Vec3.new(0, 0, -1))
        
        config:add_joint(leg_name .. "_tibia", "revolute", Vec3.new(0, 0, -100 * scale), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_tibia_link", 130 * scale, Vec3.new(0, 0, -1))
        
        config:add_chain(leg_name, {
            leg_name .. "_coxa",
            leg_name .. "_femur", 
            leg_name .. "_tibia"
        })
    end
    
    return config
end

--- Create a spider configuration
-- 8 legs with spider-like proportions
function RobotTopologies.create_spider(name, scale)
    scale = scale or 1.0
    local config = RobotConfig.new(name or "spider")
    
    -- Spider leg arrangement (longer legs, different proportions)
    local leg_names = {
        "L1", "L2", "L3", "L4", "R1", "R2", "R3", "R4"
    }
    
    local leg_positions = {
        L1 = {x = 40 * scale, y = 30 * scale, z = 0},
        L2 = {x = 10 * scale, y = 40 * scale, z = 0},
        L3 = {x = -10 * scale, y = 40 * scale, z = 0},
        L4 = {x = -40 * scale, y = 30 * scale, z = 0},
        R1 = {x = 40 * scale, y = -30 * scale, z = 0},
        R2 = {x = 10 * scale, y = -40 * scale, z = 0},
        R3 = {x = -10 * scale, y = -40 * scale, z = 0},
        R4 = {x = -40 * scale, y = -30 * scale, z = 0}
    }
    
    for leg_name, pos in pairs(leg_positions) do
        local leg_origin = Vec3.new(pos.x, pos.y, pos.z)
        
        -- Spider-like leg with longer segments
        config:add_joint(leg_name .. "_coxa", "revolute", leg_origin, Vec3.new(0, 0, 1))
        config:add_link(leg_name .. "_coxa_link", 25 * scale, Vec3.new(1, 0, 0))
        
        config:add_joint(leg_name .. "_femur", "revolute", Vec3.new(25 * scale, 0, 0), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_femur_link", 60 * scale, Vec3.new(0, 0, -1))
        
        config:add_joint(leg_name .. "_tibia", "revolute", Vec3.new(0, 0, -60 * scale), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_tibia_link", 80 * scale, Vec3.new(0, 0, -1))
        
        config:add_joint(leg_name .. "_tarsus", "revolute", Vec3.new(0, 0, -80 * scale), Vec3.new(0, 1, 0))
        config:add_link(leg_name .. "_tarsus_link", 40 * scale, Vec3.new(0, 0, -1))
        
        config:add_chain(leg_name, {
            leg_name .. "_coxa",
            leg_name .. "_femur", 
            leg_name .. "_tibia",
            leg_name .. "_tarsus"
        })
    end
    
    return config
end

--- Get recommended gait patterns for each topology
function RobotTopologies.get_recommended_gaits(topology_name)
    local gait_recommendations = {
        hexapod = {"tripod", "wave", "ripple", "metachronal"},
        quadruped = {"trot", "walk", "bound", "gallop", "pace"},
        octopod = {"wave", "ripple", "metachronal", "tetrapod"},
        tripod = {"alternating", "hop"},
        spider = {"wave", "ripple", "metachronal"}
    }
    
    return gait_recommendations[topology_name] or {"tripod", "wave"}
end

--- Get optimal gait parameters for each topology
function RobotTopologies.get_gait_parameters(topology_name, scale)
    scale = scale or 1.0
    
    local parameters = {
        hexapod = {
            step_height = 25.0 * scale,
            step_length = 50.0 * scale,
            cycle_time = 2.0,
            body_height = 100.0 * scale,
            ground_clearance = 8.0 * scale,
            max_velocity = 80.0 * scale,
            max_turn_rate = 0.4
        },
        quadruped = {
            step_height = 35.0 * scale,
            step_length = 70.0 * scale,
            cycle_time = 1.5,
            body_height = 120.0 * scale,
            ground_clearance = 10.0 * scale,
            max_velocity = 120.0 * scale,
            max_turn_rate = 0.6
        },
        octopod = {
            step_height = 20.0 * scale,
            step_length = 40.0 * scale,
            cycle_time = 2.5,
            body_height = 90.0 * scale,
            ground_clearance = 6.0 * scale,
            max_velocity = 60.0 * scale,
            max_turn_rate = 0.3
        },
        tripod = {
            step_height = 40.0 * scale,
            step_length = 80.0 * scale,
            cycle_time = 1.8,
            body_height = 140.0 * scale,
            ground_clearance = 12.0 * scale,
            max_velocity = 100.0 * scale,
            max_turn_rate = 0.5
        },
        spider = {
            step_height = 30.0 * scale,
            step_length = 60.0 * scale,
            cycle_time = 2.2,
            body_height = 80.0 * scale,
            ground_clearance = 5.0 * scale,
            max_velocity = 70.0 * scale,
            max_turn_rate = 0.4
        }
    }
    
    return parameters[topology_name] or parameters.hexapod
end

--- Create all available topologies
function RobotTopologies.create_all_topologies(scale)
    scale = scale or 1.0
    
    return {
        hexapod = RobotTopologies.create_hexapod("demo_hexapod", scale),
        quadruped = RobotTopologies.create_quadruped("demo_quadruped", scale),
        octopod = RobotTopologies.create_octopod("demo_octopod", scale),
        tripod = RobotTopologies.create_tripod("demo_tripod", scale),
        spider = RobotTopologies.create_spider("demo_spider", scale)
    }
end

return RobotTopologies