#!/usr/bin/env lua

-- Add src to package path (prioritize local src over luarocks)
package.path = "./src/?.lua;" .. package.path

--[[
  Phase 3 Terrain Adaptation Example
  
  Demonstrates the terrain adaptation capabilities added in Phase 3 of the
  Ardumatic gait generator system, including:
  
  - TerrainPredictor with sensor integration
  - Adaptive step height based on terrain roughness
  - Ground contact detection and prediction
  - Body attitude compensation
  - Sensor fusion from multiple sources
  
  This example shows how to integrate terrain adaptation with the existing
  gait generator for robust walking on uneven terrain.
]]

local RobotBuilder = require("robot_builder")
local GaitGenerator = require("gait.gait_generator")
local TerrainPredictor = require("gait.terrain_predictor")
local SensorProviders = require("gait.sensor_providers")
local Vec3 = require("vec3")

print("=== Ardumatic Phase 3: Terrain Adaptation Example ===\n")

-- Create a hexapod robot configuration
print("Creating hexapod robot configuration...")
local robot_config = RobotBuilder.hexapod(
  120,  -- leg_spacing: distance between leg attachment points
  40,   -- coxa_length: hip segment length
  60,   -- femur_length: thigh segment length
  80    -- tibia_length: shin segment length
)

-- Create gait generator with terrain adaptation enabled
print("Creating gait generator with terrain adaptation...")
local gait_config = {
  step_height = 40,                    -- 40mm base step height
  step_length = 80,                    -- 80mm step length
  cycle_time = 2.5,                    -- 2.5 second cycle time
  body_height = 120,                   -- 120mm body height
  ground_clearance = 8,                -- 8mm ground clearance
  default_gait = "tripod",             -- Start with tripod gait
  enable_terrain_adaptation = true,    -- Enable terrain adaptation
  terrain_prediction_distance = 250,   -- 250mm prediction distance
  adaptive_step_height_factor = 2.0    -- Up to 2x step height increase
}

local gait_generator = GaitGenerator.new(robot_config, gait_config)

-- Create and register sensor providers for terrain adaptation
print("Setting up sensor providers...")

-- Rangefinder for ground distance measurement
local rangefinder_provider = SensorProviders.MockProvider.new({
  distance = 1200,        -- 1.2m ground distance in mm
  signal_quality = 90,    -- 90% signal quality
  vehicle_altitude = 1320 -- 1.32m vehicle altitude in mm
}, true)

-- AHRS for body attitude
local ahrs_provider = SensorProviders.MockProvider.new({
  attitude = {
    roll = 0.087,   -- 5 degrees roll (uneven ground)
    pitch = -0.052, -- -3 degrees pitch (slight slope)
    yaw = 0.0
  },
  velocity = {
    north = 75,     -- 75 mm/s forward
    east = 0,       -- No lateral movement
    down = 0        -- No vertical movement
  },
  height_above_ground = 1200  -- 1.2m above ground in mm
}, true)

-- Terrain database provider
local terrain_provider = SensorProviders.MockProvider.new({
  height_above_terrain = 1180,  -- 1.18m above terrain in mm
  terrain_height_amsl = 140     -- 140mm terrain height above sea level
}, true)

-- Register sensor providers with the gait generator
gait_generator:register_sensor_provider("rangefinder", rangefinder_provider)
gait_generator:register_sensor_provider("ahrs", ahrs_provider)
gait_generator:register_sensor_provider("terrain", terrain_provider)

print("Sensor providers registered successfully.\n")

-- Start the gait generator
gait_generator:start()

-- Simulate terrain adaptation over several scenarios
print("=== Scenario 1: Flat Terrain Walking ===")

local dt = 0.05  -- 50ms time steps (20Hz)
local motion_command = {
  velocity = Vec3.new(75, 0, 0),  -- 75 mm/s forward
  turn_rate = 0.0,
  body_pose = Vec3.new(0, 0, 120)
}

