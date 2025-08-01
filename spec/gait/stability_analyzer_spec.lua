local StabilityAnalyzer = require("gait.stability_analyzer")
local RobotBuilder = require("robot_builder")
local Vec3 = require("vec3")

describe("StabilityAnalyzer", function()
  local robot_config
  local stability_analyzer
  
  before_each(function()
    robot_config = RobotBuilder.hexapod(120, 40, 60, 80)
    stability_analyzer = StabilityAnalyzer.new(robot_config)
  end)
  
  describe("new", function()
    it("should create a stability analyzer with robot configuration", function()
      assert.is_not_nil(stability_analyzer)
      assert.equals(2000, stability_analyzer:get_config("body_mass"))
      assert.equals(100, stability_analyzer:get_config("leg_mass"))
    end)
    
    it("should accept custom configuration", function()
      local custom_config = {
        body_mass = 3000,
        safety_margin = 30
      }
      
      local custom_analyzer = StabilityAnalyzer.new(robot_config, custom_config)
      assert.equals(3000, custom_analyzer:get_config("body_mass"))
      assert.equals(30, custom_analyzer:get_config("safety_margin"))
    end)
  end)
  
  describe("calculate_centre_of_mass", function()
    it("should calculate CoM with body only", function()
      local leg_positions = {}
      local body_position = Vec3.new(10, 20, 30)
      
      local com = stability_analyzer:calculate_centre_of_mass(leg_positions, body_position)
      
      -- With no legs, CoM should be at body position
      assert.equals(body_position, com)
    end)
    
    it("should calculate CoM with legs", function()
      local leg_positions = {
        front_right = Vec3.new(100, 50, -100),
        front_left = Vec3.new(-100, 50, -100)
      }
      local body_position = Vec3.zero()
      
      local com = stability_analyzer:calculate_centre_of_mass(leg_positions, body_position)
      
      -- CoM should be influenced by leg positions
      assert.is_true(com:x() == 0)  -- Symmetric legs
      assert.is_true(com:y() > 0)   -- Legs are forward of body
      assert.is_true(com:z() < 0)   -- Legs are below body
    end)
    
    it("should handle missing leg positions", function()
      local leg_positions = {
        front_right = Vec3.new(100, 50, -100)
        -- Missing other legs
      }
      local body_position = Vec3.zero()
      
      -- Should not error with missing legs
      assert.has_no_error(function()
        stability_analyzer:calculate_centre_of_mass(leg_positions, body_position)
      end)
    end)
  end)
  
  describe("calculate_support_polygon", function()
    it("should return empty polygon with less than 3 stance legs", function()
      local leg_positions = {
        front_right = Vec3.new(100, 50, -100),
        front_left = Vec3.new(-100, 50, -100)
      }
      local stance_legs = {"front_right", "front_left"}
      
      local polygon = stability_analyzer:calculate_support_polygon(leg_positions, stance_legs)
      
      assert.equals(0, #polygon)
    end)
    
    it("should calculate polygon with 3 stance legs", function()
      local leg_positions = {
        front_right = Vec3.new(100, 50, -100),
        front_left = Vec3.new(-100, 50, -100),
        rear_right = Vec3.new(100, -50, -100)
      }
      local stance_legs = {"front_right", "front_left", "rear_right"}
      
      local polygon = stability_analyzer:calculate_support_polygon(leg_positions, stance_legs)
      
      assert.equals(3, #polygon)
      -- All points should be projected to z=0
      for _, point in ipairs(polygon) do
        assert.equals(0, point:z())
      end
    end)
    
    it("should calculate convex hull with more legs", function()
      local leg_positions = {
        front_right = Vec3.new(100, 50, -100),
        middle_right = Vec3.new(120, 0, -100),
        rear_right = Vec3.new(100, -50, -100),
        rear_left = Vec3.new(-100, -50, -100),
        middle_left = Vec3.new(-120, 0, -100),
        front_left = Vec3.new(-100, 50, -100)
      }
      local stance_legs = {"front_right", "middle_right", "rear_right", "rear_left", "middle_left", "front_left"}
      
      local polygon = stability_analyzer:calculate_support_polygon(leg_positions, stance_legs)
      
      -- Should form convex hull (likely 6 points for hexagon, but could be fewer)
      assert.is_true(#polygon >= 3)
      assert.is_true(#polygon <= 6)
    end)
  end)
  
  describe("is_statically_stable", function()
    it("should return false for empty support polygon", function()
      local com = Vec3.zero()
      local polygon = {}
      
      local is_stable = stability_analyzer:is_statically_stable(com, polygon)
      
      assert.is_false(is_stable)
    end)
    
    it("should return true when CoM is inside triangle", function()
      local com = Vec3.zero()  -- At origin
      local polygon = {
        Vec3.new(100, 0, 0),
        Vec3.new(-50, 87, 0),
        Vec3.new(-50, -87, 0)
      }
      
      local is_stable = stability_analyzer:is_statically_stable(com, polygon)
      
      assert.is_true(is_stable)
    end)
    
    it("should return false when CoM is outside triangle", function()
      local com = Vec3.new(200, 0, 0)  -- Far outside
      local polygon = {
        Vec3.new(100, 0, 0),
        Vec3.new(-50, 87, 0),
        Vec3.new(-50, -87, 0)
      }
      
      local is_stable = stability_analyzer:is_statically_stable(com, polygon)
      
      assert.is_false(is_stable)
    end)
  end)
  
  describe("calculate_stability_margin", function()
    it("should return negative infinity for empty polygon", function()
      local com = Vec3.zero()
      local polygon = {}
      
      local margin = stability_analyzer:calculate_stability_margin(com, polygon)
      
      assert.equals(-math.huge, margin)
    end)
    
    it("should return positive margin when inside polygon", function()
      local com = Vec3.zero()  -- At center
      local polygon = {
        Vec3.new(100, 0, 0),
        Vec3.new(0, 100, 0),
        Vec3.new(-100, 0, 0),
        Vec3.new(0, -100, 0)
      }
      
      local margin = stability_analyzer:calculate_stability_margin(com, polygon)
      
      assert.is_true(margin > 0)
      assert.is_true(margin <= 100)  -- Should be distance to nearest edge
    end)
    
    it("should return negative margin when outside polygon", function()
      local com = Vec3.new(200, 0, 0)  -- Outside
      local polygon = {
        Vec3.new(100, 0, 0),
        Vec3.new(0, 100, 0),
        Vec3.new(-100, 0, 0),
        Vec3.new(0, -100, 0)
      }
      
      local margin = stability_analyzer:calculate_stability_margin(com, polygon)
      
      assert.is_true(margin < 0)
    end)
  end)
  
  describe("validate_stability", function()
    it("should return false with insufficient stance legs", function()
      local leg_positions = {
        front_right = Vec3.new(100, 50, -100),
        front_left = Vec3.new(-100, 50, -100)
      }
      local stance_legs = {"front_right", "front_left"}  -- Only 2 legs
      
      local is_stable, margin, com = stability_analyzer:validate_stability(leg_positions, stance_legs)
      
      assert.is_false(is_stable)
      assert.equals(-math.huge, margin)
    end)
    
    it("should validate stability with sufficient stance legs", function()
      local leg_positions = {
        front_right = Vec3.new(100, 50, -100),
        front_left = Vec3.new(-100, 50, -100),
        rear_right = Vec3.new(100, -50, -100)
      }
      local stance_legs = {"front_right", "front_left", "rear_right"}
      local body_position = Vec3.new(0, 0, -50)
      
      local is_stable, margin, com = stability_analyzer:validate_stability(leg_positions, stance_legs, body_position)
      
      -- Should return valid results
      assert.is_boolean(is_stable)
      assert.is_number(margin)
      assert.is_not_nil(com)
      assert.is_function(com.x)  -- Check that it has Vec3 methods
    end)
  end)
  
  describe("calculate_max_safe_velocity", function()
    it("should return zero for negative stability margin", function()
      local max_velocity = stability_analyzer:calculate_max_safe_velocity(-10, 2.0)
      
      assert.equals(0, max_velocity)
    end)
    
    it("should return zero when margin equals safety margin", function()
      local safety_margin = stability_analyzer:get_config("safety_margin")
      local max_velocity = stability_analyzer:calculate_max_safe_velocity(safety_margin, 2.0)
      
      assert.equals(0, max_velocity)
    end)
    
    it("should return positive velocity for good stability", function()
      local safety_margin = stability_analyzer:get_config("safety_margin")
      local max_velocity = stability_analyzer:calculate_max_safe_velocity(safety_margin + 50, 2.0)
      
      assert.is_true(max_velocity > 0)
      assert.is_true(max_velocity <= 200)  -- Should respect upper limit
    end)
    
    it("should scale with cycle time", function()
      local safety_margin = stability_analyzer:get_config("safety_margin")
      local velocity_short = stability_analyzer:calculate_max_safe_velocity(safety_margin + 50, 1.0)
      local velocity_long = stability_analyzer:calculate_max_safe_velocity(safety_margin + 50, 2.0)
      
      -- Longer cycle time should allow higher velocity
      assert.is_true(velocity_long > velocity_short)
    end)
  end)
  
  describe("get_stability_recommendations", function()
    it("should recommend conservative parameters for low stability", function()
      local safety_margin = stability_analyzer:get_config("safety_margin")
      local recommendations = stability_analyzer:get_stability_recommendations(safety_margin - 10)
      
      assert.is_true(recommendations.step_height <= 25)
      assert.is_true(recommendations.cycle_time >= 2.5)
      assert.is_true(recommendations.duty_factor >= 0.8)
      assert.is_true(recommendations.max_velocity <= 75)
    end)
    
    it("should recommend normal parameters for adequate stability", function()
      local safety_margin = stability_analyzer:get_config("safety_margin")
      local recommendations = stability_analyzer:get_stability_recommendations(safety_margin + 5)
      
      assert.equals(30, recommendations.step_height)
      assert.equals(2.0, recommendations.cycle_time)
      assert.equals(0.75, recommendations.duty_factor)
      assert.equals(100, recommendations.max_velocity)
    end)
    
    it("should recommend aggressive parameters for high stability", function()
      local safety_margin = stability_analyzer:get_config("safety_margin")
      local recommendations = stability_analyzer:get_stability_recommendations(safety_margin * 3)
      
      assert.is_true(recommendations.step_height >= 35)
      assert.is_true(recommendations.cycle_time <= 2.0)
      assert.is_true(recommendations.duty_factor <= 0.7)
      assert.is_true(recommendations.max_velocity >= 125)
    end)
  end)
  
  describe("configuration management", function()
    it("should set and get configuration parameters", function()
      stability_analyzer:set_config("body_mass", 2500)
      assert.equals(2500, stability_analyzer:get_config("body_mass"))
      
      stability_analyzer:set_config("safety_margin", 25)
      assert.equals(25, stability_analyzer:get_config("safety_margin"))
    end)
    
    it("should reject unknown configuration parameters", function()
      assert.has_error(function()
        stability_analyzer:set_config("unknown_param", 123)
      end)
    end)
  end)
end)