local GaitPattern = require("gait.patterns.gait_pattern")
local Object = require("object")
local Scalar = require("scalar")

--- Dynamic Gait Patterns
--
-- Implements dynamic gaits where the robot may have periods of aerial phase
-- (no legs in contact) and relies on momentum for stability.
local DynamicGaits = {}

--- Dynamic Trot Gait
--
-- Fast diagonal gait where diagonal leg pairs move together with lower duty factor.
-- Suitable for quadrupeds and can achieve higher speeds than static gaits.
local DynamicTrot = Object.new("DynamicTrot")

function DynamicTrot.new()
  local instance = GaitPattern.new("dynamic_trot", 0.6)  -- 60% duty factor to maintain ground contact
  
  -- Diagonal pairs move together
  instance:set_leg_phase_offset("front_right", 0.0)
  instance:set_leg_phase_offset("rear_left", 0.0)
  
  instance:set_leg_phase_offset("front_left", 0.5)
  instance:set_leg_phase_offset("rear_right", 0.5)
  
  return instance
end

--- Bound Gait
--
-- Dynamic gait where front legs move together, then rear legs move together.
-- Creates a bounding motion similar to rabbits or dogs at high speed.
local BoundGait = Object.new("BoundGait")

function BoundGait.new()
  local instance = GaitPattern.new("bound", 0.35)  -- 35% duty factor for dynamic motion
  
  -- Front legs move together
  instance:set_leg_phase_offset("front_right", 0.0)
  instance:set_leg_phase_offset("front_left", 0.0)
  
  -- Rear legs move together, offset by half cycle
  instance:set_leg_phase_offset("rear_right", 0.5)
  instance:set_leg_phase_offset("rear_left", 0.5)
  
  return instance
end

--- Gallop Gait
--
-- Asymmetric dynamic gait with complex timing pattern.
-- Most dynamic gait with significant aerial phases.
local GallopGait = Object.new("GallopGait")

function GallopGait.new()
  local instance = GaitPattern.new("gallop", 0.25)  -- 25% duty factor for maximum speed
  
  -- Gallop sequence: lead front, other front, lead rear, other rear
  -- Using right lead gallop pattern
  instance:set_leg_phase_offset("front_right", 0.0)    -- Lead front
  instance:set_leg_phase_offset("front_left", 0.125)   -- Other front
  instance:set_leg_phase_offset("rear_right", 0.25)    -- Lead rear  
  instance:set_leg_phase_offset("rear_left", 0.375)    -- Other rear
  
  return instance
end

--- Pronk Gait
--
-- All legs move in unison - maximum aerial phase.
-- Used for jumping or very dynamic movement.
local PronkGait = Object.new("PronkGait")

function PronkGait.new()
  local instance = GaitPattern.new("pronk", 0.3)  -- 30% duty factor
  
  -- All legs move together
  instance:set_leg_phase_offset("front_right", 0.0)
  instance:set_leg_phase_offset("front_left", 0.0)
  instance:set_leg_phase_offset("rear_right", 0.0)
  instance:set_leg_phase_offset("rear_left", 0.0)
  
  return instance
end

--- Fast Tripod Gait
--
-- Dynamic version of tripod gait with lower duty factor for hexapods.
-- Maintains tripod stability pattern but allows for faster movement.
local FastTripodGait = Object.new("FastTripodGait")

function FastTripodGait.new()
  local instance = GaitPattern.new("fast_tripod", 0.35)  -- 35% duty factor
  
  -- Group 1 legs (tripod pattern)
  instance:set_leg_phase_offset("front_right", 0.0)
  instance:set_leg_phase_offset("middle_left", 0.0)
  instance:set_leg_phase_offset("rear_right", 0.0)
  
  -- Group 2 legs (offset by half cycle)
  instance:set_leg_phase_offset("front_left", 0.5)
  instance:set_leg_phase_offset("middle_right", 0.5)
  instance:set_leg_phase_offset("rear_left", 0.5)
  
  return instance
end

--- Dynamic Wave Gait
--
-- Faster version of wave gait with reduced duty factor.
-- Maintains sequential leg lifting but with shorter stance phases.
local DynamicWaveGait = Object.new("DynamicWaveGait")

function DynamicWaveGait.new(leg_count)
  Scalar.assert_type(leg_count, "number", true)
  leg_count = leg_count or 6
  
  -- Lower duty factor for dynamic movement
  local duty_factor = 0.6  -- 60% stance phase (vs 83% for static wave)
  local instance = GaitPattern.new("dynamic_wave", duty_factor)
  
  -- Set phase offsets for wave pattern (sequential)
  local phase_increment = 1.0 / leg_count
  
  -- Standard leg order for dynamic wave gait (adapt to leg count)
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

