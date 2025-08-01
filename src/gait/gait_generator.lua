local Object = require("object")
local Scalar = require("scalar")
local Vec3 = require("vec3")
local FABRIK = require("fabrik")
local GaitState = require("gait.gait_state")
local LegTrajectory = require("gait.leg_trajectory")
local StaticGaits = require("gait.patterns.static_gaits")
local DynamicGaits = require("gait.patterns.dynamic_gaits")
local TurningGaits = require("gait.patterns.turning_gaits")
local StabilityAnalyzer = require("gait.stability_analyzer")
local GaitTransition = require("gait.gait_transition")
local TerrainPredictor = require("gait.terrain_predictor")
local GaitOptimizer = require("gait.gait_optimizer")
local PerformanceMonitor = require("gait.performance_monitor")
local ParameterTuner = require("gait.parameter_tuner")
local DebugVisualizer = require("gait.debug_visualizer")

--- Gait Generator
--
-- Main orchestrator for generating walking gaits for multi-legged robots.
-- Integrates with RobotConfig and FABRIK solver to produce smooth,
-- stable locomotion patterns.
local GaitGenerator = Object.new("GaitGenerator")

--- Default configuration parameters
GaitGenerator.DEFAULT_CONFIG = {
  step_height = 30.0,        -- mm
  step_length = 50.0,        -- mm
  cycle_time = 2.0,          -- seconds
  body_height = 100.0,       -- mm above ground
  ground_clearance = 5.0,    -- mm minimum clearance
  stability_margin = 20.0,   -- mm margin for stability
  max_velocity = 100.0,      -- mm/s maximum forward velocity
  max_turn_rate = 0.5,       -- rad/s maximum turn rate
  default_gait = "tripod",   -- default gait pattern
  enable_stability_check = true,  -- enable stability validation
  enable_dynamic_gaits = false,   -- enable dynamic gait patterns
  auto_gait_selection = true,     -- automatically select optimal gait
  transition_time = 1.0,          -- seconds for gait transitions
  enable_terrain_adaptation = false,  -- enable terrain-aware gait modifications
  terrain_prediction_distance = 200.0, -- mm ahead to predict terrain
  adaptive_step_height_factor = 1.5,   -- multiplier for adaptive step height
  enable_turning_gaits = false,        -- enable turning and differential gaits
  enable_gait_optimization = false,    -- enable intelligent gait selection
  enable_performance_monitoring = false, -- enable performance tracking
  enable_parameter_tuning = false,     -- enable automatic parameter tuning
  enable_debug_visualization = false   -- enable debug output and visualization
}

