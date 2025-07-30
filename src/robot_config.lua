local Chain = require("chain")
local Joint = require("joint")
local Link = require("link")
local Object = require("object")
local Scalar = require("scalar")
local Vec3 = require("vec3")
local Angle = require("angle")

--- Chain Builder DSL
--
-- Provides a fluent interface for building kinematic chains
local ChainBuilder = Object.new("ChainBuilder")

--- Robot Configuration Builder
--
-- Provides a DSL for defining robot kinematic configurations that can be
-- converted into Ardumatic Chain objects.
local RobotConfig = Object.new("RobotConfig")

--- Create a new robot configuration
--
-- @param name optional name for the robot configuration
function RobotConfig.new(name)
  Scalar.assert_type(name, "string", true)
  
  return Object.instance({
    _name = name,
    _chains = {}
  }, RobotConfig)
end

--- Add a kinematic chain to the robot configuration
--
-- @param name the name of the chain (e.g., "front_left", "arm_1")
-- @param origin the origin point of the chain as a Vec3
function RobotConfig:add_chain(name, origin)
  Scalar.assert_type(name, "string")
  Object.assert_type(origin, Vec3, true)
  
  local chain_config = {
    name = name,
    origin = origin or Vec3.zero(),
    segments = {}
  }
  
  self._chains[name] = chain_config
  return ChainBuilder.new(chain_config, self)
end

--- Build all chains from the configuration
--
-- @return a table of Chain objects keyed by chain name
function RobotConfig:build_chains()
  local chains = {}
  
  for name, config in pairs(self._chains) do
    local chain = Chain.new(config.origin, config.name)
    
    for _, segment in ipairs(config.segments) do
      local joint = self:_build_joint(segment.joint_config)
      local link = Link.new(segment.link_length, segment.link_name)
      chain:add(joint, link)
    end
    
    chains[name] = chain
  end
  
  return chains
end

--- Build a joint from configuration
--
-- @param joint_config table containing joint configuration
-- @return Joint object
function RobotConfig:_build_joint(joint_config)
  if joint_config.type == "ball" then
    return Joint.ball(
      joint_config.reference_axis,
      joint_config.max_constraint
    )
  elseif joint_config.type == "hinge" then
    return Joint.hinge(
      joint_config.rotation_axis,
      joint_config.reference_axis,
      joint_config.clockwise_constraint,
      joint_config.anticlockwise_constraint
    )
  else
    error("Unknown joint type: " .. tostring(joint_config.type))
  end
end

RobotConfig.name = Object.reader("name")

function ChainBuilder.new(chain_config, parent_config)
  return Object.instance({
    _config = chain_config,
    _parent_config = parent_config
  }, ChainBuilder)
end

--- Add a ball joint to the chain
--
-- @param reference_axis Vec3 defining the initial direction
-- @param max_constraint optional Angle for maximum deflection
function ChainBuilder:ball_joint(reference_axis, max_constraint)
  Object.assert_type(reference_axis, Vec3)
  Object.assert_type(max_constraint, Angle, true)
  
  self._pending_joint = {
    type = "ball",
    reference_axis = reference_axis,
    max_constraint = max_constraint
  }
  
  return self
end

--- Add a hinge joint to the chain
--
-- @param rotation_axis Vec3 defining the rotation axis
-- @param reference_axis Vec3 defining the reference direction
-- @param clockwise_constraint optional Angle for clockwise limit
-- @param anticlockwise_constraint optional Angle for anticlockwise limit
function ChainBuilder:hinge_joint(rotation_axis, reference_axis, clockwise_constraint, anticlockwise_constraint)
  Object.assert_type(rotation_axis, Vec3)
  Object.assert_type(reference_axis, Vec3)
  Object.assert_type(clockwise_constraint, Angle, true)
  Object.assert_type(anticlockwise_constraint, Angle, true)
  
  self._pending_joint = {
    type = "hinge",
    rotation_axis = rotation_axis,
    reference_axis = reference_axis,
    clockwise_constraint = clockwise_constraint,
    anticlockwise_constraint = anticlockwise_constraint
  }
  
  return self
end

--- Add a link to complete the current segment
--
-- @param length the length of the link
-- @param name optional name for the link
function ChainBuilder:link(length, name)
  Scalar.assert_type(length, "number")
  Scalar.assert_type(name, "string", true)
  
  if not self._pending_joint then
    error("Cannot add link without a joint. Call ball_joint() or hinge_joint() first.")
  end
  
  local segment = {
    joint_config = self._pending_joint,
    link_length = length,
    link_name = name
  }
  
  table.insert(self._config.segments, segment)
  self._pending_joint = nil
  
  return self
end

--- Finish building this chain and return to the robot config
function ChainBuilder:done()
  if self._pending_joint then
    error("Incomplete segment: joint defined but no link added")
  end
  
  return self._parent_config
end

return RobotConfig