-- Simulate 10 steps on flat terrain
for step = 1, 10 do
  local targets = gait_generator:update(dt, motion_command)
  local terrain_data = gait_generator:get_terrain_data()
  
  if step % 5 == 0 then  -- Print every 5th step
    print(string.format("Step %d:", step))
    print(string.format("  Ground height: %.1f mm", terrain_data.current_ground_height))
    print(string.format("  Predicted terrain distance: %.1f mm", terrain_data.predicted_terrain.distance_ahead))
    print(string.format("  Adaptive clearance: %.1f mm", terrain_data.adaptive_clearance))
    
    -- Show attitude compensation
    local compensation = gait_generator:get_terrain_predictor():get_body_attitude_compensation()
    print(string.format("  Body attitude compensation: roll=%.3f, pitch=%.3f", 
          compensation.roll, compensation.pitch))
    
    -- Show adaptive step height for one leg
    local predictor = gait_generator:get_terrain_predictor()
    local leg_pos = Vec3.new(100, 50, 120)
    local target_pos = Vec3.new(150, 50, 120)
    local adaptive_height = predictor:get_adaptive_step_height(40, leg_pos, target_pos)
    print(string.format("  Adaptive step height: %.1f mm (base: 40mm)", adaptive_height))
    print()
  end
end

print("=== Scenario 2: Rough Terrain with Obstacles ===")

-- Simulate rough terrain by changing sensor data
rangefinder_provider:set_mock_data({
  distance = 800,         -- Closer ground (obstacle)
  signal_quality = 75,    -- Lower quality due to rough surface
  vehicle_altitude = 1320
})

-- Add terrain roughness variation
local terrain_heights = {950, 1100, 1250, 1180, 1050, 1300, 1150, 1200}
local height_index = 1

for step = 1, 8 do
  -- Vary terrain height to simulate rough ground
  terrain_provider:set_mock_data({
    height_above_terrain = terrain_heights[height_index],
    terrain_height_amsl = 140 + (height_index * 20)  -- Varying terrain elevation
  })
  height_index = height_index + 1
  
  local targets = gait_generator:update(dt, motion_command)
  local terrain_data = gait_generator:get_terrain_data()
  
  print(string.format("Rough terrain step %d:", step))
  print(string.format("  Ground height: %.1f mm", terrain_data.current_ground_height))
  print(string.format("  Terrain confidence: %.2f", terrain_data.predicted_terrain.confidence))
  
  -- Show how step height adapts to rough terrain
  local predictor = gait_generator:get_terrain_predictor()
  local leg_pos = Vec3.new(100, 50, terrain_data.current_ground_height)
  local target_pos = Vec3.new(150, 50, terrain_data.predicted_terrain.predicted_height or terrain_data.current_ground_height)
  local adaptive_height = predictor:get_adaptive_step_height(40, leg_pos, target_pos)
  print(string.format("  Adaptive step height: %.1f mm (increase: +%.1f mm)", 
        adaptive_height, adaptive_height - 40))
  
  -- Show sensor health
  local sensor_health = terrain_data.sensor_health
  local healthy_sensors = 0
  local total_sensors = 0
  for name, health in pairs(sensor_health) do
    total_sensors = total_sensors + 1
    if health.healthy and health.has_data then
      healthy_sensors = healthy_sensors + 1
    end
  end
  print(string.format("  Sensor health: %d/%d sensors healthy", healthy_sensors, total_sensors))
  print()
end

print("=== Scenario 3: Steep Slope with Body Attitude Compensation ===")

-- Simulate walking on a steep slope
ahrs_provider:set_mock_data({
  attitude = {
    roll = 0.0,     -- No roll
    pitch = 0.262,  -- 15 degrees pitch (steep uphill)
    yaw = 0.0
  },
  velocity = {
    north = 50,     -- Slower on steep terrain
    east = 0,
    down = -25      -- Climbing up
  },
  height_above_ground = 1200
})

-- Adjust motion for uphill climb
motion_command.velocity = Vec3.new(50, 0, 0)  -- Slower forward speed

