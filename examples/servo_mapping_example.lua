-- Example demonstrating servo channel mapping and validation
-- This shows how to configure a robot with servo channel constraints

local RobotBuilder = require("robot_builder")
local ConfigValidator = require("config_validator")
local ServoMapper = require("servo_mapper")

print("=== Servo Channel Mapping Example ===\n")

-- Example 1: Simple quadruped on a Pixhawk (16 channels)
print("Example 1: Quadruped on Pixhawk")
print("--------------------------------")

local quadruped = RobotBuilder.quadruped(150, 50, 75, 100)

-- Create validator for Pixhawk platform with some reserved channels
local reserved_channels = {
  flight_control = {1, 2, 3, 4},  -- Reserved for flight control motors
  camera_gimbal = {5, 6}          -- Reserved for camera gimbal
}

local validator = ConfigValidator.new("PIXHAWK", nil, reserved_channels)

if validator:validate(quadruped) then
  print("✓ Quadruped configuration is valid!")
  
  -- Get servo mapping
  local mapping = validator:get_servo_mapping(quadruped)
  print("\n" .. validator._servo_mapper:get_mapping_summary(mapping))
  
  -- Get ArduPilot parameters
  local parameters = validator:get_servo_parameters(quadruped)
  print("\nArduPilot Parameters:")
  for param_name, value in pairs(parameters) do
    print(string.format("  %s = %d", param_name, value))
  end
  
else
  print("✗ Quadruped configuration failed:")
  for _, error in ipairs(validator:get_errors()) do
    print("  ERROR: " .. error)
  end
end

print("\n" .. string.rep("=", 60) .. "\n")

-- Example 2: Large hexapod on constrained platform
print("Example 2: Hexapod on F4-based autopilot (8 channels)")
print("-----------------------------------------------------")

local hexapod = RobotBuilder.hexapod(200, 60, 80, 120)

-- F4-based autopilot with limited channels
local f4_validator = ConfigValidator.new("GENERIC_F4", 8, {
  flight_control = {1, 2, 3, 4}  -- Only 4 channels reserved, leaving 4 for kinematics
})

if f4_validator:validate(hexapod) then
  print("✓ Hexapod fits on F4 platform")
  local mapping = f4_validator:get_servo_mapping(hexapod)
  print("\n" .. f4_validator._servo_mapper:get_mapping_summary(mapping))
else
  print("✗ Hexapod does not fit on F4 platform:")
  for _, error in ipairs(f4_validator:get_errors()) do
    print("  ERROR: " .. error)
  end
  for _, warning in ipairs(f4_validator:get_warnings()) do
    print("  WARNING: " .. warning)
  end
end

print("\n" .. string.rep("=", 60) .. "\n")

-- Example 3: Custom servo mapper usage
print("Example 3: Direct servo mapper usage")
print("------------------------------------")

local mapper = ServoMapper.new("CUBE_ORANGE", 16)

-- Reserve channels for various purposes
mapper:reserve_channels({1, 2, 3, 4, 5, 6, 7, 8}, "octocopter_motors")
mapper:reserve_channels({9, 10}, "camera_gimbal")
mapper:reserve_channels({11}, "landing_gear")

-- Test if a simple arm would fit
local simple_arm = RobotBuilder.robotic_arm()
local fit_success, fit_error = mapper:validate_robot_fit(simple_arm)

if fit_success then
  print("✓ Robotic arm fits with current reservations")
  local arm_mapping = mapper:map_robot(simple_arm)
  print("\n" .. mapper:get_mapping_summary(arm_mapping))
else
  print("✗ Robotic arm does not fit: " .. fit_error)
end

print("\n" .. string.rep("=", 60) .. "\n")

-- Example 4: Platform comparison
print("Example 4: Platform comparison for same robot")
print("---------------------------------------------")

local test_robot = RobotBuilder.quadruped(100, 40, 60, 80)

local platforms = {"GENERIC_F4", "PIXHAWK", "CUBE_ORANGE"}
local reserved = {flight_control = {1, 2, 3, 4}}

for _, platform in ipairs(platforms) do
  local platform_validator = ConfigValidator.new(platform, nil, reserved)
  local success = platform_validator:validate(test_robot)
  
  if success then
    local mapping = platform_validator:get_servo_mapping(test_robot)
    print(string.format("✓ %s: %d/%d channels used", 
                       platform, mapping.channels_used, 
                       platform_validator._servo_mapper._max_channels))
  else
    print(string.format("✗ %s: insufficient channels", platform))
  end
end

print("\n=== Summary ===")
print("The servo mapping system provides:")
print("• Automatic assignment of hinge joints to servo channels")
print("• Validation against platform servo channel limits")
print("• Support for reserving channels for other functions")
print("• Generation of ArduPilot parameter configurations")
print("• Detection of ball joints requiring multiple servos")
print("• Platform-specific channel limit enforcement")