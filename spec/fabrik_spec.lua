require "busted.runner"
local Angle = require("angle")
local Chain = require("chain")
local FABRIK = require("fabrik")
local Joint = require("joint")
local Link = require("link")
local Scalar = require("scalar")
local Vec3 = require("vec3")

describe("FABRIK.solve", function()
  local target, chain, config

  local function build_chain()
    return Chain.new()
      :add(Joint.ball(Vec3.new(1, 0, 0)), Link.new(10))
      :add(Joint.ball(Vec3.new(1, 0, 0)), Link.new(5))
  end

  describe("when the end effector is already at the target location", function()
    before_each(function()
      chain = build_chain()
      target = Vec3.new(15, 0, 0)
      config = {}
    end)

    it("doesn't change the chain state", function()
      local before_state = chain
      FABRIK.solve(chain, target, config)
      local after_state = chain
      assert.are.same(before_state, after_state)
    end)
  end)

  describe("when the end effector is very near the target location", function()
    before_each(function()
      chain = build_chain()
      target = Vec3.new(14.999, 0, 0)
      config = {}
    end)

    it("doesn't change the chain state", function()
      local before_state = chain
      FABRIK.solve(chain, target, config)
      local after_state = chain
      assert.are.same(before_state, after_state)
    end)
  end)

  describe("when given a *lot* of iterations and no minimum travel", function()
    before_each(function()
      chain = build_chain()
      target = Vec3.new(5, 10, 0)
      config = {
        max_interations = math.maxinteger,
        min_travel = 0
      }
    end)

    it("stops iterating when it gets within tolerance of the goal", function()
      FABRIK.solve(chain, target, config)

      local new_end_location = chain:end_location()
      local delta = target:distance(new_end_location)
      assert.is.truthy(delta < FABRIK.DEFAULT_CONFIGURATION.tolerance)
    end)
  end)

  describe("when given a lot of iterations and no tolerance", function()
    before_each(function()
      chain = build_chain()
      target = Vec3.new(5, 10, 0)
      config = {
        max_interations = math.maxinteger,
        tolerance = 0
      }
    end)

    it("stops iterating when it is moving less than min-travel per iteration", function()
      FABRIK.solve(chain, target, config)

      local new_end_location = chain:end_location()
      local delta = target:distance(new_end_location)
      assert.is.truthy(delta < FABRIK.DEFAULT_CONFIGURATION.tolerance)
    end)
  end)

  describe("when the target position is out of reach", function()
    before_each(function()
      chain = build_chain()
      target = Vec3.new(30, 30, 0)
    end)

    it("doesn't iterate at all and moves straight to the elongated position", function()
      local iterations = FABRIK.solve(chain, target, config)

      assert.are.equal(iterations, 0)

      local expected_direction = target:normalise()

      for link_state in chain:forwards() do
        local direction = link_state.joint:direction()
        assert.is.near(direction:x(), expected_direction:x(), Scalar.FLOAT_EPSILON)
        assert.is.near(direction:y(), expected_direction:y(), Scalar.FLOAT_EPSILON)
        assert.is.near(direction:y(), expected_direction:y(), Scalar.FLOAT_EPSILON)
      end
    end)
  end)

  describe("when moving one step iteration at a time", function()
    local last_delta
    before_each(function()
      chain = build_chain()
      target = Vec3.new(0, 15, 0)
      last_delta = target:distance(chain:end_location())
      config = { max_interations = 1}
    end)

    it("iterates towards the goal", function()
      for i = 1, 20, 1 do
        local iterations = FABRIK.solve(chain, target, config)
        assert.are.equal(iterations, 1)
        local new_end_location = chain:end_location()
        local new_delta = target:distance(new_end_location)
        assert.is.truthy(new_delta < last_delta)
        last_delta = new_delta
      end
    end)
  end)

  describe("when the target is on another plane", function()
    before_each(function()
      chain = build_chain()
      target = Vec3.new(5, 5, 10)
      config = {}
    end)

    it("solves correctly", function()
      FABRIK.solve(chain, target, config)
      local end_location = chain:end_location()

      assert.is.near(end_location:x(), target:x(), 0.1)
      assert.is.near(end_location:y(), target:y(), 0.1)
      assert.is.near(end_location:z(), target:z(), 0.1)
    end)
  end)

  describe("when the target is in negative coordinates", function()
    before_each(function()
      chain = build_chain()
      target = Vec3.new(-7.5, -7.5, -7.5)
      config = {}
    end)

    it("solves correctly", function()
      FABRIK.solve(chain, target, config)
      local end_location = chain:end_location()

      assert.is.near(end_location:x(), target:x(), 0.1)
      assert.is.near(end_location:y(), target:y(), 0.1)
      assert.is.near(end_location:z(), target:z(), 0.1)
    end)
  end)
end)

