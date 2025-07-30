local Object = require("object")
local Scalar = require("scalar")

--- Servo Channel Mapper
--
-- Maps kinematic chain joints to ArduPilot servo output channels and validates
-- that sufficient channels are available for the robot configuration.
local ServoMapper = Object.new("ServoMapper")

--- ArduPilot servo function assignments for kinematic chains
local SERVO_FUNCTIONS = {
  -- Standard servo functions (1-16 are main outputs)
  DISABLED = 0,
  RC_PASSTHROUGH = 1,
  MOTOR1 = 33,
  MOTOR2 = 34,
  MOTOR3 = 35,
  MOTOR4 = 36,
  
  -- Kinematic chain servo functions (custom range)
  KINEMATIC_JOINT_1 = 100,
  KINEMATIC_JOINT_2 = 101,
  KINEMATIC_JOINT_3 = 102,
  KINEMATIC_JOINT_4 = 103,
  KINEMATIC_JOINT_5 = 104,
  KINEMATIC_JOINT_6 = 105,
  KINEMATIC_JOINT_7 = 106,
  KINEMATIC_JOINT_8 = 107,
  KINEMATIC_JOINT_9 = 108,
  KINEMATIC_JOINT_10 = 109,
  KINEMATIC_JOINT_11 = 110,
  KINEMATIC_JOINT_12 = 111,
  KINEMATIC_JOINT_13 = 112,
  KINEMATIC_JOINT_14 = 113,
  KINEMATIC_JOINT_15 = 114,
  KINEMATIC_JOINT_16 = 115,
  KINEMATIC_JOINT_17 = 116,
  KINEMATIC_JOINT_18 = 117,
  KINEMATIC_JOINT_19 = 118,
  KINEMATIC_JOINT_20 = 119,
  KINEMATIC_JOINT_21 = 120,
  KINEMATIC_JOINT_22 = 121,
  KINEMATIC_JOINT_23 = 122,
  KINEMATIC_JOINT_24 = 123
}

--- Platform servo channel limits
local PLATFORM_LIMITS = {
  -- Common ArduPilot autopilot servo channel counts
  PIXHAWK = 16,      -- Pixhawk 1/2/4/6 series
  CUBE_ORANGE = 16,  -- CubePilot Orange/Purple
  DURANDAL = 16,     -- Holybro Durandal
  KAKUTE_F7 = 8,     -- Holybro Kakute F7
  MATEK_F405 = 8,    -- Matek F405 series
  GENERIC_F4 = 8,    -- Generic F4-based autopilots
  GENERIC_F7 = 16,   -- Generic F7-based autopilots
  GENERIC_H7 = 16    -- Generic H7-based autopilots
}

function ServoMapper.new(platform, max_channels)
  Scalar.assert_type(platform, "string", true)
  Scalar.assert_type(max_channels, "number", true)
  
  -- Determine channel limit
  local channel_limit
  if max_channels then
    channel_limit = max_channels
  elseif platform and PLATFORM_LIMITS[platform:upper()] then
    channel_limit = PLATFORM_LIMITS[platform:upper()]
  else
    channel_limit = PLATFORM_LIMITS.PIXHAWK  -- Default to Pixhawk
  end
  
  return Object.instance({
    _platform = platform or "PIXHAWK",
    _max_channels = channel_limit,
    _channel_assignments = {},
    _reserved_channels = {},
    _next_kinematic_function = SERVO_FUNCTIONS.KINEMATIC_JOINT_1
  }, ServoMapper)
end

--- Reserve servo channels for non-kinematic functions
--
-- @param channels array of channel numbers to reserve (1-based)
-- @param purpose string describing what the channels are used for
function ServoMapper:reserve_channels(channels, purpose)
  assert(type(channels) == "table", "Channels must be an array")
  Scalar.assert_type(purpose, "string", true)
  
  for _, channel in ipairs(channels) do
    assert(type(channel) == "number", "Channel must be a number")
    assert(channel >= 1 and channel <= self._max_channels, 
           "Channel " .. channel .. " is outside valid range 1-" .. self._max_channels)
    
    if self._reserved_channels[channel] then
      error("Channel " .. channel .. " is already reserved for " .. self._reserved_channels[channel])
    end
    
    self._reserved_channels[channel] = purpose or "unknown"
  end
end

