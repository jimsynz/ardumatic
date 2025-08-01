local Object = require("object")
local Scalar = require("scalar")
local Vec3 = require("vec3")
local StaticGaits = require("gait.patterns.static_gaits")
local DynamicGaits = require("gait.patterns.dynamic_gaits")
local TurningGaits = require("gait.patterns.turning_gaits")

--- Gait Optimizer
--
-- Provides intelligent gait selection based on energy efficiency, stability,
-- terrain conditions, and performance requirements.
local GaitOptimizer = Object.new("GaitOptimizer")

--- Energy cost models for different gait patterns
local ENERGY_MODELS = {
  -- Static gaits (lower energy cost due to stability)
  tripod = {base_cost = 1.0, speed_factor = 0.8, stability_bonus = 0.9},
  wave = {base_cost = 1.2, speed_factor = 0.6, stability_bonus = 0.8},
  ripple = {base_cost = 1.1, speed_factor = 0.7, stability_bonus = 0.85},
  quadruped_trot = {base_cost = 0.9, speed_factor = 0.9, stability_bonus = 0.9},
  
  -- Dynamic gaits (higher energy cost but faster)
  dynamic_trot = {base_cost = 1.3, speed_factor = 1.2, stability_bonus = 1.1},
  bound = {base_cost = 1.5, speed_factor = 1.4, stability_bonus = 1.3},
  gallop = {base_cost = 1.8, speed_factor = 1.6, stability_bonus = 1.5},
  pronk = {base_cost = 2.0, speed_factor = 1.8, stability_bonus = 1.7},
  fast_tripod = {base_cost = 1.4, speed_factor = 1.3, stability_bonus = 1.2},
  dynamic_wave = {base_cost = 1.6, speed_factor = 1.1, stability_bonus = 1.1},
  
  -- Turning gaits (moderate energy cost, specialized for maneuvering)
  differential_tripod = {base_cost = 1.1, speed_factor = 0.9, stability_bonus = 0.95},
  differential_wave = {base_cost = 1.3, speed_factor = 0.7, stability_bonus = 0.85},
  crab_walk = {base_cost = 1.4, speed_factor = 0.6, stability_bonus = 0.9},
  pivot_turn = {base_cost = 1.6, speed_factor = 0.3, stability_bonus = 0.8}
}

--- Performance requirements for gait selection
local DEFAULT_REQUIREMENTS = {
  max_energy_cost = 2.0,        -- Maximum acceptable energy cost multiplier
  min_stability_margin = 20.0,  -- mm minimum stability margin
  max_cycle_time = 3.0,         -- seconds maximum cycle time
  min_speed_efficiency = 0.5,   -- minimum speed efficiency factor
  terrain_roughness_threshold = 50.0,  -- mm terrain roughness threshold
  enable_dynamic_gaits = true,  -- allow dynamic gaits
  enable_turning_gaits = true,  -- allow turning gaits
  prefer_stability = false,     -- prioritize stability over speed
  prefer_speed = false          -- prioritize speed over energy
}

function GaitOptimizer.new(requirements)
  if requirements ~= nil then
    assert(type(requirements) == "table", "requirements must be a table")
  end
  
  local merged_requirements = {}
  for k, v in pairs(DEFAULT_REQUIREMENTS) do
    merged_requirements[k] = requirements and requirements[k] or v
  end
  
  return Object.instance({
    _requirements = merged_requirements,
    _gait_performance_cache = {},
    _last_optimization_time = 0,
    _current_conditions = nil
  }, GaitOptimizer)
end

--- Optimize gait selection based on current conditions
--
-- @param conditions table with current robot state and environment
-- @return recommended gait name and parameters
function GaitOptimizer:optimize_gait_selection(conditions)
  assert(type(conditions) == "table", "conditions must be a table")
  
  self._current_conditions = conditions
  local current_time = conditions.timestamp or 0
  
  -- Extract key conditions
  local velocity = conditions.velocity or Vec3.zero()
  local turn_rate = conditions.turn_rate or 0.0
  local terrain_roughness = conditions.terrain_roughness or 0.0
  local stability_margin = conditions.stability_margin or 100.0
  local leg_count = conditions.leg_count or 6
  local energy_budget = conditions.energy_budget or self._requirements.max_energy_cost
  
  -- Determine motion type
  local speed = velocity:length()
  local is_turning = math.abs(turn_rate) > 0.1
  local is_stationary = speed < 10.0  -- mm/s
  local is_high_speed = speed > 100.0  -- mm/s
  local is_rough_terrain = terrain_roughness > self._requirements.terrain_roughness_threshold
  
  -- Get candidate gaits based on motion type and conditions
  local candidates = self:_get_candidate_gaits(leg_count, is_turning, is_stationary, is_high_speed)
  
  -- Evaluate each candidate gait
  local best_gait = nil
  local best_score = -math.huge
  local evaluations = {}
  
  for _, gait_info in ipairs(candidates) do
    local score = self:_evaluate_gait(gait_info, conditions)
    evaluations[gait_info.name] = {
      score = score,
      energy_cost = self:_calculate_energy_cost(gait_info, conditions),
      stability_score = self:_calculate_stability_score(gait_info, conditions),
      speed_efficiency = self:_calculate_speed_efficiency(gait_info, conditions),
      terrain_suitability = self:_calculate_terrain_suitability(gait_info, conditions)
    }
    
    if score > best_score then
      best_score = score
      best_gait = gait_info
    end
  end
  
  -- Cache results for performance
  self._gait_performance_cache[current_time] = {
    best_gait = best_gait,
    evaluations = evaluations,
    conditions = conditions
  }
  
  return best_gait, evaluations
