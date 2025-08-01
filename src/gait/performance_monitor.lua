local Object = require("object")
local Scalar = require("scalar")

--- Performance Monitor
--
-- Tracks and analyzes gait generator performance metrics including
-- computation time, memory usage, stability, and energy efficiency.
local PerformanceMonitor = Object.new("PerformanceMonitor")

--- Default monitoring configuration
local DEFAULT_CONFIG = {
  enable_timing = true,           -- Track computation times
  enable_memory_tracking = true,  -- Track memory usage
  enable_stability_tracking = true, -- Track stability metrics
  enable_energy_tracking = true,  -- Track energy efficiency
  sample_window_size = 100,       -- Number of samples to keep in rolling window
  alert_threshold_ms = 1.0,       -- Alert if computation exceeds this time
  memory_alert_threshold = 1024,  -- Alert if memory usage exceeds this (KB)
  stability_alert_threshold = 10.0, -- Alert if stability margin drops below this (mm)
  enable_profiling = false,       -- Enable detailed profiling
  profile_sample_rate = 0.1       -- Fraction of cycles to profile (0.0-1.0)
}

function PerformanceMonitor.new(config)
  if config ~= nil then
    assert(type(config) == "table", "config must be a table")
  end
  
  local merged_config = {}
  for k, v in pairs(DEFAULT_CONFIG) do
    merged_config[k] = config and config[k] or v
  end
  
  return Object.instance({
    _config = merged_config,
    _timing_samples = {},
    _memory_samples = {},
    _stability_samples = {},
    _energy_samples = {},
    _profile_data = {},
    _current_session = {
      start_time = 0,
      cycle_count = 0,
      total_computation_time = 0,
      peak_memory_usage = 0,
      min_stability_margin = math.huge,
      average_energy_cost = 0,
      alerts = {}
    },
    _active_timers = {},
    _last_gc_time = 0
  }, PerformanceMonitor)
end

--- Start a new monitoring session
--
-- @param session_name optional name for the session
function PerformanceMonitor:start_session(session_name)
  session_name = session_name or "default"
  
  local current_time = self:_get_current_time()
  
  self._current_session = {
    name = session_name,
    start_time = current_time,
    cycle_count = 0,
    total_computation_time = 0,
    peak_memory_usage = 0,
    min_stability_margin = math.huge,
    average_energy_cost = 0,
    alerts = {}
  }
  
  -- Clear sample windows
  self._timing_samples = {}
  self._memory_samples = {}
  self._stability_samples = {}
  self._energy_samples = {}
  
  if self._config.enable_profiling then
    self._profile_data = {}
  end
end

--- Start timing a specific operation
--
-- @param operation_name name of the operation being timed
function PerformanceMonitor:start_timer(operation_name)
  if not self._config.enable_timing then
    return
  end
  
  assert(type(operation_name) == "string", "operation_name must be a string")
  
  self._active_timers[operation_name] = self:_get_current_time()
end

--- Stop timing an operation and record the result
--
-- @param operation_name name of the operation being timed
-- @return elapsed time in milliseconds
function PerformanceMonitor:stop_timer(operation_name)
  if not self._config.enable_timing then
    return 0
  end
  
  assert(type(operation_name) == "string", "operation_name must be a string")
  
  local start_time = self._active_timers[operation_name]
  if not start_time then
    error("Timer not started for operation: " .. operation_name)
  end
  
  local end_time = self:_get_current_time()
  local elapsed_ms = (end_time - start_time) * 1000
  
  -- Record timing sample
  self:_add_timing_sample(operation_name, elapsed_ms)
  
  -- Check for performance alerts
  if elapsed_ms > self._config.alert_threshold_ms then
    self:_add_alert("timing", string.format("%s took %.2fms (threshold: %.2fms)", 
                    operation_name, elapsed_ms, self._config.alert_threshold_ms))
  end
  
  -- Update session totals
  self._current_session.total_computation_time = self._current_session.total_computation_time + elapsed_ms
  
  self._active_timers[operation_name] = nil
  return elapsed_ms
end