--- Check if gait has aerial phases
--
-- @param gait_pattern GaitPattern instance
-- @param leg_names array of all leg names
-- @return true if gait can have all legs in swing simultaneously
function DynamicGaits.has_aerial_phase(gait_pattern, leg_names)
  assert(gait_pattern, "gait_pattern is required")
  assert(type(leg_names) == "table", "leg_names must be an array")
  
  -- Check if there's any phase where all legs could be in swing
  for phase = 0, 1, 0.01 do
    local stance_count = 0
    for _, leg_name in ipairs(leg_names) do
      local leg_phase, is_stance = gait_pattern:calculate_leg_phase(leg_name, phase)
      if is_stance then
        stance_count = stance_count + 1
      end
    end
    
    if stance_count == 0 then
      return true  -- Found aerial phase
    end
  end
  
  return false
end

--- Calculate minimum stance legs for dynamic gait
--
-- @param gait_pattern GaitPattern instance
-- @param leg_names array of all leg names
-- @return minimum number of legs in stance during cycle
function DynamicGaits.get_min_stance_legs(gait_pattern, leg_names)
  assert(gait_pattern, "gait_pattern is required")
  assert(type(leg_names) == "table", "leg_names must be an array")
  
  local min_stance = #leg_names
  
  for phase = 0, 1, 0.01 do
    local stance_count = 0
    for _, leg_name in ipairs(leg_names) do
      local leg_phase, is_stance = gait_pattern:calculate_leg_phase(leg_name, phase)
      if is_stance then
        stance_count = stance_count + 1
      end
    end
    
    min_stance = math.min(min_stance, stance_count)
  end
  
  return min_stance
end

--- Get velocity requirements for dynamic gait
--
-- @param gait_name name of the dynamic gait
-- @return table with min_velocity, recommended_velocity in mm/s
function DynamicGaits.get_velocity_requirements(gait_name)
  Scalar.assert_type(gait_name, "string")
  
  local requirements = {
    dynamic_trot = {min_velocity = 80, recommended_velocity = 120},
    bound = {min_velocity = 100, recommended_velocity = 150},
    gallop = {min_velocity = 150, recommended_velocity = 200},
    pronk = {min_velocity = 50, recommended_velocity = 100},
    fast_tripod = {min_velocity = 60, recommended_velocity = 100},
    dynamic_wave = {min_velocity = 40, recommended_velocity = 80}
  }
  
  return requirements[gait_name] or {min_velocity = 50, recommended_velocity = 100}
end

--- Factory function to create dynamic gait patterns by name
--
-- @param gait_name name of the gait pattern
-- @param leg_count number of legs (for gaits that need it)
-- @return GaitPattern instance
function DynamicGaits.create(gait_name, leg_count)
  Scalar.assert_type(gait_name, "string")
  Scalar.assert_type(leg_count, "number", true)
  
  if gait_name == "dynamic_trot" then
    return DynamicTrot.new()
  elseif gait_name == "bound" then
    return BoundGait.new()
  elseif gait_name == "gallop" then
    return GallopGait.new()
  elseif gait_name == "pronk" then
    return PronkGait.new()
  elseif gait_name == "fast_tripod" then
    return FastTripodGait.new()
  elseif gait_name == "dynamic_wave" then
    return DynamicWaveGait.new(leg_count)
  else
    error("Unknown dynamic gait pattern: " .. gait_name)
  end
end

--- Get list of available dynamic gait patterns
--
-- @return array of gait pattern names
function DynamicGaits.get_available_gaits()
  return {"dynamic_trot", "bound", "gallop", "pronk", "fast_tripod", "dynamic_wave"}
end

--- Validate that a dynamic gait pattern is suitable for given leg count
--
-- @param gait_name name of the gait pattern
-- @param leg_count number of legs
-- @return true if suitable, false otherwise
function DynamicGaits.is_suitable_for_legs(gait_name, leg_count)
  Scalar.assert_type(gait_name, "string")
  Scalar.assert_type(leg_count, "number")
  
  if gait_name == "dynamic_trot" or gait_name == "bound" or gait_name == "gallop" or gait_name == "pronk" then
    return leg_count == 4  -- Quadruped gaits
  elseif gait_name == "fast_tripod" then
    return leg_count == 6  -- Hexapod only
  elseif gait_name == "dynamic_wave" then
    return leg_count >= 4  -- Works with 4+ legs
  else
    return false
  end
end

--- Check if gait requires dynamic stability analysis
--
-- @param gait_name name of the gait pattern
-- @return true if gait needs momentum-based stability analysis
function DynamicGaits.requires_dynamic_stability(gait_name)
  Scalar.assert_type(gait_name, "string")
  
  -- All dynamic gaits require momentum consideration
  local dynamic_gaits = {
    dynamic_trot = true,
    bound = true,
    gallop = true,
    pronk = true,
    fast_tripod = false,  -- Still maintains static stability
    dynamic_wave = false  -- Still maintains static stability
  }
  
  return dynamic_gaits[gait_name] or false
end

DynamicGaits.DynamicTrot = DynamicTrot
DynamicGaits.BoundGait = BoundGait
DynamicGaits.GallopGait = GallopGait
DynamicGaits.PronkGait = PronkGait
DynamicGaits.FastTripodGait = FastTripodGait
DynamicGaits.DynamicWaveGait = DynamicWaveGait

return DynamicGaits