end

--- Get candidate gaits based on current conditions
--
-- @param leg_count number of legs
-- @param is_turning whether robot is turning
-- @param is_stationary whether robot is stationary
-- @param is_high_speed whether robot is at high speed
-- @return array of candidate gait information
function GaitOptimizer:_get_candidate_gaits(leg_count, is_turning, is_stationary, is_high_speed)
  local candidates = {}
  
  -- Add static gaits
  for _, gait_name in ipairs(StaticGaits.get_available_gaits()) do
    if StaticGaits.is_suitable_for_legs(gait_name, leg_count) then
      table.insert(candidates, {
        name = gait_name,
        type = "static",
        factory = StaticGaits,
        params = {leg_count = leg_count}
      })
    end
  end
  
  -- Add dynamic gaits if enabled and appropriate
  if self._requirements.enable_dynamic_gaits and (is_high_speed or self._requirements.prefer_speed) then
    for _, gait_name in ipairs(DynamicGaits.get_available_gaits()) do
      if DynamicGaits.is_suitable_for_legs(gait_name, leg_count) then
        table.insert(candidates, {
          name = gait_name,
          type = "dynamic",
          factory = DynamicGaits,
          params = {leg_count = leg_count}
        })
      end
    end
  end
  
  -- Add turning gaits if turning or maneuvering
  if self._requirements.enable_turning_gaits and (is_turning or is_stationary) then
    for _, gait_name in ipairs(TurningGaits.get_available_gaits()) do
      if TurningGaits.is_suitable_for_legs(gait_name, leg_count) then
        local params = {leg_count = leg_count}
        
        -- Add specific parameters for turning gaits
        if gait_name == "differential_tripod" or gait_name == "differential_wave" then
          params.turn_rate = self._current_conditions.turn_rate or 0.0
        elseif gait_name == "crab_walk" then
          params.direction = self._current_conditions.crab_direction or 0.0
        elseif gait_name == "pivot_turn" then
          params.turn_direction = (self._current_conditions.turn_rate or 0.0) > 0 and 1.0 or -1.0
        end
        
        table.insert(candidates, {
          name = gait_name,
          type = "turning",
          factory = TurningGaits,
          params = params
        })
      end
    end
  end
  
  return candidates
end

--- Evaluate a gait candidate and return a score
--
-- @param gait_info gait information table
-- @param conditions current conditions
-- @return evaluation score (higher is better)
function GaitOptimizer:_evaluate_gait(gait_info, conditions)
  local energy_cost = self:_calculate_energy_cost(gait_info, conditions)
  local stability_score = self:_calculate_stability_score(gait_info, conditions)
  local speed_efficiency = self:_calculate_speed_efficiency(gait_info, conditions)
  local terrain_suitability = self:_calculate_terrain_suitability(gait_info, conditions)
  
  -- Weighted scoring based on requirements
  local weights = {
    energy = self._requirements.prefer_speed and 0.2 or 0.3,
    stability = self._requirements.prefer_stability and 0.4 or 0.25,
    speed = self._requirements.prefer_speed and 0.4 or 0.25,
    terrain = 0.2
  }
  
  -- Normalize scores (invert energy cost since lower is better)
  local energy_score = math.max(0, 2.0 - energy_cost)
  
  local total_score = (energy_score * weights.energy +
                      stability_score * weights.stability +
                      speed_efficiency * weights.speed +
                      terrain_suitability * weights.terrain)
  
  -- Apply penalties for requirement violations
  if energy_cost > self._requirements.max_energy_cost then
    total_score = total_score * 0.5  -- Heavy penalty for exceeding energy budget
  end
  
  if stability_score < 0.5 and self._requirements.prefer_stability then
    total_score = total_score * 0.7  -- Penalty for low stability when stability is preferred
  end
  
  return total_score
end