--- Create a new gait generator
--
-- @param robot_config RobotConfig object defining robot morphology
-- @param config optional configuration table
function GaitGenerator.new(robot_config, config)
  assert(robot_config, "robot_config is required")
  config = config or {}
  
  -- Merge with defaults
  local merged_config = {}
  for key, value in pairs(GaitGenerator.DEFAULT_CONFIG) do
    merged_config[key] = config[key] or value
  end
  
  -- Build chains from robot configuration
  local chains = robot_config:build_chains()
  local leg_names = {}
  for name, _ in pairs(chains) do
    table.insert(leg_names, name)
  end
  table.sort(leg_names)  -- Consistent ordering
  
  -- Determine appropriate gait pattern
  local leg_count = #leg_names
  local gait_name = merged_config.default_gait
  
  -- Validate gait is suitable for this robot
  local gait_pattern
  if StaticGaits.is_suitable_for_legs(gait_name, leg_count) then
    gait_pattern = StaticGaits.create(gait_name, leg_count)
  elseif merged_config.enable_dynamic_gaits and DynamicGaits.is_suitable_for_legs(gait_name, leg_count) then
    gait_pattern = DynamicGaits.create(gait_name, leg_count)
  else
    -- Fall back to wave gait which works for most configurations
    gait_name = "wave"
    if StaticGaits.is_suitable_for_legs(gait_name, leg_count) then
      gait_pattern = StaticGaits.create(gait_name, leg_count)
    else
      error("No suitable gait pattern found for " .. leg_count .. " legs")
    end
  end
  local gait_state = GaitState.new(leg_names, merged_config.cycle_time)
  local leg_trajectory = LegTrajectory.new(merged_config.step_height, merged_config.ground_clearance)
  local stability_analyzer = merged_config.enable_stability_check and 
                            StabilityAnalyzer.new(robot_config) or nil
  local gait_transition = GaitTransition.new({transition_time = merged_config.transition_time})
  local terrain_predictor = merged_config.enable_terrain_adaptation and 
                           TerrainPredictor.new({
                             prediction_distance = merged_config.terrain_prediction_distance,
                             max_step_height_increase = merged_config.step_height * merged_config.adaptive_step_height_factor
                           }) or nil
  
  -- Phase 4 components
  local gait_optimizer = merged_config.enable_gait_optimization and 
                        GaitOptimizer.new({
                          enable_dynamic_gaits = merged_config.enable_dynamic_gaits,
                          enable_turning_gaits = merged_config.enable_turning_gaits
                        }) or nil
  
  local performance_monitor = merged_config.enable_performance_monitoring and 
                             PerformanceMonitor.new() or nil
  
  local parameter_tuner = merged_config.enable_parameter_tuning and 
                         ParameterTuner.new() or nil
  
  local debug_visualizer = merged_config.enable_debug_visualization and 
                          DebugVisualizer.new() or nil
  
  -- Calculate default foot positions (neutral stance)
  local default_positions = {}
  for name, chain in pairs(chains) do
    -- Position feet at comfortable reach distance
    local reach = chain:reach() * 0.7  -- 70% of maximum reach
    local origin = chain:origin()
    
    -- Default position: straight down from leg origin at body height
    local default_pos = Vec3.new(
      origin:x(),
      origin:y(),
      origin:z() - merged_config.body_height
    )
    
    default_positions[name] = default_pos
    gait_state:set_leg_position(name, default_pos)
    gait_state:set_leg_target(name, default_pos)
  end
  
  return Object.instance({
    _robot_config = robot_config,
    _chains = chains,
    _leg_names = leg_names,
    _config = merged_config,
    _gait_pattern = gait_pattern,
    _gait_state = gait_state,
    _leg_trajectory = leg_trajectory,
    _stability_analyzer = stability_analyzer,
    _gait_transition = gait_transition,
    _terrain_predictor = terrain_predictor,
    _gait_optimizer = gait_optimizer,
    _performance_monitor = performance_monitor,
    _parameter_tuner = parameter_tuner,
    _debug_visualizer = debug_visualizer,
    _default_positions = default_positions,
    _current_velocity = Vec3.zero(),
    _current_turn_rate = 0.0,
    _body_position = Vec3.zero(),
    _is_active = false,
    _last_stability_margin = 0.0,
    _terrain_data = nil,
    _optimization_data = nil,
    _performance_data = nil
  }, GaitGenerator)
end

--- Start gait generation
function GaitGenerator:start()
  self._is_active = true
  self._gait_state:start()
end

--- Stop gait generation
function GaitGenerator:stop()
  self._is_active = false
  self._gait_state:stop()
end

