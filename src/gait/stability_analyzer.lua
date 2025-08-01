local Object = require("object")
local Scalar = require("scalar")
local Vec3 = require("vec3")

--- Stability Analyzer
--
-- Analyzes robot stability by calculating centre of mass, support polygon,
-- and stability margins for gait validation and safety.
local StabilityAnalyzer = Object.new("StabilityAnalyzer")

--- Create a new stability analyzer
--
-- @param robot_config RobotConfig object defining robot morphology
-- @param config optional configuration table
function StabilityAnalyzer.new(robot_config, config)
  assert(robot_config, "robot_config is required")
  config = config or {}
  
  -- Default configuration
  local default_config = {
    body_mass = 2000,           -- grams (2kg default)
    leg_mass = 100,             -- grams per leg
    safety_margin = 20,         -- mm minimum distance from CoM to support edge
    min_stance_legs = 3,        -- minimum legs required for static stability
    gravity_vector = Vec3.new(0, 0, -9810)  -- mm/s² (Earth gravity)
  }
  
  -- Merge with defaults
  local merged_config = {}
  for key, value in pairs(default_config) do
    merged_config[key] = config[key] or value
  end
  
  -- Build chains and get leg information
  local chains = robot_config:build_chains()
  local leg_names = {}
  local leg_origins = {}
  
  for name, chain in pairs(chains) do
    table.insert(leg_names, name)
    leg_origins[name] = chain:origin()
  end
  table.sort(leg_names)  -- Consistent ordering
  
  return Object.instance({
    _robot_config = robot_config,
    _chains = chains,
    _leg_names = leg_names,
    _leg_origins = leg_origins,
    _config = merged_config
  }, StabilityAnalyzer)
end

--- Calculate centre of mass for current robot pose
--
-- @param leg_positions table of Vec3 positions keyed by leg name
-- @param body_position Vec3 position of robot body (optional)
-- @return Vec3 centre of mass position
function StabilityAnalyzer:calculate_centre_of_mass(leg_positions, body_position)
  assert(type(leg_positions) == "table", "leg_positions must be a table")
  Object.assert_type(body_position, Vec3, true)
  
  body_position = body_position or Vec3.zero()
  
  local total_mass = self._config.body_mass
  local weighted_position = body_position * self._config.body_mass
  
  -- Add contribution from each leg
  for _, leg_name in ipairs(self._leg_names) do
    local leg_pos = leg_positions[leg_name]
    if leg_pos then
      Object.assert_type(leg_pos, Vec3)
      total_mass = total_mass + self._config.leg_mass
      weighted_position = weighted_position + (leg_pos * self._config.leg_mass)
    end
  end
  
  return weighted_position / total_mass
end

--- Calculate support polygon from stance leg positions
--
-- @param leg_positions table of Vec3 positions keyed by leg name
-- @param stance_legs array of leg names currently in stance
-- @return array of Vec3 points forming convex hull (support polygon)
function StabilityAnalyzer:calculate_support_polygon(leg_positions, stance_legs)
  assert(type(leg_positions) == "table", "leg_positions must be a table")
  assert(type(stance_legs) == "table", "stance_legs must be an array")
  
  if #stance_legs < 3 then
    return {}  -- Cannot form a polygon with less than 3 points
  end
  
  -- Get stance leg positions
  local stance_points = {}
  for _, leg_name in ipairs(stance_legs) do
    local pos = leg_positions[leg_name]
    if pos then
      -- Project to ground plane (z=0 for 2D polygon)
      table.insert(stance_points, Vec3.new(pos:x(), pos:y(), 0))
    end
  end
  
  if #stance_points < 3 then
    return {}
  end
  
  -- Calculate convex hull using Graham scan algorithm
  return self:_convex_hull(stance_points)
end

--- Check if centre of mass is within support polygon
--
-- @param centre_of_mass Vec3 centre of mass position
-- @param support_polygon array of Vec3 points forming convex hull
-- @return true if stable, false otherwise
function StabilityAnalyzer:is_statically_stable(centre_of_mass, support_polygon)
  Object.assert_type(centre_of_mass, Vec3)
  assert(type(support_polygon) == "table", "support_polygon must be an array")
  
  if #support_polygon < 3 then
    return false  -- No valid support polygon
  end
  
  -- Project CoM to ground plane
  local com_2d = Vec3.new(centre_of_mass:x(), centre_of_mass:y(), 0)
  
  -- Check if point is inside convex polygon using cross product method
  return self:_point_in_convex_polygon(com_2d, support_polygon)
end

