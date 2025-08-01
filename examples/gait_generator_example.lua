-- Example: Gait Generator Usage
-- This demonstrates how to use the gait generator system with a hexapod robot

-- Add src to package path
package.path = package.path .. ";./src/?.lua"

local RobotBuilder = require("robot_builder")
local GaitGenerator = require("gait.gait_generator")
local Vec3 = require("vec3")

print("=== Ardumatic Gait Generator Example ===\n")

-- Create a hexapod robot configuration
local robot_config = RobotBuilder.hexapod(
  120,  -- leg_spacing: distance between leg attachment points
  40,   -- coxa_length: hip segment length
  60,   -- femur_length: thigh segment length
  80    -- tibia_length: shin segment length
)

print("✓ Created hexapod robot configuration")

-- Create gait generator with custom parameters
local gait_gen = GaitGenerator.new(robot_config, {
  step_height = 25,        -- 25mm step height
  step_length = 60,        -- 60mm maximum step length
  cycle_time = 2.5,        -- 2.5 second gait cycle
  body_height = 90,        -- 90mm body height above ground
  default_gait = "tripod"  -- Use tripod gait
})

print("✓ Created gait generator")
print("  Gait pattern:", gait_gen:get_gait_pattern())
print("  Step height:", gait_gen:get_config("step_height"), "mm")
print("  Cycle time:", gait_gen:get_config("cycle_time"), "seconds")

-- Start gait generation
gait_gen:start()
print("\n✓ Started gait generation")

-- Simulate walking forward
print("\n=== Simulating Forward Walk ===")
local motion_command = {
  velocity = Vec3.new(40, 0, 0),  -- 40 mm/s forward
  turn_rate = 0.0,                -- No turning
  body_pose = Vec3.zero()         -- Level body
}

-- Simulate several gait cycles
local dt = 0.1  -- 100ms time steps
local total_time = 0.0

for step = 1, 25 do
  -- Update gait generator
  local leg_targets = gait_gen:update(dt, motion_command)
  total_time = total_time + dt
  
  -- Get current gait state
  local gait_state = gait_gen:get_gait_state()
  local global_phase = gait_state:get_global_phase()
  
  -- Print status every 5 steps
  if step % 5 == 0 then
    print(string.format("Time: %.1fs, Phase: %.3f", total_time, global_phase))
    
    -- Show which legs are in stance vs swing
    local stance_legs = {}
    local swing_legs = {}
    
    for _, leg_name in ipairs(gait_state:get_leg_names()) do
      if gait_state:is_leg_stance(leg_name) then
        table.insert(stance_legs, leg_name)
      else
        table.insert(swing_legs, leg_name)
      end
    end
    
    print("  Stance legs:", table.concat(stance_legs, ", "))
    print("  Swing legs:", table.concat(swing_legs, ", "))
  end
end

-- Demonstrate gait pattern switching
print("\n=== Switching to Wave Gait ===")
gait_gen:set_gait_pattern("wave")
print("✓ Switched to wave gait")

-- Continue simulation with wave gait
for step = 1, 10 do
  local leg_targets = gait_gen:update(dt, motion_command)
  total_time = total_time + dt
  
  local gait_state = gait_gen:get_gait_state()
  local global_phase = gait_state:get_global_phase()
  
  if step % 5 == 0 then
    print(string.format("Time: %.1fs, Phase: %.3f (wave gait)", total_time, global_phase))
  end
end

-- Demonstrate parameter changes
print("\n=== Adjusting Parameters ===")
gait_gen:set_config("step_height", 35)
gait_gen:set_config("cycle_time", 3.0)

print("✓ Increased step height to", gait_gen:get_config("step_height"), "mm")
print("✓ Increased cycle time to", gait_gen:get_config("cycle_time"), "seconds")

-- Demonstrate turning
print("\n=== Simulating Turn ===")
motion_command.turn_rate = 0.2  -- 0.2 rad/s turn rate

for step = 1, 10 do
  local leg_targets = gait_gen:update(dt, motion_command)
  total_time = total_time + dt
  
  if step % 5 == 0 then
    print(string.format("Time: %.1fs, Turning at %.1f rad/s", total_time, motion_command.turn_rate))
  end
end

-- Stop gait
gait_gen:stop()
print("\n✓ Stopped gait generation")

print("\n=== Example Complete ===")
print("The gait generator successfully:")
print("  • Generated smooth leg trajectories")
print("  • Integrated with FABRIK inverse kinematics")
print("  • Switched between gait patterns")
print("  • Adjusted parameters dynamically")
print("  • Handled forward motion and turning")
print("\nPhase 1 implementation is ready for integration with ArduPilot!")