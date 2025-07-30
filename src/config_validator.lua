local Object = require("object")
local Scalar = require("scalar")
local Vec3 = require("vec3")
local Angle = require("angle")
local ServoMapper = require("servo_mapper")

--- Configuration Validator
--
-- Validates robot configurations for correctness and safety
local ConfigValidator = Object.new("ConfigValidator")

function ConfigValidator.new(platform, max_channels, reserved_channels)
  local instance = Object.instance({
    _errors = {},
    _warnings = {},
    _servo_mapper = ServoMapper.new(platform, max_channels)
  }, ConfigValidator)
  
  -- Reserve channels if specified
  if reserved_channels then
    for purpose, channels in pairs(reserved_channels) do
      instance._servo_mapper:reserve_channels(channels, purpose)
    end
  end
  
  return instance
end

--- Validate a robot configuration
--
-- @param config RobotConfig object to validate
-- @return boolean true if valid, false if errors found
function ConfigValidator:validate(config)
  self._errors = {}
  self._warnings = {}
  
  self:_validate_basic_structure(config)
  
  if #self._errors == 0 then
    self:_validate_chains(config)
    self:_validate_physical_constraints(config)
    self:_validate_servo_requirements(config)
  end
  
  return #self._errors == 0
end

--- Get validation errors
--
-- @return array of error messages
function ConfigValidator:get_errors()
  return self._errors
end

--- Get validation warnings
--
-- @return array of warning messages
function ConfigValidator:get_warnings()
  return self._warnings
end

--- Get servo mapping for the validated configuration
--
-- @param config RobotConfig object (must be validated first)
-- @return servo mapping table or nil if validation failed
function ConfigValidator:get_servo_mapping(config)
  if #self._errors > 0 then
    return nil
  end
  
  return self._servo_mapper:map_robot(config)
end

--- Get ArduPilot parameters for the servo configuration
--
-- @param config RobotConfig object (must be validated first)
-- @return table of parameter name/value pairs
function ConfigValidator:get_servo_parameters(config)
  local mapping = self:get_servo_mapping(config)
  if not mapping then
    return nil
  end
  
  return self._servo_mapper:generate_parameters(mapping)
end

--- Validate basic configuration structure
function ConfigValidator:_validate_basic_structure(config)
  if not config then
    self:_add_error("Configuration is nil")
    return
  end
  
  if not config._chains then
    self:_add_error("Configuration missing chains")
    return
  end
  
  local chain_count = 0
  for _ in pairs(config._chains) do
    chain_count = chain_count + 1
  end
  
  if chain_count == 0 then
    self:_add_error("Configuration has no chains defined")
  elseif chain_count > 12 then
    self:_add_warning("Configuration has " .. chain_count .. " chains, which may exceed servo output limits")
  end
end

--- Validate individual chains
function ConfigValidator:_validate_chains(config)
  for chain_name, chain_config in pairs(config._chains) do
    self:_validate_chain(chain_name, chain_config)
  end
end

