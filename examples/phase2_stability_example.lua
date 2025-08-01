-- Example: Phase 2 Stability and Dynamic Gaits
-- This demonstrates the new stability analysis and dynamic gait features

-- Add src to package path
package.path = package.path .. ";./src/?.lua"

local RobotBuilder = require("robot_builder")
local GaitGenerator = require("gait.gait_generator")
local StabilityAnalyzer = require("gait.stability_analyzer")
local DynamicGaits = require("gait.patterns.dynamic_gaits")
local Vec3 = require("vec3")

print("=== Ardumatic Phase 2: Stability & Dynamic Gaits ===\n")

-- Create a quadruped robot for dynamic gait demonstration
local robot_config = RobotBuilder.quadruped(
  100,  -- leg_spacing
  50,   -- coxa_length
  70,   -- femur_length
  90    -- tibia_length
)

print("✓ Created quadruped robot configuration")

-- Create gait generator with Phase 2 features enabled
local gait_gen = GaitGenerator.new(robot_config, {
  step_height = 30,
  cycle_time = 1.5,
  enable_stability_check = true,
  enable_dynamic_gaits = true,
  auto_gait_selection = true,
  default_gait = "quadruped_trot"
})

print("✓ Created gait generator with stability analysis")
print("  Available gaits:", table.concat(gait_gen:get_available_gaits(), ", "))

-- Get the stability analyzer
local stability_analyzer = gait_gen:get_stability_analyzer()
print("✓ Stability analyzer enabled")

-- Start with static gait
gait_gen:start()
print("\n=== Testing Static Stability ===")

-- Simulate some steps to get leg positions
local motion_command = {
  velocity = Vec3.new(30, 0, 0),  -- Slow forward movement
  turn_rate = 0.0
}

for step = 1, 5 do
  local targets = gait_gen:update(0.1, motion_command)
  
  if step == 5 then
    -- Analyze stability at this point
    local gait_state = gait_gen:get_gait_state()
    local stance_legs = {}
    local leg_positions = {}
    
    for _, leg_name in ipairs(gait_state:get_leg_names()) do
      local pos = gait_state:get_leg_position(leg_name)
      leg_positions[leg_name] = pos
      
      if gait_state:is_leg_stance(leg_name) then
        table.insert(stance_legs, leg_name)
      end
    end
    
    -- Validate stability
    local is_stable, margin, com = stability_analyzer:validate_stability(
      leg_positions, stance_legs, Vec3.zero()
    )
    
    print(string.format("Stability check: %s (margin: %.1f mm)", 
                       is_stable and "STABLE" or "UNSTABLE", margin))
    print(string.format("Centre of mass: (%.1f, %.1f, %.1f)", 
                       com:x(), com:y(), com:z()))
    print("Stance legs:", table.concat(stance_legs, ", "))
    
    -- Get stability recommendations
    local recommendations = stability_analyzer:get_stability_recommendations(margin)
    print("Stability recommendations:")
    print(string.format("  Step height: %.0f mm", recommendations.step_height))
    print(string.format("  Cycle time: %.1f s", recommendations.cycle_time))
    print(string.format("  Max velocity: %.0f mm/s", recommendations.max_velocity))
  end
end

-- Test dynamic gait switching
print("\n=== Testing Dynamic Gaits ===")

-- Switch to dynamic trot
print("Switching to dynamic trot...")
gait_gen:set_gait_pattern("dynamic_trot", true)  -- Use smooth transition

-- Wait for transition to complete
local transition_manager = gait_gen:get_gait_transition()
while transition_manager:is_transitioning() do
  gait_gen:update(0.1, motion_command)
  local progress = transition_manager:get_progress()
  if math.floor(progress * 10) % 3 == 0 then  -- Print occasionally
    print(string.format("  Transition progress: %.0f%%", progress * 100))
  end
end

print("✓ Transition to dynamic trot complete")

-- Test higher speed with dynamic gait
motion_command.velocity = Vec3.new(80, 0, 0)  -- Higher speed
print(string.format("Increasing speed to %.0f mm/s", motion_command.velocity:length()))

