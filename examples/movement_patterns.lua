-- Movement Pattern Generators for Gait Demonstrations
-- Creates various motion commands to showcase different gaits and behaviors

local Vec3 = require('vec3')

local MovementPatterns = {}

--- Create a circular walking pattern
-- Robot walks in a circle with specified radius and speed
function MovementPatterns.create_circle_pattern(radius, speed, duration)
    radius = radius or 200.0  -- mm
    speed = speed or 50.0     -- mm/s
    duration = duration or 30.0  -- seconds
    
    return {
        name = "circle",
        duration = duration,
        update = function(self, elapsed_time)
            local angular_velocity = speed / radius
            local angle = angular_velocity * elapsed_time
            
            local forward_speed = speed * 0.8  -- Slightly slower for stability
            local turn_rate = angular_velocity
            
            return {
                velocity = Vec3.new(forward_speed, 0, 0),
                turn_rate = turn_rate,
                body_pose = Vec3.zero()
            }
        end
    }
end

--- Create a figure-8 walking pattern
-- Robot walks in a figure-8 pattern
function MovementPatterns.create_figure8_pattern(size, speed, duration)
    size = size or 300.0      -- mm
    speed = speed or 40.0     -- mm/s
    duration = duration or 60.0  -- seconds
    
    return {
        name = "figure8",
        duration = duration,
        update = function(self, elapsed_time)
            local cycle_time = 30.0  -- seconds per figure-8
            local phase = (elapsed_time % cycle_time) / cycle_time * 2 * math.pi
            
            -- Figure-8 parametric equations
            local turn_rate = 0.3 * math.sin(2 * phase)
            local forward_speed = speed * (0.7 + 0.3 * math.cos(phase))
            
            return {
                velocity = Vec3.new(forward_speed, 0, 0),
                turn_rate = turn_rate,
                body_pose = Vec3.zero()
            }
        end
    }
end

--- Create a straight line pattern with direction changes
-- Robot walks straight, then turns and walks in new direction
function MovementPatterns.create_straight_line_pattern(distance, speed, num_segments)
    distance = distance or 500.0  -- mm per segment
    speed = speed or 60.0         -- mm/s
    num_segments = num_segments or 4
    
    local segment_time = distance / speed
    local turn_time = 3.0  -- seconds to turn
    local total_cycle_time = (segment_time + turn_time) * num_segments
    
    return {
        name = "straight_line",
        duration = total_cycle_time * 2,  -- Two full cycles
        update = function(self, elapsed_time)
            local cycle_phase = (elapsed_time % total_cycle_time) / total_cycle_time
            local segment_phase = (cycle_phase * num_segments) % 1.0
            local segment_index = math.floor(cycle_phase * num_segments)
            
            local segment_duration = segment_time / (segment_time + turn_time)
            
            if segment_phase < segment_duration then
                -- Walking straight
                return {
                    velocity = Vec3.new(speed, 0, 0),
                    turn_rate = 0.0,
                    body_pose = Vec3.zero()
                }
            else
                -- Turning
                local turn_angle = (2 * math.pi) / num_segments
                local turn_rate = turn_angle / turn_time
                return {
                    velocity = Vec3.new(0, 0, 0),
                    turn_rate = turn_rate,
                    body_pose = Vec3.zero()
                }
            end
        end
    }
end

--- Create a random walk pattern
-- Robot walks with random direction changes
function MovementPatterns.create_random_walk_pattern(speed, turn_frequency, duration)
    speed = speed or 45.0           -- mm/s
    turn_frequency = turn_frequency or 5.0  -- direction changes per minute
    duration = duration or 120.0    -- seconds
    
    local direction_change_interval = 60.0 / turn_frequency
    local current_direction = 0.0
    local next_change_time = direction_change_interval
    
    return {
        name = "random_walk",
        duration = duration,
        current_direction = current_direction,
        next_change_time = next_change_time,
        update = function(self, elapsed_time)
            -- Check if it's time to change direction
            if elapsed_time >= self.next_change_time then
                -- Random direction change (-45 to +45 degrees)
                local direction_change = (math.random() - 0.5) * math.pi / 2
                self.current_direction = self.current_direction + direction_change
                self.next_change_time = elapsed_time + direction_change_interval + (math.random() - 0.5) * 2.0
            end
            
            -- Calculate velocity components
            local forward_speed = speed * 0.9  -- Slightly reduced for stability
            local lateral_speed = speed * 0.3 * math.sin(self.current_direction)
            
            return {
                velocity = Vec3.new(forward_speed, lateral_speed, 0),
                turn_rate = self.current_direction * 0.1,  -- Gradual turning
                body_pose = Vec3.zero()
            }
        end
    }
