local RobotConfig = require("robot_config")
local Vec3 = require("vec3")
local Angle = require("angle")
local Object = require("object")
local Scalar = require("scalar")

--- Robot Builder
--
-- Provides high-level factory functions for creating common robot configurations
local RobotBuilder = {}

--- Create a hexapod robot configuration
--
-- Creates a 6-legged robot with standard leg placement and 3-segment legs
-- @param leg_spacing distance between leg attachment points
-- @param coxa_length length of the coxa (hip) segment
-- @param femur_length length of the femur (thigh) segment  
-- @param tibia_length length of the tibia (shin) segment
-- @return RobotConfig object
function RobotBuilder.hexapod(leg_spacing, coxa_length, femur_length, tibia_length)
  leg_spacing = leg_spacing or 100
  coxa_length = coxa_length or 50
  femur_length = femur_length or 75
  tibia_length = tibia_length or 100
  
  local config = RobotConfig.new("hexapod")
  
  -- Standard hexapod leg positions (60-degree spacing)
  local leg_positions = {
    front_right = Vec3.new(leg_spacing * 0.866, leg_spacing * 0.5, 0),
    middle_right = Vec3.new(leg_spacing, 0, 0),
    rear_right = Vec3.new(leg_spacing * 0.866, -leg_spacing * 0.5, 0),
    rear_left = Vec3.new(-leg_spacing * 0.866, -leg_spacing * 0.5, 0),
    middle_left = Vec3.new(-leg_spacing, 0, 0),
    front_left = Vec3.new(-leg_spacing * 0.866, leg_spacing * 0.5, 0)
  }
  
  -- Create each leg with standard 3-segment configuration
  for leg_name, position in pairs(leg_positions) do
    config:add_chain(leg_name, position)
      :hinge_joint(Vec3.up(), Vec3.forward(), Angle.from_degrees(45), Angle.from_degrees(45))
      :link(coxa_length, "coxa")
      :hinge_joint(Vec3.up(), Vec3.forward(), Angle.from_degrees(90), Angle.from_degrees(90))
      :link(femur_length, "femur")
      :hinge_joint(Vec3.up(), Vec3.forward(), Angle.from_degrees(120), Angle.from_degrees(30))
      :link(tibia_length, "tibia")
  end
  
  return config
end

--- Create a quadruped robot configuration
--
-- Creates a 4-legged robot with standard leg placement and 3-segment legs
-- @param leg_spacing distance between leg attachment points
-- @param coxa_length length of the coxa (hip) segment
-- @param femur_length length of the femur (thigh) segment
-- @param tibia_length length of the tibia (shin) segment
-- @return RobotConfig object
function RobotBuilder.quadruped(leg_spacing, coxa_length, femur_length, tibia_length)
  leg_spacing = leg_spacing or 100
  coxa_length = coxa_length or 60
  femur_length = femur_length or 80
  tibia_length = tibia_length or 120
  
  local config = RobotConfig.new("quadruped")
  
  -- Standard quadruped leg positions
  local leg_positions = {
    front_right = Vec3.new(leg_spacing * 0.5, leg_spacing * 0.5, 0),
    front_left = Vec3.new(-leg_spacing * 0.5, leg_spacing * 0.5, 0),
    rear_right = Vec3.new(leg_spacing * 0.5, -leg_spacing * 0.5, 0),
    rear_left = Vec3.new(-leg_spacing * 0.5, -leg_spacing * 0.5, 0)
  }
  
  -- Create each leg with standard 3-segment configuration
  for leg_name, position in pairs(leg_positions) do
    config:add_chain(leg_name, position)
      :hinge_joint(Vec3.up(), Vec3.forward(), Angle.from_degrees(45), Angle.from_degrees(45))
      :link(coxa_length, "coxa")
      :hinge_joint(Vec3.up(), Vec3.forward(), Angle.from_degrees(90), Angle.from_degrees(90))
      :link(femur_length, "femur")
      :hinge_joint(Vec3.up(), Vec3.forward(), Angle.from_degrees(120), Angle.from_degrees(30))
      :link(tibia_length, "tibia")
  end
  
  return config
end

--- Create a simple robotic arm configuration
--
-- Creates a multi-segment robotic arm
-- @param base_position Vec3 position of the arm base
-- @param segment_lengths array of segment lengths
-- @param joint_constraints array of joint constraint angles (optional)
-- @return RobotConfig object
function RobotBuilder.robotic_arm(base_position, segment_lengths, joint_constraints)
  Object.assert_type(base_position, Vec3, true)
  base_position = base_position or Vec3.zero()
  segment_lengths = segment_lengths or {100, 80, 60}
  joint_constraints = joint_constraints or {}
  
  local config = RobotConfig.new("robotic_arm")
  local chain_builder = config:add_chain("arm", base_position)
  
  -- Build arm segments
  for i, length in ipairs(segment_lengths) do
    local constraint = joint_constraints[i] or Angle.from_degrees(90)
    
    chain_builder:hinge_joint(Vec3.up(), Vec3.forward(), constraint, constraint)
      :link(length, "segment_" .. i)
  end
  
  return config
end

--- Create a custom robot from a configuration table
--
-- @param robot_spec table containing robot specification
-- @return RobotConfig object
function RobotBuilder.from_spec(robot_spec)
  Scalar.assert_type(robot_spec.name, "string", true)
  assert(robot_spec.chains, "Robot specification must include chains")
  
  local config = RobotConfig.new(robot_spec.name)
  
  for chain_name, chain_spec in pairs(robot_spec.chains) do
    local origin = Vec3.zero()
    if chain_spec.origin then
      origin = Vec3.new(chain_spec.origin[1], chain_spec.origin[2], chain_spec.origin[3])
    end
    
    local chain_builder = config:add_chain(chain_name, origin)
    
    for _, segment in ipairs(chain_spec.segments) do
      -- Parse joint configuration
      if segment.joint.type == "ball" then
        local ref_axis = Vec3.new(segment.joint.reference_axis[1], 
                                 segment.joint.reference_axis[2], 
                                 segment.joint.reference_axis[3])
        local max_constraint = segment.joint.max_constraint and 
                              Angle.from_degrees(segment.joint.max_constraint) or nil
        
        chain_builder:ball_joint(ref_axis, max_constraint)
      elseif segment.joint.type == "hinge" then
        local rot_axis = Vec3.new(segment.joint.rotation_axis[1],
                                 segment.joint.rotation_axis[2],
                                 segment.joint.rotation_axis[3])
        local ref_axis = Vec3.new(segment.joint.reference_axis[1],
                                 segment.joint.reference_axis[2],
                                 segment.joint.reference_axis[3])
        local cw_constraint = segment.joint.clockwise_constraint and
                             Angle.from_degrees(segment.joint.clockwise_constraint) or nil
        local ccw_constraint = segment.joint.anticlockwise_constraint and
                              Angle.from_degrees(segment.joint.anticlockwise_constraint) or nil
        
        chain_builder:hinge_joint(rot_axis, ref_axis, cw_constraint, ccw_constraint)
      else
        error("Unknown joint type: " .. tostring(segment.joint.type))
      end
      
      -- Add link
      chain_builder:link(segment.link.length, segment.link.name)
    end
  end
  
  return config
end

return RobotBuilder