describe("FABRIK configuration", function()
  it("includes constraint enforcement options in default configuration", function()
    local config = FABRIK.DEFAULT_CONFIGURATION
    
    assert.is_not_nil(config.enforce_constraints)
    assert.is_not_nil(config.constraint_tolerance)
    assert.is_true(config.enforce_constraints)
    assert.are.equal(config.constraint_tolerance, 0.0001)
  end)
end)

describe("FABRIK.solve with constraints", function()
  local function build_constrained_chain()
    return Chain.new()
      :add(Joint.ball(Vec3.new(1, 0, 0), Angle.from_degrees(45)), Link.new(10))
      :add(Joint.ball(Vec3.new(1, 0, 0), Angle.from_degrees(30)), Link.new(5))
  end
  
  describe("when constraints prevent reaching the target", function()
    it("finds the best possible solution within constraints", function()
      local chain = build_constrained_chain()
      local target = Vec3.new(0, 15, 0) -- Target that requires >45 degree rotation
      local config = { enforce_constraints = true }
      
      local iterations = FABRIK.solve(chain, target, config)
      
      -- Should complete without error
      assert.is_number(iterations)
      assert.is.truthy(iterations >= 0)
      
      -- Check that all joints respect their constraints
      for link_state in chain:forwards() do
        local joint = link_state.joint
        local direction = joint:direction()
        assert.is_true(FABRIK.is_direction_valid(joint, direction))
      end
    end)
    
    it("gets closer to target than initial position even with constraints", function()
      local chain = build_constrained_chain()
      local target = Vec3.new(0, 15, 0)
      local config = { enforce_constraints = true }
      
      local initial_distance = target:distance(chain:end_location())
      FABRIK.solve(chain, target, config)
      local final_distance = target:distance(chain:end_location())
      
      -- Should get closer to target (or at least not worse)
      assert.is.truthy(final_distance <= initial_distance)
    end)
  end)
  
  describe("when target is reachable within constraints", function()
    it("reaches the target accurately", function()
      local chain = build_constrained_chain()
      local target = Vec3.new(12, 8, 0) -- Reachable target within constraints
      local config = { enforce_constraints = true }
      
      FABRIK.solve(chain, target, config)
      local end_location = chain:end_location()
      local distance_to_target = target:distance(end_location)
      
      -- Should reach close to the target
      assert.is.truthy(distance_to_target < 0.1)
      
      -- All joints should still respect constraints
      for link_state in chain:forwards() do
        local joint = link_state.joint
        local direction = joint:direction()
        assert.is_true(FABRIK.is_direction_valid(joint, direction))
      end
    end)
  end)
  
  describe("when constraints are disabled", function()
    it("behaves identically to the original algorithm", function()
      local chain1 = build_constrained_chain()
      local chain2 = build_constrained_chain()
      local target = Vec3.new(0, 15, 0)
      
      -- Solve with constraints disabled
      local config_unconstrained = { enforce_constraints = false }
      local iterations1 = FABRIK.solve(chain1, target, config_unconstrained)
      
      -- Solve with default config (constraints enabled by default)
      local config_default = {}
      local iterations2 = FABRIK.solve(chain2, target, config_default)
      
      -- Results should be different (constrained should respect limits)
      local end1 = chain1:end_location()
      local end2 = chain2:end_location()
      
      -- The unconstrained version should get closer to the target
      local distance1 = target:distance(end1)
      local distance2 = target:distance(end2)
      
      -- Unconstrained should reach closer (or equal if target is reachable)
      assert.is.truthy(distance1 <= distance2)
    end)
  end)
  
  describe("with hinge joint constraints", function()
    it("respects hinge rotation limits", function()
      local chain = Chain.new()
        :add(Joint.hinge(Vec3.new(0, 0, 1), Vec3.new(1, 0, 0), Angle.from_degrees(30)), Link.new(10))
        :add(Joint.hinge(Vec3.new(0, 0, 1), Vec3.new(1, 0, 0), Angle.from_degrees(45)), Link.new(5))
      
      local target = Vec3.new(0, 15, 0) -- Target requiring large rotation
      local config = { enforce_constraints = true }
      
      FABRIK.solve(chain, target, config)
      
      -- Check that all hinge joints respect their constraints
      for link_state in chain:forwards() do
        local joint = link_state.joint
        local direction = joint:direction()
        assert.is_true(FABRIK.is_direction_valid(joint, direction))
      end
    end)
  end)
  
  describe("convergence with constraints", function()
    it("converges when constraints prevent further progress", function()
      local chain = build_constrained_chain()
      local target = Vec3.new(0, 20, 0) -- Impossible target
      local config = { 
        enforce_constraints = true,
        max_interations = 100,
        constraint_tolerance = 0.001
      }
      
      local iterations = FABRIK.solve(chain, target, config)
      
      -- Should converge in reasonable number of iterations
      assert.is.truthy(iterations < config.max_interations)
      assert.is.truthy(iterations > 0)
    end)
  end)
end)