--- Update gait and generate leg targets
--
-- @param dt time delta in seconds
-- @param motion_command table with velocity, turn_rate, body_pose
-- @return table of leg target positions
function GaitGenerator:update(dt, motion_command)
  Scalar.assert_type(dt, "number")
  assert(dt >= 0, "dt must be non-negative")
  
  motion_command = motion_command or {}
  
  -- Start performance monitoring
  if self._performance_monitor then
    self._performance_monitor:start_timer("total_update")
  end
  
  if not self._is_active then
    if self._performance_monitor then
      self._performance_monitor:stop_timer("total_update")
    end
    return self:_get_current_targets()
  end
  
  -- Update motion parameters
  self:_update_motion_command(motion_command)
  
  -- Update terrain data if terrain adaptation is enabled
  if self._terrain_predictor then
    self:_update_terrain_data(dt)
  end
  
  -- Update gait state
  self._gait_state:update(dt)
  
  -- Update gait transition if active
  if self._gait_transition:is_transitioning() then
    local current_time = self._gait_state:get_elapsed_time()
    local progress, is_complete = self._gait_transition:update(current_time)
    
    if is_complete then
      -- Transition complete - switch to target gait
      local target_gait = self._gait_transition:get_target_gait()
      if target_gait then
        self._gait_pattern = target_gait
        self._gait_transition:complete_transition()
      end
    end
  end
  
  -- Generate leg targets for current phase
  local targets = self:_generate_leg_targets()
  
  -- Apply FABRIK solver to each leg
  local achieved_positions = {}
  for leg_name, target in pairs(targets) do
    local chain = self._chains[leg_name]
    if chain then
      FABRIK.solve(chain, target, {
        tolerance = 0.5,
        max_interations = 10,
        enforce_constraints = true
      })
      
      -- Update gait state with actual achieved position
      local achieved_pos = chain:end_location()
      self._gait_state:set_leg_position(leg_name, achieved_pos)
      achieved_positions[leg_name] = achieved_pos
    end
  end
  
  -- Validate stability if enabled
  if self._stability_analyzer then
    local stance_legs = self:_get_current_stance_legs()
    local is_stable, margin, com = self._stability_analyzer:validate_stability(
      achieved_positions, stance_legs, self._body_position
    )
    
    self._last_stability_margin = margin
    
    -- Adjust velocity if stability is compromised
    if not is_stable and self._config.auto_gait_selection then
      self:_handle_stability_issue(margin)
    end
  end
  
  -- Complete performance monitoring and record cycle data
  if self._performance_monitor then
    local computation_time = self._performance_monitor:stop_timer("total_update")
    
    local cycle_data = {
      gait_pattern = self._gait_pattern:get_name(),
      leg_count = #self._leg_names,
      stability_margin = self._last_stability_margin,
      energy_cost = self:_calculate_current_energy_cost(),
      computation_time = computation_time,
      terrain_data = self._terrain_data
    }
    
    self._performance_monitor:record_cycle(cycle_data)
    self._performance_data = cycle_data
  end
  
  -- Record debug data
  if self._debug_visualizer then
    local debug_data = {
      timestamp = _G.millis and _G.millis() / 1000.0 or os.clock(),
      gait_pattern = self._gait_pattern:get_name(),
      global_phase = self._gait_state:get_global_phase(),
      leg_phases = self:_get_current_leg_phases(),
      leg_positions = achieved_positions,
      leg_targets = targets,
      stability_margin = self._last_stability_margin,
      center_of_mass = self._stability_analyzer and self._stability_analyzer:calculate_center_of_mass(achieved_positions, self._leg_names) or nil,
      computation_time = self._performance_data and self._performance_data.computation_time or 0,
      energy_cost = self._performance_data and self._performance_data.energy_cost or 0,
      terrain_data = self._terrain_data
    }
    
    self._debug_visualizer:record_gait_state(debug_data)
  end
  
  return targets
end

--- Generate leg targets for current gait phase
--
-- @return table of Vec3 target positions keyed by leg name
function GaitGenerator:_generate_leg_targets()
  local targets = {}
  local global_phase = self._gait_state:get_global_phase()
  
  for _, leg_name in ipairs(self._leg_names) do
    local leg_phase, is_stance
    
    -- Use transition blending if transitioning
    if self._gait_transition:is_transitioning() then
      leg_phase, is_stance = self._gait_transition:calculate_transition_phase(leg_name, global_phase)
    else
      leg_phase, is_stance = self._gait_pattern:calculate_leg_phase(leg_name, global_phase)
    end
    
    -- Update gait state
    self._gait_state:set_leg_phase(leg_name, leg_phase, is_stance)
    
    local target_pos
    if is_stance then
      target_pos = self:_calculate_stance_target(leg_name, leg_phase)
    else
      target_pos = self:_calculate_swing_target(leg_name, leg_phase)
    end
    
    targets[leg_name] = target_pos
    self._gait_state:set_leg_target(leg_name, target_pos)
  end
  
  return targets
end