--- Map kinematic chains to servo channels
--
-- @param robot_config RobotConfig object
-- @return table mapping joint identifiers to servo channels and functions
function ServoMapper:map_robot(robot_config)
  local mapping = {
    joints = {},
    channels_used = 0,
    channels_available = self._max_channels - self:_count_reserved_channels(),
    assignments = {}
  }
  
  local current_channel = 1
  local current_function = self._next_kinematic_function
  
  -- Iterate through all chains and joints
  for chain_name, chain_config in pairs(robot_config._chains) do
    if chain_config.segments then
      for segment_index, segment in ipairs(chain_config.segments) do
        -- Only hinge joints can be mapped to servos (ball joints need multiple servos)
        if segment.joint_config and segment.joint_config.type == "hinge" then
        -- Find next available channel
        while current_channel <= self._max_channels and self._reserved_channels[current_channel] do
          current_channel = current_channel + 1
        end
        
        if current_channel > self._max_channels then
          error("Insufficient servo channels: need more than " .. self._max_channels .. " channels")
        end
        
        -- Create joint identifier
        local joint_id = chain_name .. "_joint_" .. segment_index
        
        -- Create mapping entry
        local joint_mapping = {
          joint_id = joint_id,
          chain_name = chain_name,
          segment_index = segment_index,
          servo_channel = current_channel,
          servo_function = current_function,
          joint_type = segment.joint_config.type,
          link_name = segment.link_name
        }
        
        mapping.joints[joint_id] = joint_mapping
        mapping.assignments[current_channel] = joint_mapping
        
        current_channel = current_channel + 1
        current_function = current_function + 1
        mapping.channels_used = mapping.channels_used + 1
        elseif segment.joint_config and segment.joint_config.type == "ball" then
          -- Ball joints require multiple servos - this is a more complex mapping
          -- For now, we'll note them but not assign channels
          local joint_id = chain_name .. "_ball_joint_" .. segment_index
          mapping.joints[joint_id] = {
            joint_id = joint_id,
            chain_name = chain_name,
            segment_index = segment_index,
            servo_channel = nil,  -- Ball joints need special handling
            servo_function = nil,
            joint_type = "ball",
            link_name = segment.link_name,
            note = "Ball joint requires multiple servo channels - not yet implemented"
          }
        end
      end
    end
  end
  
  return mapping
end

--- Generate ArduPilot parameter configuration
--
-- @param mapping servo mapping from map_robot()
-- @return table of parameter name/value pairs
function ServoMapper:generate_parameters(mapping)
  local parameters = {}
  
  for channel, assignment in pairs(mapping.assignments) do
    if assignment.servo_function then
      local param_name = "SERVO" .. channel .. "_FUNCTION"
      parameters[param_name] = assignment.servo_function
      
      -- Set reasonable defaults for kinematic joints
      parameters["SERVO" .. channel .. "_MIN"] = 1000
      parameters["SERVO" .. channel .. "_MAX"] = 2000
      parameters["SERVO" .. channel .. "_TRIM"] = 1500
      parameters["SERVO" .. channel .. "_REVERSED"] = 0
    end
  end
  
  return parameters
end

--- Get mapping summary for debugging
--
-- @param mapping servo mapping from map_robot()
-- @return string summary
function ServoMapper:get_mapping_summary(mapping)
  local lines = {}
  table.insert(lines, "Servo Channel Mapping Summary:")
  table.insert(lines, string.format("Platform: %s (max %d channels)", self._platform, self._max_channels))
  table.insert(lines, string.format("Channels used: %d, available: %d", 
                                   mapping.channels_used, mapping.channels_available))
  
  if self:_count_reserved_channels() > 0 then
    table.insert(lines, "\nReserved channels:")
    for channel, purpose in pairs(self._reserved_channels) do
      table.insert(lines, string.format("  Channel %d: %s", channel, purpose))
    end
  end
  
  table.insert(lines, "\nKinematic joint assignments:")
  for joint_id, assignment in pairs(mapping.joints) do
    if assignment.servo_channel then
      table.insert(lines, string.format("  %s -> Channel %d (Function %d)", 
                                       joint_id, assignment.servo_channel, assignment.servo_function))
    else
      table.insert(lines, string.format("  %s -> %s", joint_id, assignment.note or "No channel assigned"))
    end
  end
  
  return table.concat(lines, "\n")
end

--- Validate that the robot configuration can fit on the platform
--
-- @param robot_config RobotConfig object
-- @return boolean success, string error_message
function ServoMapper:validate_robot_fit(robot_config)
  local hinge_joint_count = 0
  local ball_joint_count = 0
  
  -- Count joints that need servo channels
  for chain_name, chain_config in pairs(robot_config._chains) do
    if chain_config.segments then
      for _, segment in ipairs(chain_config.segments) do
        if segment.joint_config then
          if segment.joint_config.type == "hinge" then
            hinge_joint_count = hinge_joint_count + 1
          elseif segment.joint_config.type == "ball" then
            ball_joint_count = ball_joint_count + 1
          end
        end
      end
    end
  end
  
  local reserved_count = self:_count_reserved_channels()
  local available_channels = self._max_channels - reserved_count
  
  -- For now, assume ball joints need 2 servos each (simplified)
  local required_channels = hinge_joint_count + (ball_joint_count * 2)
  
  if required_channels > available_channels then
    return false, string.format(
      "Robot requires %d servo channels (%d hinge + %d ball*2) but only %d available (%d total - %d reserved)",
      required_channels, hinge_joint_count, ball_joint_count, 
      available_channels, self._max_channels, reserved_count
    )
  end
  
  return true, nil
end

--- Count reserved channels
function ServoMapper:_count_reserved_channels()
  local count = 0
  for _ in pairs(self._reserved_channels) do
    count = count + 1
  end
  return count
end

ServoMapper.SERVO_FUNCTIONS = SERVO_FUNCTIONS
ServoMapper.PLATFORM_LIMITS = PLATFORM_LIMITS

return ServoMapper