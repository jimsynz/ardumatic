local Object = require("object")
local Scalar = require("scalar")

--- Parameter Tuner
--
-- Provides intelligent parameter optimization for gait generation using
-- various optimization algorithms and performance feedback.
local ParameterTuner = Object.new("ParameterTuner")

--- Parameter definitions with constraints and optimization hints
local PARAMETER_DEFINITIONS = {
  step_height = {
    min = 10.0, max = 100.0, default = 30.0, unit = "mm",
    description = "Maximum height of leg lift during swing phase",
    optimization_weight = 0.8, -- Higher weight = more important to optimize
    affects = {"energy", "stability", "terrain_clearance"}
  },
  step_length = {
    min = 20.0, max = 150.0, default = 50.0, unit = "mm",
    description = "Maximum step length for forward motion",
    optimization_weight = 0.9,
    affects = {"speed", "energy", "stability"}
  },
  cycle_time = {
    min = 0.5, max = 5.0, default = 2.0, unit = "seconds",
    description = "Time for one complete gait cycle",
    optimization_weight = 0.7,
    affects = {"speed", "stability", "energy"}
  },
  body_height = {
    min = 50.0, max = 200.0, default = 100.0, unit = "mm",
    description = "Height of robot body above ground",
    optimization_weight = 0.6,
    affects = {"stability", "terrain_clearance", "energy"}
  },
  ground_clearance = {
    min = 2.0, max = 20.0, default = 5.0, unit = "mm",
    description = "Minimum clearance above ground during swing",
    optimization_weight = 0.5,
    affects = {"terrain_clearance", "energy"}
  },
  stability_margin = {
    min = 5.0, max = 50.0, default = 20.0, unit = "mm",
    description = "Minimum stability margin for safe operation",
    optimization_weight = 0.9,
    affects = {"stability"}
  }
}

--- Optimization algorithms available
local OPTIMIZATION_ALGORITHMS = {
  hill_climbing = "Simple hill climbing with random restarts",
  simulated_annealing = "Simulated annealing for global optimization",
  genetic_algorithm = "Genetic algorithm for multi-objective optimization",
  gradient_descent = "Gradient descent with finite differences",
  random_search = "Random search within parameter bounds"
}

--- Default tuning configuration
local DEFAULT_CONFIG = {
  algorithm = "hill_climbing",
  max_iterations = 100,
  convergence_threshold = 0.001,
  population_size = 20,  -- For genetic algorithm
  mutation_rate = 0.1,   -- For genetic algorithm
  temperature_initial = 1.0,  -- For simulated annealing
  temperature_decay = 0.95,   -- For simulated annealing
  step_size = 0.1,       -- For gradient descent
  random_restart_count = 5,   -- For hill climbing
  objective_weights = {  -- Multi-objective optimization weights
    energy = 0.3,
    stability = 0.4,
    speed = 0.2,
    terrain_suitability = 0.1
  }
}

function ParameterTuner.new(config)
  if config ~= nil then
    assert(type(config) == "table", "config must be a table")
  end
  
  local merged_config = {}
  for k, v in pairs(DEFAULT_CONFIG) do
    merged_config[k] = config and config[k] or v
  end
  
  return Object.instance({
    _config = merged_config,
    _current_parameters = {},
    _optimization_history = {},
    _best_parameters = nil,
    _best_score = -math.huge,
    _evaluation_function = nil,
    _constraints = {},
    _iteration_count = 0
  }, ParameterTuner)
end

--- Set the evaluation function for parameter optimization
--
-- @param eval_func function that takes parameters and returns a score
function ParameterTuner:set_evaluation_function(eval_func)
  assert(type(eval_func) == "function", "eval_func must be a function")
  self._evaluation_function = eval_func
end

--- Add parameter constraints
--
-- @param param_name name of the parameter
-- @param constraints table with min, max, and other constraints
function ParameterTuner:add_parameter_constraint(param_name, constraints)
  assert(type(param_name) == "string", "param_name must be a string")
  assert(type(constraints) == "table", "constraints must be a table")
  
  self._constraints[param_name] = constraints
end

--- Initialize parameters with default or provided values
--
-- @param initial_params optional table of initial parameter values
function ParameterTuner:initialize_parameters(initial_params)
  initial_params = initial_params or {}
  
  self._current_parameters = {}
  
  -- Initialize with defaults or provided values
  for param_name, definition in pairs(PARAMETER_DEFINITIONS) do
    if initial_params[param_name] then
      self._current_parameters[param_name] = initial_params[param_name]
    else
      self._current_parameters[param_name] = definition.default
    end
    
    -- Apply constraints
    self._current_parameters[param_name] = self:_apply_constraints(param_name, self._current_parameters[param_name])
  end
end