--- Calculate stance phase target position
--
-- @param leg_name name of the leg
-- @param stance_phase phase within stance (0.0-1.0)
-- @return Vec3 target position
function GaitGenerator:_calculate_stance_target(leg_name, leg_phase)
  local stance_phase = self._gait_pattern:get_stance_phase(leg_phase)
  if not stance_phase then
    return self._default_positions[leg_name]
  end
  
  -- Calculate stride positions based on velocity
  local step_vector = self:_calculate_step_vector()
  local stride_length = step_vector:length()
  
  if stride_length < 0.001 then
    -- No movement, stay at default position
    return self._default_positions[leg_name]
  end
  
  -- Stance phase moves from forward position to rear position
  local default_pos = self._default_positions[leg_name]
  local forward_pos = default_pos + (step_vector * 0.5)
  local rear_pos = default_pos - (step_vector * 0.5)
  
  return self._leg_trajectory:stance_trajectory(forward_pos, rear_pos, stance_phase)
end

--- Calculate swing phase target position
--
-- @param leg_name name of the leg
-- @param leg_phase current leg phase
-- @return Vec3 target position
function GaitGenerator:_calculate_swing_target(leg_name, leg_phase)
  local swing_phase = self._gait_pattern:get_swing_phase(leg_phase)
  if not swing_phase then
    return self._default_positions[leg_name]
  end
  
  -- Calculate stride positions
  local step_vector = self:_calculate_step_vector()
  local default_pos = self._default_positions[leg_name]
  
  -- Swing phase moves from rear position to forward position
  local rear_pos = default_pos - (step_vector * 0.5)
  local forward_pos = default_pos + (step_vector * 0.5)
  
  -- Apply terrain adaptation if enabled
  if self._terrain_predictor then
    rear_pos, forward_pos = self:_apply_terrain_adaptation(leg_name, rear_pos, forward_pos)
  end
  
  -- Get body bounds for collision avoidance
  local body_bounds = self:_get_body_bounds()
  
  -- Calculate adaptive step height for terrain
  local step_height = self._config.step_height
  if self._terrain_predictor then
    step_height = self._terrain_predictor:get_adaptive_step_height(step_height, rear_pos, forward_pos)
  end
  
  -- Get ground height for terrain adaptation
  local ground_height = nil
  if self._terrain_predictor then
    ground_height = self._terrain_predictor:get_ground_height_at_position(forward_pos)
  end
  
  return self._leg_trajectory:collision_aware_trajectory(
    rear_pos, forward_pos, swing_phase, body_bounds, ground_height, step_height
  )
end

--- Calculate step vector based on current velocity and turn rate
--
-- @return Vec3 step vector
function GaitGenerator:_calculate_step_vector()
  local velocity = self._current_velocity
  local turn_rate = self._current_turn_rate
  local cycle_time = self._gait_state:get_cycle_time()
  
  -- Base step from linear velocity
  local linear_step = velocity * cycle_time
  
  -- Limit step length
  local step_length = linear_step:length()
  if step_length > self._config.step_length then
    linear_step = linear_step:normalise() * self._config.step_length
  end
  
  -- TODO: Add turning component based on turn_rate
  -- For now, just return linear step
  return linear_step
end

--- Get body collision bounds
--
-- @return table with collision bounds
function GaitGenerator:_get_body_bounds()
  -- Calculate approximate body bounds from leg origins
  local min_x, max_x = math.huge, -math.huge
  local min_y, max_y = math.huge, -math.huge
  
  for _, chain in pairs(self._chains) do
    local origin = chain:origin()
    min_x = math.min(min_x, origin:x())
    max_x = math.max(max_x, origin:x())
    min_y = math.min(min_y, origin:y())
    max_y = math.max(max_y, origin:y())
  end
  
  local center_x = (min_x + max_x) * 0.5
  local center_y = (min_y + max_y) * 0.5
  local radius = math.max(max_x - min_x, max_y - min_y) * 0.5
  
  return {
    center = Vec3.new(center_x, center_y, 0),
    radius = radius,
    clearance = self._config.stability_margin
  }
end

