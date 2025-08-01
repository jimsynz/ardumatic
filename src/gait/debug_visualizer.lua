local Object = require("object")
local Scalar = require("scalar")
local Vec3 = require("vec3")

--- Debug Visualizer
--
-- Provides debug output and visualization capabilities for gait generation,
-- including trajectory plots, stability analysis, and performance metrics.
local DebugVisualizer = Object.new("DebugVisualizer")

--- Output formats supported
local OUTPUT_FORMATS = {
  console = "Human-readable console output",
  json = "JSON format for external tools",
  csv = "CSV format for data analysis",
  gnuplot = "Gnuplot script for trajectory visualization",
  svg = "SVG format for web visualization"
}

--- Default visualization configuration
local DEFAULT_CONFIG = {
  output_format = "console",
  enable_trajectory_plot = true,
  enable_stability_plot = true,
  enable_timing_plot = true,
  enable_energy_plot = true,
  plot_resolution = 100,        -- Number of points in plots
  trajectory_history_size = 200, -- Number of trajectory points to keep
  console_width = 80,           -- Console output width
  precision = 2,                -- Decimal places for numeric output
  color_output = true,          -- Enable colored console output
  export_directory = "./debug_output"
}

function DebugVisualizer.new(config)
  if config ~= nil then
    assert(type(config) == "table", "config must be a table")
  end
  
  local merged_config = {}
  for k, v in pairs(DEFAULT_CONFIG) do
    merged_config[k] = config and config[k] or v
  end
  
  return Object.instance({
    _config = merged_config,
    _trajectory_history = {},
    _stability_history = {},
    _timing_history = {},
    _energy_history = {},
    _current_frame = 0,
    _debug_data = {},
    _color_codes = {
      reset = "\27[0m",
      red = "\27[31m",
      green = "\27[32m",
      yellow = "\27[33m",
      blue = "\27[34m",
      magenta = "\27[35m",
      cyan = "\27[36m",
      white = "\27[37m"
    }
  }, DebugVisualizer)
end

--- Record gait state for visualization
--
-- @param gait_data table containing current gait state information
function DebugVisualizer:record_gait_state(gait_data)
  assert(type(gait_data) == "table", "gait_data must be a table")
  
  self._current_frame = self._current_frame + 1
  
  -- Record trajectory data
  if self._config.enable_trajectory_plot and gait_data.leg_positions then
    self:_record_trajectory_data(gait_data.leg_positions, gait_data.leg_targets)
  end
  
  -- Record stability data
  if self._config.enable_stability_plot and gait_data.stability_margin then
    self:_record_stability_data(gait_data.stability_margin, gait_data.center_of_mass)
  end
  
  -- Record timing data
  if self._config.enable_timing_plot and gait_data.computation_time then
    self:_record_timing_data(gait_data.computation_time)
  end
  
  -- Record energy data
  if self._config.enable_energy_plot and gait_data.energy_cost then
    self:_record_energy_data(gait_data.energy_cost)
  end
  
  -- Store complete debug data
  self._debug_data[self._current_frame] = {
    timestamp = gait_data.timestamp or self._current_frame,
    gait_pattern = gait_data.gait_pattern,
    global_phase = gait_data.global_phase,
    leg_phases = gait_data.leg_phases,
    leg_positions = gait_data.leg_positions,
    leg_targets = gait_data.leg_targets,
    stability_margin = gait_data.stability_margin,
    center_of_mass = gait_data.center_of_mass,
    computation_time = gait_data.computation_time,
    energy_cost = gait_data.energy_cost,
    terrain_data = gait_data.terrain_data
  }
end

--- Generate debug output in specified format
--
-- @param format output format ("console", "json", "csv", etc.)
-- @return formatted debug output
function DebugVisualizer:generate_output(format)
  format = format or self._config.output_format
  
  if format == "console" then
    return self:_generate_console_output()
  elseif format == "json" then
    return self:_generate_json_output()
  elseif format == "csv" then
    return self:_generate_csv_output()
  elseif format == "gnuplot" then
    return self:_generate_gnuplot_output()
  elseif format == "svg" then
    return self:_generate_svg_output()
  else
    error("Unknown output format: " .. format)
  end
end