--- Run parameter optimization
--
-- @param target_conditions table describing the target operating conditions
-- @return optimized parameters and optimization results
function ParameterTuner:optimize(target_conditions)
  assert(type(target_conditions) == "table", "target_conditions must be a table")
  assert(self._evaluation_function, "Evaluation function must be set before optimization")
  
  if not self._current_parameters or next(self._current_parameters) == nil then
    self:initialize_parameters()
  end
  
  self._iteration_count = 0
  self._optimization_history = {}
  self._best_parameters = nil
  self._best_score = -math.huge
  
  local algorithm = self._config.algorithm
  local results = {}
  
  if algorithm == "hill_climbing" then
    results = self:_hill_climbing_optimization(target_conditions)
  elseif algorithm == "simulated_annealing" then
    results = self:_simulated_annealing_optimization(target_conditions)
  elseif algorithm == "genetic_algorithm" then
    results = self:_genetic_algorithm_optimization(target_conditions)
  elseif algorithm == "gradient_descent" then
    results = self:_gradient_descent_optimization(target_conditions)
  elseif algorithm == "random_search" then
    results = self:_random_search_optimization(target_conditions)
  else
    error("Unknown optimization algorithm: " .. algorithm)
  end
  
  return self._best_parameters, results
end

--- Get current parameter values
--
-- @return table of current parameter values
function ParameterTuner:get_current_parameters()
  return self._current_parameters
end

--- Get optimization history
--
-- @return array of optimization iterations with parameters and scores
function ParameterTuner:get_optimization_history()
  return self._optimization_history
end

--- Get parameter recommendations based on conditions
--
-- @param conditions current operating conditions
-- @return recommended parameter adjustments
function ParameterTuner:get_parameter_recommendations(conditions)
  assert(type(conditions) == "table", "conditions must be a table")
  
  local recommendations = {}
  
  -- Analyze current conditions and suggest parameter adjustments
  local terrain_roughness = conditions.terrain_roughness or 0
  local desired_speed = conditions.desired_speed or 50
  local stability_requirement = conditions.stability_requirement or "normal"
  local energy_budget = conditions.energy_budget or "normal"
  
  -- Terrain-based recommendations
  if terrain_roughness > 50 then
    recommendations.step_height = {
      adjustment = "increase",
      factor = 1.2 + (terrain_roughness / 100),
      reason = "Increase step height for rough terrain clearance"
    }
    recommendations.cycle_time = {
      adjustment = "increase",
      factor = 1.1,
      reason = "Slower gait for better stability on rough terrain"
    }
  end
  
  -- Speed-based recommendations
  if desired_speed > 100 then
    recommendations.step_length = {
      adjustment = "increase",
      factor = 1.0 + (desired_speed / 200),
      reason = "Increase step length for higher speed"
    }
    recommendations.cycle_time = {
      adjustment = "decrease",
      factor = 0.8,
      reason = "Faster cycle time for higher speed"
    }
  end
  
  -- Stability-based recommendations
  if stability_requirement == "high" then
    recommendations.stability_margin = {
      adjustment = "increase",
      factor = 1.5,
      reason = "Increase stability margin for high stability requirement"
    }
    recommendations.body_height = {
      adjustment = "decrease",
      factor = 0.9,
      reason = "Lower body height for better stability"
    }
  end
  
  -- Energy-based recommendations
  if energy_budget == "low" then
    recommendations.step_height = {
      adjustment = "decrease",
      factor = 0.8,
      reason = "Reduce step height to save energy"
    }
    recommendations.cycle_time = {
      adjustment = "increase",
      factor = 1.2,
      reason = "Slower gait for energy efficiency"
    }
  end
  
  return recommendations
end

--- Apply parameter recommendations
--
-- @param recommendations table of parameter recommendations
-- @return updated parameters
function ParameterTuner:apply_recommendations(recommendations)
  assert(type(recommendations) == "table", "recommendations must be a table")
  
  local updated_parameters = {}
  for k, v in pairs(self._current_parameters) do
    updated_parameters[k] = v
  end
  
  for param_name, recommendation in pairs(recommendations) do
    if updated_parameters[param_name] and PARAMETER_DEFINITIONS[param_name] then
      local current_value = updated_parameters[param_name]
      local new_value = current_value
      
      if recommendation.adjustment == "increase" then
        new_value = current_value * recommendation.factor
      elseif recommendation.adjustment == "decrease" then
        new_value = current_value / recommendation.factor
      elseif recommendation.adjustment == "set" then
        new_value = recommendation.value
      end
      
      -- Apply constraints
      new_value = self:_apply_constraints(param_name, new_value)
      updated_parameters[param_name] = new_value
    end
  end
  
  self._current_parameters = updated_parameters
  return updated_parameters
end

--- Internal optimization algorithms

