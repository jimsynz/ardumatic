-- Example robotic arm configuration
-- This demonstrates how to define a multi-segment robotic arm

local RobotBuilder = require("robot_builder")
local RobotConfig = require("robot_config")
local ConfigValidator = require("config_validator")
local Vec3 = require("vec3")
local Angle = require("angle")

-- Method 1: Using the builder helper
print("=== Method 1: Using RobotBuilder.robotic_arm ===")

local arm_segments = {120, 100, 80, 60}  -- Decreasing segment lengths
local arm_constraints = {
  Angle.from_degrees(180),  -- Base rotation: full rotation
  Angle.from_degrees(120),  -- Shoulder: wide range
  Angle.from_degrees(90),   -- Elbow: moderate range
  Angle.from_degrees(60)    -- Wrist: limited range
}

local simple_arm = RobotBuilder.robotic_arm(
  Vec3.new(0, 0, 100),  -- Mounted 100mm above origin
  arm_segments,
  arm_constraints
)

-- Validate and build
local validator = ConfigValidator.new()
if validator:validate(simple_arm) then
  local chains = simple_arm:build_chains()
  local arm_chain = chains.arm
  print(string.format("Simple arm: %d segments, reach = %.1f", 
                     arm_chain:length(), arm_chain:reach()))
end

-- Method 2: Manual configuration with mixed joint types
print("\n=== Method 2: Manual configuration with ball joints ===")

local advanced_arm = RobotConfig.new("advanced_robotic_arm")

advanced_arm:add_chain("manipulator", Vec3.new(0, 0, 150))
  -- Base rotation (hinge around Z-axis)
  :hinge_joint(Vec3.up(), Vec3.forward(), Angle.from_degrees(180), Angle.from_degrees(180))
  :link(30, "base_rotator")
  
  -- Shoulder (ball joint for 3D movement)
  :ball_joint(Vec3.forward(), Angle.from_degrees(90))
  :link(100, "upper_arm")
  
  -- Elbow (hinge joint)
  :hinge_joint(Vec3.right(), Vec3.forward(), Angle.from_degrees(135), Angle.from_degrees(5))
  :link(80, "forearm")
  
  -- Wrist rotation (hinge around arm axis)
  :hinge_joint(Vec3.forward(), Vec3.up(), Angle.from_degrees(180), Angle.from_degrees(180))
  :link(20, "wrist_rotator")
  
  -- Wrist pitch (hinge perpendicular to arm)
  :hinge_joint(Vec3.right(), Vec3.forward(), Angle.from_degrees(90), Angle.from_degrees(90))
  :link(40, "end_effector")

-- Validate the advanced arm
if validator:validate(advanced_arm) then
  print("Advanced arm configuration is valid!")
  
  local chains = advanced_arm:build_chains()
  local manipulator = chains.manipulator
  
  print(string.format("Advanced arm: %d segments, reach = %.1f", 
                     manipulator:length(), manipulator:reach()))
  print(string.format("End effector position: %s", manipulator:end_location()))
  
  -- Demonstrate chain iteration
  print("\nArm segments (root to tip):")
  for link_state in manipulator:forwards() do
    print(string.format("  Joint at %s -> Link tip at %s", 
                       link_state.root_location, link_state.tip_location))
  end
  
else
  print("Advanced arm configuration has errors:")
  for _, error in ipairs(validator:get_errors()) do
    print("  ERROR: " .. error)
  end
end

-- Method 3: Dual-arm configuration
print("\n=== Method 3: Dual-arm robot ===")

local dual_arm = RobotConfig.new("dual_arm_robot")

-- Left arm
dual_arm:add_chain("left_arm", Vec3.new(-100, 0, 200))
  :hinge_joint(Vec3.up(), Vec3.forward(), Angle.from_degrees(90), Angle.from_degrees(90))
  :link(80, "left_upper")
  :hinge_joint(Vec3.right(), Vec3.forward(), Angle.from_degrees(120), Angle.from_degrees(10))
  :link(70, "left_lower")
  :ball_joint(Vec3.forward(), Angle.from_degrees(45))
  :link(30, "left_hand")

-- Right arm (mirrored)
dual_arm:add_chain("right_arm", Vec3.new(100, 0, 200))
  :hinge_joint(Vec3.up(), Vec3.forward(), Angle.from_degrees(90), Angle.from_degrees(90))
  :link(80, "right_upper")
  :hinge_joint(Vec3.left(), Vec3.forward(), Angle.from_degrees(120), Angle.from_degrees(10))
  :link(70, "right_lower")
  :ball_joint(Vec3.forward(), Angle.from_degrees(45))
  :link(30, "right_hand")

if validator:validate(dual_arm) then
  print("Dual-arm configuration is valid!")
  
  local chains = dual_arm:build_chains()
  
  for name, chain in pairs(chains) do
    print(string.format("%s: %d segments, reach = %.1f, origin = %s", 
                       name, chain:length(), chain:reach(), chain:origin()))
  end
end

return {
  simple_arm = simple_arm,
  advanced_arm = advanced_arm,
  dual_arm = dual_arm
}