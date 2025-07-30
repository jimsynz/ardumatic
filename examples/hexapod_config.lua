-- Example hexapod robot configuration
-- This demonstrates how to define a 6-legged walking robot using Ardumatic

local RobotBuilder = require("robot_builder")
local ConfigValidator = require("config_validator")

-- Create a hexapod with custom dimensions
local hexapod = RobotBuilder.hexapod(
  120,  -- leg_spacing: distance between leg attachment points
  40,   -- coxa_length: hip segment length
  60,   -- femur_length: thigh segment length
  80    -- tibia_length: shin segment length
)

-- Validate the configuration
local validator = ConfigValidator.new()
if validator:validate(hexapod) then
  print("Hexapod configuration is valid!")
  
  -- Build the kinematic chains
  local chains = hexapod:build_chains()
  
  -- Print information about each leg
  for name, chain in pairs(chains) do
    print(string.format("Leg '%s': %d segments, reach = %.1f", 
                       name, chain:length(), chain:reach()))
  end
  
  -- Example: Access a specific leg for inverse kinematics
  local front_right_leg = chains.front_right
  if front_right_leg then
    print(string.format("Front right leg end position: %s", 
                       front_right_leg:end_location()))
  end
  
else
  print("Hexapod configuration has errors:")
  for _, error in ipairs(validator:get_errors()) do
    print("  ERROR: " .. error)
  end
  
  for _, warning in ipairs(validator:get_warnings()) do
    print("  WARNING: " .. warning)
  end
end

return hexapod