--- Update motion command parameters
--
-- @param motion_command table with velocity, turn_rate, body_pose
function GaitGenerator:_update_motion_command(motion_command)
  -- Update velocity with limits
  if motion_command.velocity then
    Object.assert_type(motion_command.velocity, Vec3)
    local speed = motion_command.velocity:length()
    if speed > self._config.max_velocity then
      self._current_velocity = motion_command.velocity:normalise() * self._config.max_velocity
    else
      self._current_velocity = motion_command.velocity
    end
  end
  
  -- Update turn rate with limits
  if motion_command.turn_rate then
    Scalar.assert_type(motion_command.turn_rate, "number")
    self._current_turn_rate = math.max(-self._config.max_turn_rate,
                                      math.min(self._config.max_turn_rate, motion_command.turn_rate))
  end
  
  -- Update body position
  if motion_command.body_pose then
    Object.assert_type(motion_command.body_pose, Vec3)
    self._body_position = motion_command.body_pose
  end
end

--- Get current leg targets without updating
--
-- @return table of current target positions
function GaitGenerator:_get_current_targets()
  local targets = {}
  for _, leg_name in ipairs(self._leg_names) do
    targets[leg_name] = self._gait_state:get_leg_target(leg_name)
  end
  return targets
end

--- Set gait pattern with optional transition
--
-- @param gait_name name of the gait pattern
-- @param use_transition whether to use smooth transition (default true)
function GaitGenerator:set_gait_pattern(gait_name, use_transition)
  Scalar.assert_type(gait_name, "string")
  use_transition = use_transition ~= false  -- Default to true
  
  local leg_count = #self._leg_names
  local new_gait_pattern
  
  -- Try static gaits first
  if StaticGaits.is_suitable_for_legs(gait_name, leg_count) then
    new_gait_pattern = StaticGaits.create(gait_name, leg_count)
  elseif self._config.enable_dynamic_gaits and DynamicGaits.is_suitable_for_legs(gait_name, leg_count) then
    new_gait_pattern = DynamicGaits.create(gait_name, leg_count)
  else
    error("Gait pattern '" .. gait_name .. "' is not suitable for " .. leg_count .. " legs")
  end
  
  if use_transition and self._is_active and self._gait_pattern:get_name() ~= gait_name then
    -- Start smooth transition
    local current_time = self._gait_state:get_elapsed_time()
    local current_phase = self._gait_state:get_global_phase()
    
    if self._gait_transition:start_transition(self._gait_pattern, new_gait_pattern, current_time, current_phase) then
      -- Transition started successfully - don't change gait pattern yet
      return
    end
  end
  
  -- Direct switch (no transition)
  self._gait_pattern = new_gait_pattern
  self._gait_state:reset()  -- Reset to beginning of new gait cycle
end

--- Get current gait pattern name
function GaitGenerator:get_gait_pattern()
  return self._gait_pattern:get_name()
end

--- Set configuration parameter
--
-- @param key parameter name
-- @param value parameter value
function GaitGenerator:set_config(key, value)
  Scalar.assert_type(key, "string")
  
  if key == "cycle_time" then
    Scalar.assert_type(value, "number")
    assert(value > 0, "cycle_time must be positive")
    self._config.cycle_time = value
    self._gait_state:set_cycle_time(value)
  elseif key == "step_height" then
    Scalar.assert_type(value, "number")
    assert(value > 0, "step_height must be positive")
    self._config.step_height = value
    self._leg_trajectory:set_step_height(value)
  elseif key == "ground_clearance" then
    Scalar.assert_type(value, "number")
    assert(value >= 0, "ground_clearance must be non-negative")
    self._config.ground_clearance = value
    self._leg_trajectory:set_ground_clearance(value)
  elseif self._config[key] ~= nil then
    self._config[key] = value
  else
    error("Unknown configuration parameter: " .. key)
  end
end

--- Get configuration parameter
--
-- @param key parameter name
-- @return parameter value
function GaitGenerator:get_config(key)
  Scalar.assert_type(key, "string")
  return self._config[key]
end

--- Get gait state for debugging
function GaitGenerator:get_gait_state()
  return self._gait_state
end

--- Get leg trajectory generator
function GaitGenerator:get_leg_trajectory()
  return self._leg_trajectory
end

--- Check if gait is currently active
function GaitGenerator:is_active()
  return self._is_active
end

--- Get current stance legs
--
-- @return array of leg names currently in stance
function GaitGenerator:_get_current_stance_legs()
  local stance_legs = {}
  for _, leg_name in ipairs(self._leg_names) do
    if self._gait_state:is_leg_stance(leg_name) then
      table.insert(stance_legs, leg_name)
    end
  end
  return stance_legs