--- Validate a single chain configuration
function ConfigValidator:_validate_chain(chain_name, chain_config)
  local context = "Chain '" .. chain_name .. "'"
  
  -- Validate chain name
  if not chain_name or chain_name == "" then
    self:_add_error(context .. ": Chain name cannot be empty")
    return
  end
  
  -- Validate origin
  if chain_config.origin and not self:_is_valid_vec3(chain_config.origin) then
    self:_add_error(context .. ": Invalid origin vector")
  end
  
  -- Validate segments
  if not chain_config.segments then
    self:_add_error(context .. ": Missing segments")
    return
  end
  
  if #chain_config.segments == 0 then
    self:_add_error(context .. ": Chain has no segments")
    return
  end
  
  if #chain_config.segments > 6 then
    self:_add_warning(context .. ": Chain has " .. #chain_config.segments .. " segments, which may be excessive")
  end
  
  -- Validate each segment
  for i, segment in ipairs(chain_config.segments) do
    self:_validate_segment(chain_name, i, segment)
  end
end

--- Validate a single segment
function ConfigValidator:_validate_segment(chain_name, segment_index, segment)
  local context = "Chain '" .. chain_name .. "' segment " .. segment_index
  
  -- Validate joint configuration
  if not segment.joint_config then
    self:_add_error(context .. ": Missing joint configuration")
    return
  end
  
  self:_validate_joint_config(context, segment.joint_config)
  
  -- Validate link
  if not segment.link_length then
    self:_add_error(context .. ": Missing link length")
  elseif type(segment.link_length) ~= "number" then
    self:_add_error(context .. ": Link length must be a number")
  elseif segment.link_length <= 0 then
    self:_add_error(context .. ": Link length must be positive")
  elseif segment.link_length > 1000 then
    self:_add_warning(context .. ": Link length " .. segment.link_length .. " seems very large")
  end
  
  -- Validate link name (optional)
  if segment.link_name and type(segment.link_name) ~= "string" then
    self:_add_error(context .. ": Link name must be a string")
  end
end

--- Validate joint configuration
function ConfigValidator:_validate_joint_config(context, joint_config)
  if not joint_config.type then
    self:_add_error(context .. ": Missing joint type")
    return
  end
  
  if joint_config.type == "ball" then
    self:_validate_ball_joint(context, joint_config)
  elseif joint_config.type == "hinge" then
    self:_validate_hinge_joint(context, joint_config)
  else
    self:_add_error(context .. ": Unknown joint type '" .. joint_config.type .. "'")
  end
end

--- Validate ball joint configuration
function ConfigValidator:_validate_ball_joint(context, joint_config)
  if not joint_config.reference_axis then
    self:_add_error(context .. ": Ball joint missing reference axis")
  elseif not self:_is_valid_vec3(joint_config.reference_axis) then
    self:_add_error(context .. ": Ball joint reference axis must be a valid Vec3")
  elseif self:_is_zero_vec3(joint_config.reference_axis) then
    self:_add_error(context .. ": Ball joint reference axis cannot be zero vector")
  end
  
  if joint_config.max_constraint then
    if not self:_is_valid_angle(joint_config.max_constraint) then
      self:_add_error(context .. ": Ball joint max constraint must be a valid Angle")
    elseif joint_config.max_constraint:degrees() < 0 or joint_config.max_constraint:degrees() > 180 then
      self:_add_error(context .. ": Ball joint max constraint must be between 0 and 180 degrees")
    end
  end
end

--- Validate hinge joint configuration
function ConfigValidator:_validate_hinge_joint(context, joint_config)
  if not joint_config.rotation_axis then
    self:_add_error(context .. ": Hinge joint missing rotation axis")
  elseif not self:_is_valid_vec3(joint_config.rotation_axis) then
    self:_add_error(context .. ": Hinge joint rotation axis must be a valid Vec3")
  elseif self:_is_zero_vec3(joint_config.rotation_axis) then
    self:_add_error(context .. ": Hinge joint rotation axis cannot be zero vector")
  end
  
  if not joint_config.reference_axis then
    self:_add_error(context .. ": Hinge joint missing reference axis")
  elseif not self:_is_valid_vec3(joint_config.reference_axis) then
    self:_add_error(context .. ": Hinge joint reference axis must be a valid Vec3")
  elseif self:_is_zero_vec3(joint_config.reference_axis) then
    self:_add_error(context .. ": Hinge joint reference axis cannot be zero vector")
  end
  
  -- Check that axes are perpendicular
  if joint_config.rotation_axis and joint_config.reference_axis and
     self:_is_valid_vec3(joint_config.rotation_axis) and self:_is_valid_vec3(joint_config.reference_axis) then
    local dot_product = joint_config.rotation_axis:dot(joint_config.reference_axis)
    if math.abs(dot_product) > Scalar.FLOAT_EPSILON then
      self:_add_error(context .. ": Hinge joint axes must be perpendicular")
    end
  end
  
  -- Validate constraints
  if joint_config.clockwise_constraint then
    if not self:_is_valid_angle(joint_config.clockwise_constraint) then
      self:_add_error(context .. ": Hinge joint clockwise constraint must be a valid Angle")
    elseif joint_config.clockwise_constraint:degrees() < 0 or joint_config.clockwise_constraint:degrees() > 180 then
      self:_add_error(context .. ": Hinge joint clockwise constraint must be between 0 and 180 degrees")
    end
  end
  
  if joint_config.anticlockwise_constraint then
    if not self:_is_valid_angle(joint_config.anticlockwise_constraint) then
      self:_add_error(context .. ": Hinge joint anticlockwise constraint must be a valid Angle")
    elseif joint_config.anticlockwise_constraint:degrees() < 0 or joint_config.anticlockwise_constraint:degrees() > 180 then
      self:_add_error(context .. ": Hinge joint anticlockwise constraint must be between 0 and 180 degrees")
    end
  end
end

--- Validate physical constraints and reachability
function ConfigValidator:_validate_physical_constraints(config)
  for chain_name, chain_config in pairs(config._chains) do
    local total_reach = 0
    
    -- Skip if segments is missing (error already reported)
    if chain_config.segments then
      for _, segment in ipairs(chain_config.segments) do
        if segment.link_length and type(segment.link_length) == "number" then
          total_reach = total_reach + segment.link_length
        end
      end
      
      if total_reach == 0 then
        self:_add_warning("Chain '" .. chain_name .. "' has zero total reach")
      elseif total_reach > 2000 then
        self:_add_warning("Chain '" .. chain_name .. "' has very large total reach: " .. total_reach)
      end
    end
  end
end

--- Validate servo channel requirements
function ConfigValidator:_validate_servo_requirements(config)
  local success, error_message = self._servo_mapper:validate_robot_fit(config)
  
  if not success then
    self:_add_error("Servo channel constraint: " .. error_message)
    return
  end
  
  -- Count different joint types for informational purposes
  local hinge_count = 0
  local ball_count = 0
  
  for chain_name, chain_config in pairs(config._chains) do
    if chain_config.segments then
      for _, segment in ipairs(chain_config.segments) do
        if segment.joint_config then
          if segment.joint_config.type == "hinge" then
            hinge_count = hinge_count + 1
          elseif segment.joint_config.type == "ball" then
            ball_count = ball_count + 1
          end
        end
      end
    end
  end
  
  -- Generate mapping to check for any issues
  local mapping = self._servo_mapper:map_robot(config)
  
  if ball_count > 0 then
    self:_add_warning(string.format(
      "Configuration contains %d ball joints which require multiple servos each - advanced servo mapping needed",
      ball_count
    ))
  end
  
  if mapping.channels_used > mapping.channels_available * 0.8 then
    self:_add_warning(string.format(
      "Using %d of %d available servo channels (%.1f%%) - consider reserving channels for other functions",
      mapping.channels_used, mapping.channels_available, 
      (mapping.channels_used / mapping.channels_available) * 100
    ))
  end
end

--- Helper functions
function ConfigValidator:_add_error(message)
  table.insert(self._errors, message)
end

function ConfigValidator:_add_warning(message)
  table.insert(self._warnings, message)
end

function ConfigValidator:_is_valid_vec3(vec)
  return vec and type(vec) == "table" and vec.x and vec.y and vec.z
end

function ConfigValidator:_is_zero_vec3(vec)
  return vec and vec:length() < Scalar.FLOAT_EPSILON
end

function ConfigValidator:_is_valid_angle(angle)
  return angle and type(angle) == "table" and angle.degrees
end

return ConfigValidator