for step = 1, 5 do
  local targets = gait_generator:update(dt, motion_command)
  local terrain_data = gait_generator:get_terrain_data()
  
  print(string.format("Uphill step %d:", step))
  
  -- Show body attitude compensation in action
  local compensation = gait_generator:get_terrain_predictor():get_body_attitude_compensation()
  print(string.format("  Body pitch: %.3f rad (%.1f degrees)", 
        terrain_data.attitude.pitch, math.deg(terrain_data.attitude.pitch)))
  print(string.format("  Pitch compensation: %.3f rad (%.1f degrees)", 
        compensation.pitch, math.deg(compensation.pitch)))
  
  -- Show how terrain prediction works on slopes
  local predicted = terrain_data.predicted_terrain
  print(string.format("  Predicted terrain ahead: %.1f mm at %.1f mm distance", 
        predicted.predicted_height or 0, predicted.distance_ahead))
  
  print()
end

print("=== Scenario 4: Sensor Failure Recovery ===")

print("Simulating rangefinder failure...")
rangefinder_provider:set_healthy(false)

-- Continue walking with degraded sensor input
for step = 1, 3 do
  local targets = gait_generator:update(dt, motion_command)
  local terrain_data = gait_generator:get_terrain_data()
  
  print(string.format("Degraded sensor step %d:", step))
  
  -- Show fallback behavior
  print(string.format("  Ground height (fallback): %.1f mm", terrain_data.current_ground_height))
  
  -- Show sensor health status
  local sensor_health = terrain_data.sensor_health
  for name, health in pairs(sensor_health) do
    local status = health.healthy and "HEALTHY" or "FAILED"
    local data_status = health.has_data and "DATA" or "NO_DATA"
    print(string.format("  %s: %s, %s", name, status, data_status))
  end
  
  print()
end

print("Restoring rangefinder...")
rangefinder_provider:set_healthy(true)

-- Show recovery
local targets = gait_generator:update(dt, motion_command)
local terrain_data = gait_generator:get_terrain_data()
print("Sensor recovery:")
print(string.format("  Ground height (restored): %.1f mm", terrain_data.current_ground_height))
print()

print("=== Terrain Adaptation Configuration ===")

-- Show terrain predictor configuration
local predictor = gait_generator:get_terrain_predictor()
print("Current terrain adaptation settings:")
print(string.format("  Prediction distance: %.0f mm", predictor:get_config("prediction_distance")))
print(string.format("  Ground clearance margin: %.0f mm", predictor:get_config("ground_clearance_margin")))
print(string.format("  Max step height increase: %.0f mm", predictor:get_config("max_step_height_increase")))
print(string.format("  Terrain smoothing factor: %.2f", predictor:get_config("terrain_smoothing_factor")))
print(string.format("  Attitude compensation: %s", predictor:get_config("attitude_compensation") and "enabled" or "disabled"))
print(string.format("  Max attitude angle: %.3f rad (%.1f degrees)", 
      predictor:get_config("max_attitude_angle"), 
      math.deg(predictor:get_config("max_attitude_angle"))))

print("\n=== Performance Summary ===")

-- Show performance characteristics
local gait_state = gait_generator:get_gait_state()
print(string.format("Gait cycle time: %.2f seconds", gait_state:get_cycle_time()))
print(string.format("Current gait pattern: %s", gait_generator:get_gait_pattern()))

-- Show stability information if available
local stability_analyzer = gait_generator:get_stability_analyzer()
if stability_analyzer then
  print("Stability analysis: enabled")
else
  print("Stability analysis: disabled")
end

print("\n=== Phase 3 Features Demonstrated ===")
print("✓ TerrainPredictor with multi-sensor fusion")
print("✓ Adaptive step height based on terrain roughness")
print("✓ Ground contact detection and prediction")
print("✓ Body attitude compensation for slopes")
print("✓ Sensor health monitoring and fallback behavior")
print("✓ Terrain smoothing for stable locomotion")
print("✓ Real-time terrain adaptation during gait execution")

print("\nPhase 3 terrain adaptation example completed successfully!")
print("The gait generator can now adapt to uneven terrain, slopes, and obstacles")
print("while maintaining stable locomotion through sensor fusion and predictive control.")

-- Stop the gait generator
gait_generator:stop()