--- Calculate stability margin (distance from CoM to nearest support edge)
--
-- @param centre_of_mass Vec3 centre of mass position
-- @param support_polygon array of Vec3 points forming convex hull
-- @return distance in mm (positive = stable, negative = unstable)
function StabilityAnalyzer:calculate_stability_margin(centre_of_mass, support_polygon)
  Object.assert_type(centre_of_mass, Vec3)
  assert(type(support_polygon) == "table", "support_polygon must be an array")
  
  if #support_polygon < 3 then
    return -math.huge  -- No support polygon = maximally unstable
  end
  
  -- Project CoM to ground plane
  local com_2d = Vec3.new(centre_of_mass:x(), centre_of_mass:y(), 0)
  
  -- Find minimum distance to polygon edges
  local min_distance = math.huge
  local is_inside = self:_point_in_convex_polygon(com_2d, support_polygon)
  
  for i = 1, #support_polygon do
    local p1 = support_polygon[i]
    local p2 = support_polygon[(i % #support_polygon) + 1]
    
    local distance = self:_point_to_line_distance(com_2d, p1, p2)
    min_distance = math.min(min_distance, distance)
  end
  
  -- Return positive distance if inside polygon, negative if outside
  return is_inside and min_distance or -min_distance
end

--- Validate gait stability at current state
--
-- @param leg_positions table of Vec3 positions keyed by leg name
-- @param stance_legs array of leg names currently in stance
-- @param body_position Vec3 position of robot body (optional)
-- @return is_stable (boolean), stability_margin (number), centre_of_mass (Vec3)
function StabilityAnalyzer:validate_stability(leg_positions, stance_legs, body_position)
  assert(type(leg_positions) == "table", "leg_positions must be a table")
  assert(type(stance_legs) == "table", "stance_legs must be an array")
  Object.assert_type(body_position, Vec3, true)
  
  -- Check minimum stance legs requirement
  if #stance_legs < self._config.min_stance_legs then
    return false, -math.huge, Vec3.zero()
  end
  
  -- Calculate centre of mass
  local centre_of_mass = self:calculate_centre_of_mass(leg_positions, body_position)
  
  -- Calculate support polygon
  local support_polygon = self:calculate_support_polygon(leg_positions, stance_legs)
  
  -- Check static stability
  local is_stable = self:is_statically_stable(centre_of_mass, support_polygon)
  
  -- Calculate stability margin
  local stability_margin = self:calculate_stability_margin(centre_of_mass, support_polygon)
  
  -- Apply safety margin requirement
  local is_safe = is_stable and (stability_margin >= self._config.safety_margin)
  
  return is_safe, stability_margin, centre_of_mass
end

--- Calculate maximum safe velocity for current stability state
--
-- @param stability_margin current stability margin in mm
-- @param cycle_time gait cycle time in seconds
-- @return maximum safe velocity in mm/s
function StabilityAnalyzer:calculate_max_safe_velocity(stability_margin, cycle_time)
  Scalar.assert_type(stability_margin, "number")
  Scalar.assert_type(cycle_time, "number")
  assert(cycle_time > 0, "cycle_time must be positive")
  
  if stability_margin <= 0 then
    return 0  -- No movement if unstable
  end
  
  -- Conservative approach: limit velocity based on stability margin
  -- Allow movement that won't exceed safety margin in one cycle
  local available_margin = stability_margin - self._config.safety_margin
  if available_margin <= 0 then
    return 0
  end
  
  -- Maximum velocity that keeps CoM within safety bounds
  -- Longer cycle time allows higher velocity due to more time for corrections
  local max_velocity = available_margin * cycle_time
  
  -- Apply reasonable upper limit (e.g., 200 mm/s)
  return math.min(max_velocity, 200)
end

--- Get recommended gait parameters for stability
--
-- @param current_stability_margin current margin in mm
-- @return table with recommended step_height, cycle_time, duty_factor
function StabilityAnalyzer:get_stability_recommendations(current_stability_margin)
  Scalar.assert_type(current_stability_margin, "number")
  
  local recommendations = {
    step_height = 30,     -- mm
    cycle_time = 2.0,     -- seconds
    duty_factor = 0.75,   -- fraction in stance
    max_velocity = 100    -- mm/s
  }
  
  if current_stability_margin < self._config.safety_margin then
    -- Reduce performance for better stability
    recommendations.step_height = 20
    recommendations.cycle_time = 3.0
    recommendations.duty_factor = 0.85
    recommendations.max_velocity = 50
  elseif current_stability_margin > self._config.safety_margin * 2 then
    -- Can afford more aggressive parameters
    recommendations.step_height = 40
    recommendations.cycle_time = 1.5
    recommendations.duty_factor = 0.65
    recommendations.max_velocity = 150
  end
  
  return recommendations
end

--- Calculate convex hull using Graham scan algorithm
--
-- @param points array of Vec3 points
-- @return array of Vec3 points forming convex hull
function StabilityAnalyzer:_convex_hull(points)
  if #points < 3 then
    return points
  end
  
  -- Find bottom-most point (and leftmost if tie)
  local start_idx = 1
  for i = 2, #points do
    local p = points[i]
    local start = points[start_idx]
    if p:y() < start:y() or (p:y() == start:y() and p:x() < start:x()) then
      start_idx = i
    end
  end
  
  -- Swap start point to beginning
  points[1], points[start_idx] = points[start_idx], points[1]
  local start_point = points[1]
  
  -- Sort points by polar angle with respect to start point
  local function polar_angle_compare(a, b)
    local cross = self:_cross_product_2d(
      Vec3.new(a:x() - start_point:x(), a:y() - start_point:y(), 0),
      Vec3.new(b:x() - start_point:x(), b:y() - start_point:y(), 0)
    )
    
    if math.abs(cross) < 1e-9 then
      -- Collinear points - choose closer one
      local dist_a = start_point:distance(a)
      local dist_b = start_point:distance(b)
      return dist_a < dist_b
    end
    
    return cross > 0
  end
  
  -- Sort remaining points
  local remaining = {}
  for i = 2, #points do
    table.insert(remaining, points[i])
  end
  table.sort(remaining, polar_angle_compare)
  
  -- Build convex hull
  local hull = {start_point}
  
  for _, point in ipairs(remaining) do
    -- Remove points that create right turn
    while #hull >= 2 do
      local cross = self:_cross_product_2d(
        Vec3.new(hull[#hull]:x() - hull[#hull-1]:x(), hull[#hull]:y() - hull[#hull-1]:y(), 0),
        Vec3.new(point:x() - hull[#hull]:x(), point:y() - hull[#hull]:y(), 0)
      )
      
      if cross <= 0 then
        table.remove(hull)
      else
        break
      end
    end
    
    table.insert(hull, point)
  end
  
  return hull
end

--- Check if point is inside convex polygon
--
-- @param point Vec3 point to test
-- @param polygon array of Vec3 points forming convex polygon
-- @return true if point is inside polygon
function StabilityAnalyzer:_point_in_convex_polygon(point, polygon)
  if #polygon < 3 then
    return false
  end
  
  -- Check if point is on the same side of all edges
  local sign = nil
  
  for i = 1, #polygon do
    local p1 = polygon[i]
    local p2 = polygon[(i % #polygon) + 1]
    
    local cross = self:_cross_product_2d(
      Vec3.new(p2:x() - p1:x(), p2:y() - p1:y(), 0),
      Vec3.new(point:x() - p1:x(), point:y() - p1:y(), 0)
    )
    
    if math.abs(cross) > 1e-9 then  -- Not on edge
      local current_sign = cross > 0
      if sign == nil then
        sign = current_sign
      elseif sign ~= current_sign then
        return false  -- Point is outside
      end
    end
  end
  
  return true
end

--- Calculate 2D cross product
--
-- @param a Vec3 vector
-- @param b Vec3 vector
-- @return cross product (scalar)
function StabilityAnalyzer:_cross_product_2d(a, b)
  return a:x() * b:y() - a:y() * b:x()
end

--- Calculate distance from point to line segment
--
-- @param point Vec3 point
-- @param line_start Vec3 start of line segment
-- @param line_end Vec3 end of line segment
-- @return distance in mm
function StabilityAnalyzer:_point_to_line_distance(point, line_start, line_end)
  local line_vec = line_end - line_start
  local point_vec = point - line_start
  
  local line_length_sq = line_vec:dot(line_vec)
  
  if line_length_sq < 1e-9 then
    -- Line is actually a point
    return point:distance(line_start)
  end
  
  -- Project point onto line
  local t = point_vec:dot(line_vec) / line_length_sq
  t = math.max(0, math.min(1, t))  -- Clamp to line segment
  
  local projection = line_start + (line_vec * t)
  return point:distance(projection)
end

--- Set configuration parameter
--
-- @param key parameter name
-- @param value parameter value
function StabilityAnalyzer:set_config(key, value)
  Scalar.assert_type(key, "string")
  
  if self._config[key] ~= nil then
    self._config[key] = value
  else
    error("Unknown configuration parameter: " .. key)
  end
end

--- Get configuration parameter
--
-- @param key parameter name
-- @return parameter value
function StabilityAnalyzer:get_config(key)
  Scalar.assert_type(key, "string")
  return self._config[key]
end

return StabilityAnalyzer