end

--- Handle stability issues by adjusting gait parameters
--
-- @param stability_margin current stability margin
function GaitGenerator:_handle_stability_issue(stability_margin)
  if stability_margin < -self._config.stability_margin then
    -- Critical instability - reduce velocity immediately
    local current_speed = self._current_velocity:length()
    if current_speed > 10 then
      self._current_velocity = self._current_velocity * 0.5  -- Halve velocity
    end
    
    -- Consider switching to more stable gait
    if self._gait_pattern:get_name() ~= "wave" then
      self:set_gait_pattern("wave", true)
    end
  elseif stability_margin < 0 then
    -- Mild instability - slight velocity reduction
    local current_speed = self._current_velocity:length()
    if current_speed > 20 then
      self._current_velocity = self._current_velocity * 0.8  -- Reduce by 20%
    end
  end
end

--- Get stability analyzer
function GaitGenerator:get_stability_analyzer()
  return self._stability_analyzer
end

--- Update terrain data for adaptation
--
-- @param dt time delta in seconds
function GaitGenerator:_update_terrain_data(dt)
  if not self._terrain_predictor then
    return
  end
  
  local current_time = _G.millis and _G.millis() or 0
  
  self._terrain_data = self._terrain_predictor:update(
    current_time,
    self._body_position,
    self._current_velocity
  )
  
  -- Apply body attitude compensation if available
  if self._terrain_data and self._terrain_data.attitude then
    local compensation = self._terrain_predictor:get_body_attitude_compensation()
    self:_apply_body_attitude_compensation(compensation)
  end
end

--- Apply terrain adaptation to leg positions
--
-- @param leg_name name of the leg
-- @param rear_pos rear position of swing
-- @param forward_pos forward position of swing
-- @return adjusted rear_pos, forward_pos
function GaitGenerator:_apply_terrain_adaptation(leg_name, rear_pos, forward_pos)
  if not self._terrain_predictor or not self._terrain_data then
    return rear_pos, forward_pos
  end
  
  -- Adjust positions based on predicted ground height
  local rear_ground = self._terrain_predictor:get_ground_height_at_position(rear_pos)
  local forward_ground = self._terrain_predictor:get_ground_height_at_position(forward_pos)
  
  -- Apply ground height adjustments
  local adjusted_rear = Vec3.new(rear_pos:x(), rear_pos:y(), rear_ground)
  local adjusted_forward = Vec3.new(forward_pos:x(), forward_pos:y(), forward_ground)
  
  -- Apply adaptive clearance for rough terrain
  local adaptive_clearance = self._terrain_data.adaptive_clearance or 0
  if adaptive_clearance > 0 then
    adjusted_rear = adjusted_rear + Vec3.new(0, 0, adaptive_clearance)
    adjusted_forward = adjusted_forward + Vec3.new(0, 0, adaptive_clearance)
  end
  
  return adjusted_rear, adjusted_forward
end

--- Apply body attitude compensation
--
-- @param compensation attitude compensation values
function GaitGenerator:_apply_body_attitude_compensation(compensation)
  if not compensation then
    return
  end
  
  -- Adjust default positions based on body attitude
  local roll_offset = compensation.roll * self._config.body_height * 0.1
  local pitch_offset = compensation.pitch * self._config.body_height * 0.1
  
  for leg_name, default_pos in pairs(self._default_positions) do
    local chain = self._chains[leg_name]
    if chain then
      local origin = chain:origin()
      
      -- Apply roll compensation (side-to-side)
      local roll_adjustment = origin:y() * math.sin(compensation.roll) * 0.1
      
      -- Apply pitch compensation (front-to-back)
      local pitch_adjustment = origin:x() * math.sin(compensation.pitch) * 0.1
      
      -- Update default position with compensation
      local compensated_pos = Vec3.new(
        default_pos:x(),
        default_pos:y(),
        default_pos:z() + roll_adjustment + pitch_adjustment
      )
      
      self._default_positions[leg_name] = compensated_pos
    end
  end
end