end

--- Create a speed variation pattern
-- Robot walks at varying speeds to test gait adaptation
function MovementPatterns.create_speed_variation_pattern(min_speed, max_speed, duration)
    min_speed = min_speed or 20.0   -- mm/s
    max_speed = max_speed or 100.0  -- mm/s
    duration = duration or 90.0     -- seconds
    
    return {
        name = "speed_variation",
        duration = duration,
        update = function(self, elapsed_time)
            -- Sinusoidal speed variation
            local speed_cycle = 20.0  -- seconds per speed cycle
            local speed_phase = (elapsed_time % speed_cycle) / speed_cycle * 2 * math.pi
            local speed = min_speed + (max_speed - min_speed) * (0.5 + 0.5 * math.sin(speed_phase))
            
            return {
                velocity = Vec3.new(speed, 0, 0),
                turn_rate = 0.0,
                body_pose = Vec3.zero()
            }
        end
    }
end

--- Create a terrain following pattern
-- Robot adjusts body pose based on simulated terrain
function MovementPatterns.create_terrain_following_pattern(speed, terrain_frequency, duration)
    speed = speed or 35.0                    -- mm/s
    terrain_frequency = terrain_frequency or 0.1  -- terrain changes per second
    duration = duration or 80.0              -- seconds
    
    return {
        name = "terrain_following",
        duration = duration,
        update = function(self, elapsed_time)
            -- Simulate terrain variations
            local terrain_phase = elapsed_time * terrain_frequency * 2 * math.pi
            local roll_angle = 0.1 * math.sin(terrain_phase)  -- ±0.1 radians
            local pitch_angle = 0.08 * math.sin(terrain_phase * 1.3)  -- ±0.08 radians
            local height_adjustment = 10.0 * math.sin(terrain_phase * 0.7)  -- ±10mm
            
            return {
                velocity = Vec3.new(speed, 0, 0),
                turn_rate = 0.0,
                body_pose = Vec3.new(roll_angle, pitch_angle, height_adjustment)
            }
        end
    }
end

--- Create a complex maneuver pattern
-- Combines multiple movement types in sequence
function MovementPatterns.create_complex_maneuver_pattern(duration)
    duration = duration or 150.0  -- seconds
    
    local maneuvers = {
        {name = "forward", duration = 15.0, velocity = Vec3.new(50, 0, 0), turn_rate = 0.0},
        {name = "turn_right", duration = 8.0, velocity = Vec3.new(20, 0, 0), turn_rate = 0.4},
        {name = "diagonal", duration = 12.0, velocity = Vec3.new(40, 20, 0), turn_rate = 0.0},
        {name = "circle_left", duration = 20.0, velocity = Vec3.new(35, 0, 0), turn_rate = -0.3},
        {name = "backward", duration = 10.0, velocity = Vec3.new(-30, 0, 0), turn_rate = 0.0},
        {name = "spin", duration = 6.0, velocity = Vec3.new(0, 0, 0), turn_rate = 0.8},
        {name = "forward_fast", duration = 15.0, velocity = Vec3.new(80, 0, 0), turn_rate = 0.0},
        {name = "weave", duration = 25.0, velocity = Vec3.new(45, 0, 0), turn_rate = 0.0}  -- Special weaving pattern
    }
    
    return {
        name = "complex_maneuver",
        duration = duration,
        maneuvers = maneuvers,
        update = function(self, elapsed_time)
            -- Find current maneuver
            local cumulative_time = 0
            local current_maneuver = self.maneuvers[1]
            local maneuver_elapsed = elapsed_time
            
            for _, maneuver in ipairs(self.maneuvers) do
                if elapsed_time <= cumulative_time + maneuver.duration then
                    current_maneuver = maneuver
                    maneuver_elapsed = elapsed_time - cumulative_time
                    break
                end
                cumulative_time = cumulative_time + maneuver.duration
            end
            
            -- Special handling for weaving pattern
            if current_maneuver.name == "weave" then
                local weave_frequency = 0.3  -- Hz
                local weave_amplitude = 0.2  -- rad/s
                local weave_turn = weave_amplitude * math.sin(2 * math.pi * weave_frequency * maneuver_elapsed)
                
                return {
                    velocity = current_maneuver.velocity,
                    turn_rate = weave_turn,
                    body_pose = Vec3.zero()
                }
            else
                return {
                    velocity = current_maneuver.velocity,
                    turn_rate = current_maneuver.turn_rate,
                    body_pose = Vec3.zero()
                }
            end
        end
    }