for step = 1, 10 do
  local targets = gait_gen:update(0.1, motion_command)
  local margin = gait_gen:get_last_stability_margin()
  
  if step % 3 == 0 then
    print(string.format("Step %d: Stability margin = %.1f mm", step, margin))
    
    if margin < 10 then
      print("  ⚠️  Low stability margin detected")
    end
  end
end

-- Test bound gait
print("\n=== Testing Bound Gait ===")
gait_gen:set_gait_pattern("bound", true)

-- Wait for transition
while transition_manager:is_transitioning() do
  gait_gen:update(0.1, motion_command)
end

print("✓ Switched to bound gait")

-- Test aerial phase detection
local bound_gait = DynamicGaits.create("bound")
local leg_names = {"front_right", "front_left", "rear_right", "rear_left"}
local has_aerial = DynamicGaits.has_aerial_phase(bound_gait, leg_names)
local min_stance = DynamicGaits.get_min_stance_legs(bound_gait, leg_names)

print(string.format("Bound gait analysis:"))
print(string.format("  Has aerial phase: %s", has_aerial and "YES" or "NO"))
print(string.format("  Minimum stance legs: %d", min_stance))

-- Get velocity requirements
local velocity_req = DynamicGaits.get_velocity_requirements("bound")
print(string.format("  Minimum velocity: %.0f mm/s", velocity_req.min_velocity))
print(string.format("  Recommended velocity: %.0f mm/s", velocity_req.recommended_velocity))

-- Test very high speed
motion_command.velocity = Vec3.new(velocity_req.recommended_velocity, 0, 0)
print(string.format("\nTesting at recommended velocity: %.0f mm/s", velocity_req.recommended_velocity))

for step = 1, 5 do
  local targets = gait_gen:update(0.1, motion_command)
  local margin = gait_gen:get_last_stability_margin()
  
  print(string.format("High-speed step %d: Stability margin = %.1f mm", step, margin))
end

-- Test gallop gait (most dynamic)
print("\n=== Testing Gallop Gait ===")
gait_gen:set_gait_pattern("gallop", true)

while transition_manager:is_transitioning() do
  gait_gen:update(0.1, motion_command)
end

print("✓ Switched to gallop gait")

local gallop_req = DynamicGaits.get_velocity_requirements("gallop")
motion_command.velocity = Vec3.new(gallop_req.recommended_velocity, 0, 0)
print(string.format("Testing gallop at %.0f mm/s", gallop_req.recommended_velocity))

for step = 1, 5 do
  local targets = gait_gen:update(0.1, motion_command)
  local margin = gait_gen:get_last_stability_margin()
  
  print(string.format("Gallop step %d: Stability margin = %.1f mm", step, margin))
  
  if margin < 0 then
    print("  ⚠️  Dynamic instability - relying on momentum")
  end
end

-- Test automatic gait selection under stability constraints
print("\n=== Testing Automatic Gait Selection ===")

-- Create a scenario with poor stability (simulated by very high speed)
motion_command.velocity = Vec3.new(250, 0, 0)  -- Excessive speed
print("Testing with excessive velocity to trigger automatic gait adjustment...")

local original_gait = gait_gen:get_gait_pattern()
print(string.format("Starting gait: %s", original_gait))

for step = 1, 10 do
  local targets = gait_gen:update(0.1, motion_command)
  local current_gait = gait_gen:get_gait_pattern()
  local margin = gait_gen:get_last_stability_margin()
  
  if step % 3 == 0 then
    print(string.format("Step %d: Gait = %s, Margin = %.1f mm", 
                       step, current_gait, margin))
    
    if current_gait ~= original_gait then
      print("  ✓ Automatic gait change detected for stability")
    end
  end
end

-- Stop gait
gait_gen:stop()
print("\n✓ Stopped gait generation")

print("\n=== Phase 2 Features Demonstrated ===")
print("✓ Stability analysis with centre of mass calculation")
print("✓ Support polygon validation")
print("✓ Dynamic gait patterns (trot, bound, gallop)")
print("✓ Smooth gait transitions")
print("✓ Automatic stability-based adjustments")
print("✓ Velocity requirements for dynamic gaits")
print("✓ Aerial phase detection")
print("\nPhase 2 implementation complete and ready for Phase 3!")