--- Record a gait cycle completion
--
-- @param cycle_data table with cycle performance data
function PerformanceMonitor:record_cycle(cycle_data)
  assert(type(cycle_data) == "table", "cycle_data must be a table")
  
  self._current_session.cycle_count = self._current_session.cycle_count + 1
  
  -- Record memory usage
  if self._config.enable_memory_tracking then
    local memory_kb = self:_get_memory_usage()
    self:_add_memory_sample(memory_kb)
    
    if memory_kb > self._current_session.peak_memory_usage then
      self._current_session.peak_memory_usage = memory_kb
    end
    
    if memory_kb > self._config.memory_alert_threshold then
      self:_add_alert("memory", string.format("Memory usage: %.1fKB (threshold: %.1fKB)", 
                      memory_kb, self._config.memory_alert_threshold))
    end
  end
  
  -- Record stability metrics
  if self._config.enable_stability_tracking and cycle_data.stability_margin then
    self:_add_stability_sample(cycle_data.stability_margin)
    
    if cycle_data.stability_margin < self._current_session.min_stability_margin then
      self._current_session.min_stability_margin = cycle_data.stability_margin
    end
    
    if cycle_data.stability_margin < self._config.stability_alert_threshold then
      self:_add_alert("stability", string.format("Low stability margin: %.1fmm (threshold: %.1fmm)", 
                      cycle_data.stability_margin, self._config.stability_alert_threshold))
    end
  end
  
  -- Record energy efficiency
  if self._config.enable_energy_tracking and cycle_data.energy_cost then
    self:_add_energy_sample(cycle_data.energy_cost)
    
    -- Update running average
    local total_cycles = self._current_session.cycle_count
    self._current_session.average_energy_cost = 
      ((self._current_session.average_energy_cost * (total_cycles - 1)) + cycle_data.energy_cost) / total_cycles
  end
  
  -- Profile this cycle if enabled and selected
  if self._config.enable_profiling and math.random() < self._config.profile_sample_rate then
    self:_record_profile_data(cycle_data)
  end
end

--- Get current performance statistics
--
-- @return table with current performance metrics
function PerformanceMonitor:get_statistics()
  local current_time = self:_get_current_time()
  local session_duration = current_time - self._current_session.start_time
  
  local stats = {
    session = {
      name = self._current_session.name,
      duration_seconds = session_duration,
      cycle_count = self._current_session.cycle_count,
      cycles_per_second = session_duration > 0 and self._current_session.cycle_count / session_duration or 0,
      total_computation_time_ms = self._current_session.total_computation_time,
      average_cycle_time_ms = self._current_session.cycle_count > 0 and 
                             self._current_session.total_computation_time / self._current_session.cycle_count or 0,
      peak_memory_usage_kb = self._current_session.peak_memory_usage,
      min_stability_margin_mm = self._current_session.min_stability_margin ~= math.huge and 
                                self._current_session.min_stability_margin or 0,
      average_energy_cost = self._current_session.average_energy_cost,
      alert_count = #self._current_session.alerts
    },
    timing = self:_get_timing_statistics(),
    memory = self:_get_memory_statistics(),
    stability = self:_get_stability_statistics(),
    energy = self:_get_energy_statistics()
  }
  
  return stats
end