end

--- Create a gait showcase pattern
-- Designed to show off different gait capabilities
function MovementPatterns.create_gait_showcase_pattern(duration)
    duration = duration or 180.0  -- seconds
    
    return {
        name = "gait_showcase",
        duration = duration,
        update = function(self, elapsed_time)
            local phase = (elapsed_time % 60.0) / 60.0  -- 60-second cycles
            
            if phase < 0.2 then
                -- Slow, stable walking
                return {
                    velocity = Vec3.new(25, 0, 0),
                    turn_rate = 0.0,
                    body_pose = Vec3.zero()
                }
            elseif phase < 0.4 then
                -- Medium speed with turns
                local turn_rate = 0.3 * math.sin(elapsed_time * 0.5)
                return {
                    velocity = Vec3.new(45, 0, 0),
                    turn_rate = turn_rate,
                    body_pose = Vec3.zero()
                }
            elseif phase < 0.6 then
                -- Fast straight walking
                return {
                    velocity = Vec3.new(75, 0, 0),
                    turn_rate = 0.0,
                    body_pose = Vec3.zero()
                }
            elseif phase < 0.8 then
                -- Lateral movement
                return {
                    velocity = Vec3.new(30, 25, 0),
                    turn_rate = 0.1,
                    body_pose = Vec3.zero()
                }
            else
                -- Complex maneuvering
                return {
                    velocity = Vec3.new(40, 15 * math.sin(elapsed_time), 0),
                    turn_rate = 0.2 * math.cos(elapsed_time * 0.8),
                    body_pose = Vec3.zero()
                }
            end
        end
    }
end

--- Get all available movement patterns
function MovementPatterns.get_all_patterns()
    return {
        MovementPatterns.create_circle_pattern(),
        MovementPatterns.create_figure8_pattern(),
        MovementPatterns.create_straight_line_pattern(),
        MovementPatterns.create_random_walk_pattern(),
        MovementPatterns.create_speed_variation_pattern(),
        MovementPatterns.create_terrain_following_pattern(),
        MovementPatterns.create_complex_maneuver_pattern(),
        MovementPatterns.create_gait_showcase_pattern()
    }
end

--- Create a pattern suitable for a specific robot topology
function MovementPatterns.create_topology_optimized_pattern(topology_name, duration)
    duration = duration or 120.0
    
    local patterns = {
        hexapod = MovementPatterns.create_gait_showcase_pattern(duration),
        quadruped = MovementPatterns.create_speed_variation_pattern(30, 120, duration),
        octopod = MovementPatterns.create_terrain_following_pattern(25, 0.08, duration),
        tripod = MovementPatterns.create_straight_line_pattern(400, 40, 3),
        spider = MovementPatterns.create_random_walk_pattern(35, 4, duration)
    }
    
    return patterns[topology_name] or MovementPatterns.create_circle_pattern(150, 40, duration)
end

return MovementPatterns