--- Calculate energy cost for a gait
--
-- @param gait_info gait information
-- @param conditions current conditions
-- @return energy cost multiplier
function GaitOptimizer:_calculate_energy_cost(gait_info, conditions)
  local model = ENERGY_MODELS[gait_info.name]
  if not model then
    return 1.5  -- Default moderate cost for unknown gaits
  end
  
  local speed = conditions.velocity and conditions.velocity:length() or 0
  local terrain_roughness = conditions.terrain_roughness or 0
  
  -- Base energy cost
  local cost = model.base_cost
  
  -- Speed-dependent cost
  local speed_factor = speed / 100.0  -- Normalize to typical speed
  cost = cost + (speed_factor * model.speed_factor * 0.5)
  
  -- Terrain roughness increases energy cost
  local terrain_factor = terrain_roughness / 50.0  -- Normalize to typical roughness
  cost = cost + (terrain_factor * 0.3)
  
  -- Stability bonus reduces energy cost for stable gaits
  if conditions.stability_margin and conditions.stability_margin > 50.0 then
    cost = cost * model.stability_bonus
  end
  
  return math.max(0.1, cost)
end

--- Calculate stability score for a gait
--
-- @param gait_info gait information
-- @param conditions current conditions
-- @return stability score (0.0-1.0, higher is better)
function GaitOptimizer:_calculate_stability_score(gait_info, conditions)
  local base_stability = 0.5
  
  -- Static gaits are inherently more stable
  if gait_info.type == "static" then
    base_stability = 0.8
  elseif gait_info.type == "dynamic" then
    base_stability = 0.4
  elseif gait_info.type == "turning" then
    base_stability = 0.6
  end
  
  -- Adjust based on current stability margin
  if conditions.stability_margin then
    local margin_factor = math.min(1.0, conditions.stability_margin / 100.0)
    base_stability = base_stability * (0.5 + margin_factor * 0.5)
  end
  
  -- Penalize for high speeds with unstable gaits
  local speed = conditions.velocity and conditions.velocity:length() or 0
  if speed > 150.0 and gait_info.type == "dynamic" then
    base_stability = base_stability * 0.8
  end
  
  return math.max(0.0, math.min(1.0, base_stability))
end

--- Calculate speed efficiency for a gait
--
-- @param gait_info gait information
-- @param conditions current conditions
-- @return speed efficiency score (0.0-1.0, higher is better)
function GaitOptimizer:_calculate_speed_efficiency(gait_info, conditions)
  local model = ENERGY_MODELS[gait_info.name]
  if not model then
    return 0.5  -- Default moderate efficiency
  end
  
  local base_efficiency = model.speed_factor / 2.0  -- Normalize to 0-1 range
  
  -- Adjust based on desired speed
  local speed = conditions.velocity and conditions.velocity:length() or 0
  local desired_speed = conditions.desired_speed or speed
  
  if desired_speed > 0 then
    local speed_match = 1.0 - math.abs(speed - desired_speed) / math.max(speed, desired_speed)
    base_efficiency = base_efficiency * (0.5 + speed_match * 0.5)
  end
  
  -- Turning gaits are less efficient for forward motion
  if gait_info.type == "turning" and math.abs(conditions.turn_rate or 0) < 0.1 then
    base_efficiency = base_efficiency * 0.7
  end
  
  return math.max(0.0, math.min(1.0, base_efficiency))
end

--- Calculate terrain suitability for a gait
--
-- @param gait_info gait information
-- @param conditions current conditions
-- @return terrain suitability score (0.0-1.0, higher is better)
function GaitOptimizer:_calculate_terrain_suitability(gait_info, conditions)
  local terrain_roughness = conditions.terrain_roughness or 0
  local base_suitability = 0.7
  
  -- Static gaits handle rough terrain better
  if terrain_roughness > 30.0 then
    if gait_info.type == "static" then
      base_suitability = 0.9
    elseif gait_info.type == "dynamic" then
      base_suitability = 0.4
    end
  end
  
  -- Wave gait is excellent for very rough terrain
  if gait_info.name == "wave" and terrain_roughness > 50.0 then
    base_suitability = 0.95
  end
  
  -- Dynamic gaits struggle on very rough terrain
  if gait_info.type == "dynamic" and terrain_roughness > 70.0 then
    base_suitability = base_suitability * 0.5
  end
  
  return math.max(0.0, math.min(1.0, base_suitability))
end

--- Get performance requirements
function GaitOptimizer:get_requirements()
  return self._requirements
end

--- Set performance requirements
--
-- @param requirements table of new requirements
function GaitOptimizer:set_requirements(requirements)
  assert(type(requirements) == "table", "requirements must be a table")
  
  for k, v in pairs(requirements) do
    if self._requirements[k] ~= nil then
      self._requirements[k] = v
    end
  end
end

--- Get cached gait evaluations
--
-- @param timestamp optional timestamp to get specific cache entry
-- @return cached evaluations or nil
function GaitOptimizer:get_cached_evaluations(timestamp)
  if timestamp then
    local cache_entry = self._gait_performance_cache[timestamp]
    return cache_entry and cache_entry.evaluations or nil
  else
    return self._gait_performance_cache[self._last_optimization_time]
  end
end

--- Clear performance cache
function GaitOptimizer:clear_cache()
  self._gait_performance_cache = {}
end

return GaitOptimizer