--- Get recent performance alerts
--
-- @param count optional number of recent alerts to return
-- @return array of alert messages
function PerformanceMonitor:get_alerts(count)
  count = count or #self._current_session.alerts
  
  local alerts = {}
  local start_index = math.max(1, #self._current_session.alerts - count + 1)
  
  for i = start_index, #self._current_session.alerts do
    table.insert(alerts, self._current_session.alerts[i])
  end
  
  return alerts
end

--- Clear all alerts
function PerformanceMonitor:clear_alerts()
  self._current_session.alerts = {}
end

--- Get profiling data if enabled
--
-- @return profiling data or nil if profiling disabled
function PerformanceMonitor:get_profile_data()
  if not self._config.enable_profiling then
    return nil
  end
  
  return self._profile_data
end

--- Export performance data for analysis
--
-- @param format export format ("json", "csv", "lua")
-- @return formatted performance data
function PerformanceMonitor:export_data(format)
  format = format or "lua"
  
  local data = {
    config = self._config,
    session = self._current_session,
    statistics = self:get_statistics(),
    timing_samples = self._timing_samples,
    memory_samples = self._memory_samples,
    stability_samples = self._stability_samples,
    energy_samples = self._energy_samples
  }
  
  if format == "json" then
    -- Would need JSON library for actual JSON export
    return "JSON export not implemented"
  elseif format == "csv" then
    return self:_export_csv(data)
  else
    return data  -- Return raw Lua table
  end
end

--- Internal helper functions

function PerformanceMonitor:_get_current_time()
  -- Use high-resolution timer if available, otherwise fall back to os.clock
  if _G.millis then
    return _G.millis() / 1000.0  -- Convert ms to seconds
  else
    return os.clock()
  end
end

function PerformanceMonitor:_get_memory_usage()
  -- Force garbage collection to get accurate memory reading
  local current_time = self:_get_current_time()
  if current_time - self._last_gc_time > 1.0 then  -- GC at most once per second
    collectgarbage("collect")
    self._last_gc_time = current_time
  end
  
  return collectgarbage("count")  -- Returns memory usage in KB
end

function PerformanceMonitor:_add_timing_sample(operation_name, elapsed_ms)
  if not self._timing_samples[operation_name] then
    self._timing_samples[operation_name] = {}
  end
  
  local samples = self._timing_samples[operation_name]
  table.insert(samples, elapsed_ms)
  
  -- Keep only recent samples
  if #samples > self._config.sample_window_size then
    table.remove(samples, 1)
  end
end

function PerformanceMonitor:_add_memory_sample(memory_kb)
  table.insert(self._memory_samples, {
    timestamp = self:_get_current_time(),
    memory_kb = memory_kb
  })
  
  if #self._memory_samples > self._config.sample_window_size then
    table.remove(self._memory_samples, 1)
  end
end

function PerformanceMonitor:_add_stability_sample(stability_margin)
  table.insert(self._stability_samples, {
    timestamp = self:_get_current_time(),
    stability_margin = stability_margin
  })
  
  if #self._stability_samples > self._config.sample_window_size then
    table.remove(self._stability_samples, 1)
  end
end

function PerformanceMonitor:_add_energy_sample(energy_cost)
  table.insert(self._energy_samples, {
    timestamp = self:_get_current_time(),
    energy_cost = energy_cost
  })
  
  if #self._energy_samples > self._config.sample_window_size then
    table.remove(self._energy_samples, 1)
  end
end

function PerformanceMonitor:_add_alert(category, message)
  table.insert(self._current_session.alerts, {
    timestamp = self:_get_current_time(),
    category = category,
    message = message
  })
end

function PerformanceMonitor:_get_timing_statistics()
  local stats = {}
  
  for operation_name, samples in pairs(self._timing_samples) do
    if #samples > 0 then
      local sum = 0
      local min_time = math.huge
      local max_time = -math.huge
      
      for _, time in ipairs(samples) do
        sum = sum + time
        min_time = math.min(min_time, time)
        max_time = math.max(max_time, time)
      end
      
      stats[operation_name] = {
        sample_count = #samples,
        average_ms = sum / #samples,
        min_ms = min_time,
        max_ms = max_time,
        total_ms = sum
      }
    end
  end
  
  return stats
end

function PerformanceMonitor:_get_memory_statistics()
  if #self._memory_samples == 0 then
    return {}
  end
  
  local sum = 0
  local min_memory = math.huge
  local max_memory = -math.huge
  
  for _, sample in ipairs(self._memory_samples) do
    sum = sum + sample.memory_kb
    min_memory = math.min(min_memory, sample.memory_kb)
    max_memory = math.max(max_memory, sample.memory_kb)
  end
  
  return {
    sample_count = #self._memory_samples,
    average_kb = sum / #self._memory_samples,
    min_kb = min_memory,
    max_kb = max_memory,
    current_kb = self._memory_samples[#self._memory_samples].memory_kb
  }
end

function PerformanceMonitor:_get_stability_statistics()
  if #self._stability_samples == 0 then
    return {}
  end
  
  local sum = 0
  local min_margin = math.huge
  local max_margin = -math.huge
  
  for _, sample in ipairs(self._stability_samples) do
    sum = sum + sample.stability_margin
    min_margin = math.min(min_margin, sample.stability_margin)
    max_margin = math.max(max_margin, sample.stability_margin)
  end
  
  return {
    sample_count = #self._stability_samples,
    average_margin_mm = sum / #self._stability_samples,
    min_margin_mm = min_margin,
    max_margin_mm = max_margin,
    current_margin_mm = self._stability_samples[#self._stability_samples].stability_margin
  }
end

function PerformanceMonitor:_get_energy_statistics()
  if #self._energy_samples == 0 then
    return {}
  end
  
  local sum = 0
  local min_cost = math.huge
  local max_cost = -math.huge
  
  for _, sample in ipairs(self._energy_samples) do
    sum = sum + sample.energy_cost
    min_cost = math.min(min_cost, sample.energy_cost)
    max_cost = math.max(max_cost, sample.energy_cost)
  end
  
  return {
    sample_count = #self._energy_samples,
    average_cost = sum / #self._energy_samples,
    min_cost = min_cost,
    max_cost = max_cost,
    current_cost = self._energy_samples[#self._energy_samples].energy_cost
  }
end

function PerformanceMonitor:_record_profile_data(cycle_data)
  -- Record detailed profiling information
  local profile_entry = {
    timestamp = self:_get_current_time(),
    cycle_count = self._current_session.cycle_count,
    gait_pattern = cycle_data.gait_pattern,
    leg_count = cycle_data.leg_count,
    computation_breakdown = cycle_data.computation_breakdown or {},
    memory_snapshot = self:_get_memory_usage()
  }
  
  table.insert(self._profile_data, profile_entry)
  
  -- Keep profile data manageable
  if #self._profile_data > 1000 then
    table.remove(self._profile_data, 1)
  end
end

function PerformanceMonitor:_export_csv(data)
  local csv_lines = {}
  
  -- CSV header
  table.insert(csv_lines, "timestamp,operation,value,unit,category")
  
  -- Export timing data
  for operation_name, samples in pairs(self._timing_samples) do
    for _, time_ms in ipairs(samples) do
      table.insert(csv_lines, string.format("%.3f,%s,%.3f,ms,timing", 
                   self:_get_current_time(), operation_name, time_ms))
    end
  end
  
  -- Export memory data
  for _, sample in ipairs(self._memory_samples) do
    table.insert(csv_lines, string.format("%.3f,memory,%.1f,kb,memory", 
                 sample.timestamp, sample.memory_kb))
  end
  
  return table.concat(csv_lines, "\n")
end

return PerformanceMonitor