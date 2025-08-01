local GaitPattern = require("gait.patterns.gait_pattern")
local Object = require("object")
local Scalar = require("scalar")

--- Static Gait Patterns
--
-- Implements common static gaits where the robot maintains static stability
-- throughout the gait cycle (at least 3 legs always in contact).
local StaticGaits = {}

--- Tripod Gait Pattern
--
-- Classic hexapod gait where legs move in two groups of three.
-- Group 1: front_right, middle_left, rear_right
-- Group 2: front_left, middle_right, rear_left
local TripodGait = Object.new("TripodGait")

function TripodGait.new()
  local instance = GaitPattern.new("tripod", 0.5)  -- 50% duty factor
  
  -- Set phase offsets for tripod pattern
  instance:set_leg_phase_offset("front_right", 0.0)
  instance:set_leg_phase_offset("middle_left", 0.0)
  instance:set_leg_phase_offset("rear_right", 0.0)
  
  instance:set_leg_phase_offset("front_left", 0.5)
  instance:set_leg_phase_offset("middle_right", 0.5)
  instance:set_leg_phase_offset("rear_left", 0.5)
  
  return instance
end

--- Wave Gait Pattern
--
-- Sequential gait where legs lift in a wave pattern around the body.
-- Provides maximum stability but slower movement.
local WaveGait = Object.new("WaveGait")

function WaveGait.new(leg_count)
  Scalar.assert_type(leg_count, "number", true)
  leg_count = leg_count or 6
  
  -- Higher duty factor for more stability
  local duty_factor = (leg_count - 1) / leg_count  -- e.g., 5/6 = 0.833 for hexapod
  local instance = GaitPattern.new("wave", duty_factor)
  
  -- Set phase offsets for wave pattern (sequential)
  local phase_increment = 1.0 / leg_count
  
  -- Standard leg order for wave gait (adapt to leg count)
  local leg_order
  if leg_count == 4 then
    leg_order = {"front_right", "rear_right", "rear_left", "front_left"}
  elseif leg_count == 6 then
    leg_order = {
      "front_right", "middle_right", "rear_right",
      "rear_left", "middle_left", "front_left"
    }
  else
    -- Generic order for other leg counts
    leg_order = {}
    for i = 1, leg_count do
      table.insert(leg_order, "leg_" .. i)
    end
  end
  
  for i, leg_name in ipairs(leg_order) do
    if i <= leg_count then  -- Only set offsets for actual legs
      local offset = (i - 1) * phase_increment
      instance:set_leg_phase_offset(leg_name, offset)
    end
  end
  
  return instance
end

--- Ripple Gait Pattern
--
-- Similar to wave but with overlapping swing phases for faster movement
-- while maintaining static stability.
local RippleGait = Object.new("RippleGait")

function RippleGait.new(leg_count)
  Scalar.assert_type(leg_count, "number", true)
  leg_count = leg_count or 6
  
  -- Moderate duty factor for balance of speed and stability
  local duty_factor = 0.75  -- 75% stance phase
  local instance = GaitPattern.new("ripple", duty_factor)
  
  -- Set phase offsets for ripple pattern
  local phase_increment = 1.0 / leg_count
  
  -- Ripple order: alternating sides (adapt to leg count)
  local leg_order
  if leg_count == 4 then
    leg_order = {"front_right", "rear_left", "front_left", "rear_right"}
  elseif leg_count == 6 then
    leg_order = {
      "front_right", "rear_left", "middle_right", 
      "front_left", "rear_right", "middle_left"
    }
  else
    -- Generic alternating pattern
    leg_order = {}
    for i = 1, leg_count do
      table.insert(leg_order, "leg_" .. i)
    end
  end
  
  for i, leg_name in ipairs(leg_order) do
    if i <= leg_count then  -- Only set offsets for actual legs
      local offset = (i - 1) * phase_increment
      instance:set_leg_phase_offset(leg_name, offset)
    end
  end
  
  return instance
end

--- Quadruped Trot Gait (Static Version)
--
-- For quadruped robots, diagonal legs move together.
-- This is a static version with higher duty factor for stability.
local QuadrupedTrot = Object.new("QuadrupedTrot")

function QuadrupedTrot.new()
  local instance = GaitPattern.new("quadruped_trot", 0.6)  -- 60% duty factor for stability
  
  -- Diagonal pairs move together
  instance:set_leg_phase_offset("front_right", 0.0)
  instance:set_leg_phase_offset("rear_left", 0.0)
  
  instance:set_leg_phase_offset("front_left", 0.5)
  instance:set_leg_phase_offset("rear_right", 0.5)
  
  return instance
end

--- Factory function to create gait patterns by name
--
-- @param gait_name name of the gait pattern
-- @param leg_count number of legs (for gaits that need it)
-- @return GaitPattern instance
function StaticGaits.create(gait_name, leg_count)
  Scalar.assert_type(gait_name, "string")
  Scalar.assert_type(leg_count, "number", true)
  
  if gait_name == "tripod" then
    return TripodGait.new()
  elseif gait_name == "wave" then
    return WaveGait.new(leg_count)
  elseif gait_name == "ripple" then
    return RippleGait.new(leg_count)
  elseif gait_name == "quadruped_trot" then
    return QuadrupedTrot.new()
  else
    error("Unknown static gait pattern: " .. gait_name)
  end
end

--- Get list of available static gait patterns
--
-- @return array of gait pattern names
function StaticGaits.get_available_gaits()
  return {"tripod", "wave", "ripple", "quadruped_trot"}
end

--- Validate that a gait pattern is suitable for given leg count
--
-- @param gait_name name of the gait pattern
-- @param leg_count number of legs
-- @return true if suitable, false otherwise
function StaticGaits.is_suitable_for_legs(gait_name, leg_count)
  Scalar.assert_type(gait_name, "string")
  Scalar.assert_type(leg_count, "number")
  
  if gait_name == "tripod" then
    return leg_count == 6  -- Hexapod only
  elseif gait_name == "wave" or gait_name == "ripple" then
    return leg_count >= 4  -- Works with 4+ legs
  elseif gait_name == "quadruped_trot" then
    return leg_count == 4  -- Quadruped only
  else
    return false
  end
end

StaticGaits.TripodGait = TripodGait
StaticGaits.WaveGait = WaveGait
StaticGaits.RippleGait = RippleGait
StaticGaits.QuadrupedTrot = QuadrupedTrot

return StaticGaits