--- Register sensor provider for terrain adaptation
--
-- @param name sensor provider name
-- @param provider sensor provider instance
function GaitGenerator:register_sensor_provider(name, provider)
  if not self._terrain_predictor then
    error("Terrain adaptation not enabled - cannot register sensor provider")
  end
  
  self._terrain_predictor:register_sensor_provider(name, provider)
end

--- Get terrain predictor
function GaitGenerator:get_terrain_predictor()
  return self._terrain_predictor
end

--- Get current terrain data
function GaitGenerator:get_terrain_data()
  return self._terrain_data
end

--- Get gait transition manager
function GaitGenerator:get_gait_transition()
  return self._gait_transition
end

--- Get last stability margin
function GaitGenerator:get_last_stability_margin()
  return self._last_stability_margin
end

--- Enable or disable dynamic gaits
--
-- @param enabled true to enable dynamic gaits
function GaitGenerator:set_dynamic_gaits_enabled(enabled)
  self._config.enable_dynamic_gaits = enabled
end

--- Check if dynamic gaits are enabled
function GaitGenerator:is_dynamic_gaits_enabled()
  return self._config.enable_dynamic_gaits
end

--- Get available gait patterns for current robot
--
-- @return array of gait pattern names
function GaitGenerator:get_available_gaits()
  local leg_count = #self._leg_names
  local available = {}
  
  -- Add suitable static gaits
  for _, gait_name in ipairs(StaticGaits.get_available_gaits()) do
    if StaticGaits.is_suitable_for_legs(gait_name, leg_count) then
      table.insert(available, gait_name)
    end
  end
  
  -- Add suitable dynamic gaits if enabled
  if self._config.enable_dynamic_gaits then
    for _, gait_name in ipairs(DynamicGaits.get_available_gaits()) do
      if DynamicGaits.is_suitable_for_legs(gait_name, leg_count) then
        table.insert(available, gait_name)
      end
    end
  end
  
  return available
end

--- Phase 4 Advanced Features

--- Get gait optimizer
function GaitGenerator:get_gait_optimizer()
  return self._gait_optimizer
end

--- Get performance monitor
function GaitGenerator:get_performance_monitor()
  return self._performance_monitor
end

--- Get parameter tuner
function GaitGenerator:get_parameter_tuner()
  return self._parameter_tuner
end

--- Get debug visualizer
function GaitGenerator:get_debug_visualizer()
  return self._debug_visualizer
end

--- Optimize gait selection based on current conditions
--
-- @param conditions table with current operating conditions
-- @return recommended gait and evaluation data
function GaitGenerator:optimize_gait_selection(conditions)
  if not self._gait_optimizer then
    return nil, "Gait optimization not enabled"
  end
  
  conditions = conditions or {}
  conditions.leg_count = #self._leg_names
  conditions.velocity = self._current_velocity
  conditions.turn_rate = self._current_turn_rate
  conditions.stability_margin = self._last_stability_margin
  conditions.terrain_roughness = self._terrain_data and self._terrain_data.adaptive_clearance or 0
  
  local best_gait, evaluations = self._gait_optimizer:optimize_gait_selection(conditions)
  self._optimization_data = {best_gait = best_gait, evaluations = evaluations}
  
  return best_gait, evaluations
end

--- Apply optimized gait selection
--
-- @param gait_info gait information from optimizer
-- @return success status
function GaitGenerator:apply_optimized_gait(gait_info)
  if not gait_info then
    return false, "No gait information provided"
  end
  
  local success = false
  local error_msg = nil
  
  if gait_info.type == "static" then
    success, error_msg = pcall(function()
      self:set_gait_pattern(gait_info.name, true)
    end)
  elseif gait_info.type == "dynamic" then
    if self._config.enable_dynamic_gaits then
      success, error_msg = pcall(function()
        self:set_gait_pattern(gait_info.name, true)
      end)
    else
      return false, "Dynamic gaits not enabled"
    end
  elseif gait_info.type == "turning" then
    if self._config.enable_turning_gaits then
      success, error_msg = pcall(function()
        self:set_turning_gait(gait_info.name, gait_info.params)
      end)
    else
      return false, "Turning gaits not enabled"
    end
  end
  
  return success, error_msg
end