--- Generate trajectory visualization
--
-- @param leg_name optional specific leg to visualize
-- @return trajectory visualization data
function DebugVisualizer:visualize_trajectory(leg_name)
  if not self._config.enable_trajectory_plot then
    return "Trajectory plotting disabled"
  end
  
  local output = {}
  table.insert(output, self:_color_text("=== Leg Trajectory Visualization ===", "cyan"))
  
  if leg_name then
    -- Visualize specific leg
    local trajectory = self:_get_leg_trajectory(leg_name)
    if trajectory then
      table.insert(output, self:_format_leg_trajectory(leg_name, trajectory))
    else
      table.insert(output, "No trajectory data for leg: " .. leg_name)
    end
  else
    -- Visualize all legs
    for name, trajectory in pairs(self._trajectory_history) do
      table.insert(output, self:_format_leg_trajectory(name, trajectory))
      table.insert(output, "")
    end
  end
  
  return table.concat(output, "\n")
end

--- Generate stability analysis visualization
--
-- @return stability analysis output
function DebugVisualizer:visualize_stability()
  if not self._config.enable_stability_plot then
    return "Stability plotting disabled"
  end
  
  local output = {}
  table.insert(output, self:_color_text("=== Stability Analysis ===", "cyan"))
  
  if #self._stability_history > 0 then
    local latest = self._stability_history[#self._stability_history]
    table.insert(output, string.format("Current Stability Margin: %s%.2fmm%s", 
                 self:_get_stability_color(latest.margin), latest.margin, self._color_codes.reset))
    
    -- Generate stability trend
    table.insert(output, "")
    table.insert(output, "Stability Trend (last 20 samples):")
    table.insert(output, self:_generate_stability_chart())
  else
    table.insert(output, "No stability data recorded")
  end
  
  return table.concat(output, "\n")
end

--- Generate performance analysis visualization
--
-- @return performance analysis output
function DebugVisualizer:visualize_performance()
  local output = {}
  table.insert(output, self:_color_text("=== Performance Analysis ===", "cyan"))
  
  -- Timing analysis
  if #self._timing_history > 0 then
    local avg_time = self:_calculate_average_timing()
    local max_time = self:_calculate_max_timing()
    
    table.insert(output, string.format("Average Computation Time: %.3fms", avg_time))
    table.insert(output, string.format("Peak Computation Time: %.3fms", max_time))
    
    local performance_status = avg_time < 1.0 and "GOOD" or "NEEDS_OPTIMIZATION"
    local color = avg_time < 1.0 and "green" or "red"
    table.insert(output, string.format("Performance Status: %s%s%s", 
                 self._color_codes[color], performance_status, self._color_codes.reset))
  end
  
  -- Energy analysis
  if #self._energy_history > 0 then
    local avg_energy = self:_calculate_average_energy()
    table.insert(output, string.format("Average Energy Cost: %.2f", avg_energy))
  end
  
  return table.concat(output, "\n")
end

--- Export debug data to file
--
-- @param filename output filename
-- @param format output format
-- @return success status and message
function DebugVisualizer:export_to_file(filename, format)
  assert(type(filename) == "string", "filename must be a string")
  format = format or self._config.output_format
  
  local output_data = self:generate_output(format)
  
  -- Create output directory if it doesn't exist
  local directory = self._config.export_directory
  os.execute("mkdir -p " .. directory)
  
  local full_path = directory .. "/" .. filename
  local file = io.open(full_path, "w")
  
  if not file then
    return false, "Failed to open file for writing: " .. full_path
  end
  
  file:write(output_data)
  file:close()
  
  return true, "Debug data exported to: " .. full_path
end

--- Clear all recorded debug data
function DebugVisualizer:clear_data()
  self._trajectory_history = {}
  self._stability_history = {}
  self._timing_history = {}
  self._energy_history = {}
  self._debug_data = {}
  self._current_frame = 0
end

--- Internal helper functions

function DebugVisualizer:_record_trajectory_data(leg_positions, leg_targets)
  for leg_name, position in pairs(leg_positions) do
    if not self._trajectory_history[leg_name] then
      self._trajectory_history[leg_name] = {}
    end
    
    local trajectory = self._trajectory_history[leg_name]
    table.insert(trajectory, {
      frame = self._current_frame,
      position = position,
      target = leg_targets and leg_targets[leg_name] or position
    })
    
    -- Keep history size manageable
    if #trajectory > self._config.trajectory_history_size then
      table.remove(trajectory, 1)
    end
  end
end

function DebugVisualizer:_record_stability_data(stability_margin, center_of_mass)
  table.insert(self._stability_history, {
    frame = self._current_frame,
    margin = stability_margin,
    center_of_mass = center_of_mass
  })
  
  if #self._stability_history > self._config.trajectory_history_size then
    table.remove(self._stability_history, 1)
  end
end

function DebugVisualizer:_record_timing_data(computation_time)
  table.insert(self._timing_history, {
    frame = self._current_frame,
    time_ms = computation_time
  })
  
  if #self._timing_history > self._config.trajectory_history_size then
    table.remove(self._timing_history, 1)
  end
end

function DebugVisualizer:_record_energy_data(energy_cost)
  table.insert(self._energy_history, {
    frame = self._current_frame,
    cost = energy_cost
  })
  
  if #self._energy_history > self._config.trajectory_history_size then
    table.remove(self._energy_history, 1)
  end
end

function DebugVisualizer:_generate_console_output()
  local output = {}
  
  table.insert(output, self:_color_text("=== Gait Generator Debug Output ===", "cyan"))
  table.insert(output, string.format("Frame: %d", self._current_frame))
  table.insert(output, "")
  
  -- Current state summary
  if self._debug_data[self._current_frame] then
    local current = self._debug_data[self._current_frame]
    table.insert(output, self:_color_text("Current State:", "yellow"))
    table.insert(output, string.format("  Gait Pattern: %s", current.gait_pattern or "unknown"))
    table.insert(output, string.format("  Global Phase: %.3f", current.global_phase or 0))
    
    if current.stability_margin then
      local color = self:_get_stability_color(current.stability_margin)
      table.insert(output, string.format("  Stability Margin: %s%.2fmm%s", 
                   color, current.stability_margin, self._color_codes.reset))
    end
    
    if current.computation_time then
      local color = current.computation_time < 1.0 and "green" or "red"
      table.insert(output, string.format("  Computation Time: %s%.3fms%s", 
                   self._color_codes[color], current.computation_time, self._color_codes.reset))
    end
  end
  
  table.insert(output, "")
  
  -- Add trajectory visualization
  if self._config.enable_trajectory_plot then
    table.insert(output, self:visualize_trajectory())
    table.insert(output, "")
  end
  
  -- Add stability visualization
  if self._config.enable_stability_plot then
    table.insert(output, self:visualize_stability())
    table.insert(output, "")
  end
  
  -- Add performance visualization
  table.insert(output, self:visualize_performance())
  
  return table.concat(output, "\n")
end

function DebugVisualizer:_generate_json_output()
  -- Simple JSON-like output (would need proper JSON library for full JSON)
  local json_data = {
    frame = self._current_frame,
    config = self._config,
    trajectory_history = self._trajectory_history,
    stability_history = self._stability_history,
    timing_history = self._timing_history,
    energy_history = self._energy_history,
    debug_data = self._debug_data
  }
  
  return "JSON output not fully implemented - use Lua table format"
end

function DebugVisualizer:_generate_csv_output()
  local csv_lines = {}
  
  -- CSV header
  table.insert(csv_lines, "frame,timestamp,gait_pattern,global_phase,stability_margin,computation_time,energy_cost")
  
  -- Data rows
  for frame, data in pairs(self._debug_data) do
    local line = string.format("%d,%.3f,%s,%.3f,%.2f,%.3f,%.2f",
                 frame,
                 data.timestamp or 0,
                 data.gait_pattern or "",
                 data.global_phase or 0,
                 data.stability_margin or 0,
                 data.computation_time or 0,
                 data.energy_cost or 0)
    table.insert(csv_lines, line)
  end
  
  return table.concat(csv_lines, "\n")
end

function DebugVisualizer:_generate_gnuplot_output()
  local gnuplot_script = {}
  
  table.insert(gnuplot_script, "# Gnuplot script for gait visualization")
  table.insert(gnuplot_script, "set terminal png size 800,600")
  table.insert(gnuplot_script, "set output 'gait_analysis.png'")
  table.insert(gnuplot_script, "set multiplot layout 2,2")
  table.insert(gnuplot_script, "")
  
  -- Stability plot
  table.insert(gnuplot_script, "set title 'Stability Margin'")
  table.insert(gnuplot_script, "set ylabel 'Margin (mm)'")
  table.insert(gnuplot_script, "plot '-' with lines title 'Stability'")
  
  for _, data in ipairs(self._stability_history) do
    table.insert(gnuplot_script, string.format("%d %.2f", data.frame, data.margin))
  end
  table.insert(gnuplot_script, "e")
  table.insert(gnuplot_script, "")
  
  -- Timing plot
  table.insert(gnuplot_script, "set title 'Computation Time'")
  table.insert(gnuplot_script, "set ylabel 'Time (ms)'")
  table.insert(gnuplot_script, "plot '-' with lines title 'Timing'")
  
  for _, data in ipairs(self._timing_history) do
    table.insert(gnuplot_script, string.format("%d %.3f", data.frame, data.time_ms))
  end
  table.insert(gnuplot_script, "e")
  
  return table.concat(gnuplot_script, "\n")
end

function DebugVisualizer:_generate_svg_output()
  return "SVG output not implemented"
end

function DebugVisualizer:_color_text(text, color)
  if not self._config.color_output then
    return text
  end
  
  local color_code = self._color_codes[color] or ""
  return color_code .. text .. self._color_codes.reset
end

function DebugVisualizer:_get_stability_color(margin)
  if not self._config.color_output then
    return ""
  end
  
  if margin > 30 then
    return self._color_codes.green
  elseif margin > 15 then
    return self._color_codes.yellow
  else
    return self._color_codes.red
  end
end

function DebugVisualizer:_generate_stability_chart()
  local chart_width = 60
  local chart_height = 10
  
  if #self._stability_history < 2 then
    return "Insufficient data for chart"
  end
  
  -- Get recent samples
  local samples = {}
  local start_index = math.max(1, #self._stability_history - 19)
  for i = start_index, #self._stability_history do
    table.insert(samples, self._stability_history[i].margin)
  end
  
  -- Find min/max for scaling
  local min_margin = math.huge
  local max_margin = -math.huge
  for _, margin in ipairs(samples) do
    min_margin = math.min(min_margin, margin)
    max_margin = math.max(max_margin, margin)
  end
  
  -- Generate ASCII chart
  local chart_lines = {}
  for row = chart_height, 1, -1 do
    local line = ""
    local threshold = min_margin + (max_margin - min_margin) * (row - 1) / (chart_height - 1)
    
    for _, margin in ipairs(samples) do
      if margin >= threshold then
        line = line .. "*"
      else
        line = line .. " "
      end
    end
    
    chart_lines[chart_height - row + 1] = string.format("%6.1f |%s", threshold, line)
  end
  
  table.insert(chart_lines, string.format("%6s +%s", "", string.rep("-", #samples)))
  
  return table.concat(chart_lines, "\n")
end

function DebugVisualizer:_calculate_average_timing()
  if #self._timing_history == 0 then
    return 0
  end
  
  local sum = 0
  for _, data in ipairs(self._timing_history) do
    sum = sum + data.time_ms
  end
  
  return sum / #self._timing_history
end

function DebugVisualizer:_calculate_max_timing()
  local max_time = 0
  for _, data in ipairs(self._timing_history) do
    max_time = math.max(max_time, data.time_ms)
  end
  return max_time
end

function DebugVisualizer:_calculate_average_energy()
  if #self._energy_history == 0 then
    return 0
  end
  
  local sum = 0
  for _, data in ipairs(self._energy_history) do
    sum = sum + data.cost
  end
  
  return sum / #self._energy_history
end

function DebugVisualizer:_get_leg_trajectory(leg_name)
  return self._trajectory_history[leg_name]
end

function DebugVisualizer:_format_leg_trajectory(leg_name, trajectory)
  if not trajectory or #trajectory == 0 then
    return string.format("%s: No trajectory data", leg_name)
  end
  
  local latest = trajectory[#trajectory]
  local pos = latest.position
  local target = latest.target
  
  return string.format("%s: Pos(%.1f,%.1f,%.1f) -> Target(%.1f,%.1f,%.1f)",
                      leg_name,
                      pos:x(), pos:y(), pos:z(),
                      target:x(), target:y(), target:z())
end

return DebugVisualizer