function ParameterTuner:_hill_climbing_optimization(target_conditions)
  local best_score = -math.huge
  local best_params = nil
  local no_improvement_count = 0
  local restart_count = 0
  
  while restart_count <= self._config.random_restart_count and 
        self._iteration_count < self._config.max_iterations do
    
    local current_params = self:_copy_parameters(self._current_parameters)
    local current_score = self:_evaluate_parameters(current_params, target_conditions)
    
    local local_best_score = current_score
    local local_best_params = current_params
    local step_size = 0.1
    
    -- Local hill climbing
    while no_improvement_count < 10 and self._iteration_count < self._config.max_iterations do
      local neighbor_params = self:_generate_neighbor_parameters(current_params, step_size)
      local neighbor_score = self:_evaluate_parameters(neighbor_params, target_conditions)
      
      self._iteration_count = self._iteration_count + 1
      
      if neighbor_score > local_best_score then
        local_best_score = neighbor_score
        local_best_params = neighbor_params
        current_params = neighbor_params
        no_improvement_count = 0
      else
        no_improvement_count = no_improvement_count + 1
        step_size = step_size * 0.9  -- Reduce step size
      end
      
      -- Record iteration
      table.insert(self._optimization_history, {
        iteration = self._iteration_count,
        parameters = self:_copy_parameters(neighbor_params),
        score = neighbor_score,
        algorithm = "hill_climbing"
      })
    end
    
    -- Check if this restart found a better solution
    if local_best_score > best_score then
      best_score = local_best_score
      best_params = local_best_params
    end
    
    -- Random restart
    restart_count = restart_count + 1
    if restart_count <= self._config.random_restart_count then
      self:_randomize_parameters()
      no_improvement_count = 0
    end
  end
  
  self._best_score = best_score
  self._best_parameters = best_params
  
  return {
    algorithm = "hill_climbing",
    iterations = self._iteration_count,
    best_score = best_score,
    convergence = "local_optimum",
    restarts = restart_count
  }
end

function ParameterTuner:_random_search_optimization(target_conditions)
  local best_score = -math.huge
  local best_params = nil
  
  for i = 1, self._config.max_iterations do
    local random_params = self:_generate_random_parameters()
    local score = self:_evaluate_parameters(random_params, target_conditions)
    
    if score > best_score then
      best_score = score
      best_params = random_params
    end
    
    table.insert(self._optimization_history, {
      iteration = i,
      parameters = self:_copy_parameters(random_params),
      score = score,
      algorithm = "random_search"
    })
  end
  
  self._best_score = best_score
  self._best_parameters = best_params
  self._iteration_count = self._config.max_iterations
  
  return {
    algorithm = "random_search",
    iterations = self._config.max_iterations,
    best_score = best_score,
    convergence = "max_iterations"
  }
end

--- Helper functions

function ParameterTuner:_evaluate_parameters(parameters, target_conditions)
  if not self._evaluation_function then
    error("Evaluation function not set")
  end
  
  return self._evaluation_function(parameters, target_conditions)
end

function ParameterTuner:_apply_constraints(param_name, value)
  local definition = PARAMETER_DEFINITIONS[param_name]
  if not definition then
    return value
  end
  
  -- Apply min/max constraints
  value = math.max(definition.min, math.min(definition.max, value))
  
  -- Apply custom constraints if any
  local custom_constraints = self._constraints[param_name]
  if custom_constraints then
    if custom_constraints.min then
      value = math.max(custom_constraints.min, value)
    end
    if custom_constraints.max then
      value = math.min(custom_constraints.max, value)
    end
  end
  
  return value
end

function ParameterTuner:_copy_parameters(parameters)
  local copy = {}
  for k, v in pairs(parameters) do
    copy[k] = v
  end
  return copy
end

function ParameterTuner:_generate_neighbor_parameters(parameters, step_size)
  local neighbor = self:_copy_parameters(parameters)
  
  -- Randomly select a parameter to modify
  local param_names = {}
  for name, _ in pairs(parameters) do
    table.insert(param_names, name)
  end
  
  local param_to_modify = param_names[math.random(#param_names)]
  local definition = PARAMETER_DEFINITIONS[param_to_modify]
  
  if definition then
    local current_value = neighbor[param_to_modify]
    local range = definition.max - definition.min
    local delta = (math.random() - 0.5) * 2 * step_size * range
    local new_value = current_value + delta
    
    neighbor[param_to_modify] = self:_apply_constraints(param_to_modify, new_value)
  end
  
  return neighbor
end

function ParameterTuner:_generate_random_parameters()
  local random_params = {}
  
  for param_name, definition in pairs(PARAMETER_DEFINITIONS) do
    local range = definition.max - definition.min
    local random_value = definition.min + math.random() * range
    random_params[param_name] = self:_apply_constraints(param_name, random_value)
  end
  
  return random_params
end

function ParameterTuner:_randomize_parameters()
  self._current_parameters = self:_generate_random_parameters()
end

-- Placeholder implementations for other algorithms
function ParameterTuner:_simulated_annealing_optimization(target_conditions)
  -- Simplified simulated annealing implementation
  return self:_random_search_optimization(target_conditions)
end

function ParameterTuner:_genetic_algorithm_optimization(target_conditions)
  -- Simplified genetic algorithm implementation
  return self:_random_search_optimization(target_conditions)
end

function ParameterTuner:_gradient_descent_optimization(target_conditions)
  -- Simplified gradient descent implementation
  return self:_hill_climbing_optimization(target_conditions)
end

return ParameterTuner