--- Set turning gait pattern
--
-- @param gait_name name of the turning gait
-- @param params gait-specific parameters
function GaitGenerator:set_turning_gait(gait_name, params)
  if not self._config.enable_turning_gaits then
    error("Turning gaits not enabled")
  end
  
  local leg_count = #self._leg_names
  if not TurningGaits.is_suitable_for_legs(gait_name, leg_count) then
    error("Turning gait '" .. gait_name .. "' not suitable for " .. leg_count .. " legs")
  end
  
  local new_pattern = TurningGaits.create(gait_name, params)
  
  if self._gait_transition then
    self._gait_transition:start_transition(self._gait_pattern, new_pattern, self._stability_analyzer)
  else
    self._gait_pattern = new_pattern
    self._gait_state:reset()
  end
end

--- Get current performance statistics
--
-- @return performance statistics or nil
function GaitGenerator:get_performance_statistics()
  if not self._performance_monitor then
    return nil
  end
  
  return self._performance_monitor:get_statistics()
end

--- Generate debug output
--
-- @param format output format (optional)
-- @return debug output string
function GaitGenerator:generate_debug_output(format)
  if not self._debug_visualizer then
    return "Debug visualization not enabled"
  end
  
  return self._debug_visualizer:generate_output(format)
end

--- Tune parameters automatically
--
-- @param target_conditions target operating conditions
-- @return optimized parameters
function GaitGenerator:tune_parameters(target_conditions)
  if not self._parameter_tuner then
    return nil, "Parameter tuning not enabled"
  end
  
  -- Set up evaluation function
  self._parameter_tuner:set_evaluation_function(function(params, conditions)
    return self:_evaluate_parameter_set(params, conditions)
  end)
  
  -- Initialize with current parameters
  local current_params = {
    step_height = self._config.step_height,
    step_length = self._config.step_length,
    cycle_time = self._config.cycle_time,
    body_height = self._config.body_height,
    ground_clearance = self._config.ground_clearance,
    stability_margin = self._config.stability_margin
  }
  
  self._parameter_tuner:initialize_parameters(current_params)
  
  -- Run optimization
  local optimized_params, results = self._parameter_tuner:optimize(target_conditions)
  
  return optimized_params, results
end

--- Helper methods for Phase 4

function GaitGenerator:_calculate_current_energy_cost()
  -- Simple energy cost estimation based on current gait and conditions
  local base_cost = 1.0
  local speed = self._current_velocity:length()
  local turn_rate = math.abs(self._current_turn_rate)
  
  -- Speed increases energy cost
  base_cost = base_cost + (speed / 100.0) * 0.3
  
  -- Turning increases energy cost
  base_cost = base_cost + turn_rate * 0.2
  
  -- Terrain adaptation increases energy cost
  if self._terrain_data and self._terrain_data.adaptive_clearance > 10 then
    base_cost = base_cost + (self._terrain_data.adaptive_clearance / 50.0) * 0.2
  end
  
  return base_cost
end

function GaitGenerator:_get_current_leg_phases()
  local phases = {}
  for _, leg_name in ipairs(self._leg_names) do
    phases[leg_name] = self._gait_state:get_leg_phase(leg_name)
  end
  return phases
end

function GaitGenerator:_evaluate_parameter_set(params, conditions)
  -- Evaluate a parameter set for optimization
  -- This is a simplified evaluation - in practice would run actual gait simulation
  local score = 1.0
  
  -- Penalize extreme parameter values
  if params.step_height > 80 or params.step_height < 15 then
    score = score * 0.5
  end
  
  if params.cycle_time > 4.0 or params.cycle_time < 0.8 then
    score = score * 0.7
  end
  
  -- Reward parameters that match conditions
  if conditions.desired_speed then
    local speed_efficiency = 1.0 - math.abs(conditions.desired_speed - (params.step_length / params.cycle_time)) / conditions.desired_speed
    score = score * (0.5 + speed_efficiency * 0.5)
  end
  
  if conditions.terrain_roughness and conditions.terrain_roughness > 30 then
    -- Reward higher step height for rough terrain
    local terrain_suitability = math.min(1.0, params.step_height / 50.0)
    score = score * (0.7 + terrain_suitability * 0.3)
  end
  
  return score
end

return GaitGenerator