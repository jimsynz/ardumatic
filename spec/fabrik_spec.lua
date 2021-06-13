require "busted.runner"
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
      :add(Joint.ball(Vec3.new(1, 0, 0)))
      :add(Link.new(10))
      :add(Joint.ball(Vec3.new(1, 0, 0)))
      :add(Link.new(5))
  end

  describe("when the end effector is already at the target location", function()
    before_each(function()
      chain = build_chain()
      target = Vec3.new(15, 0, 0)
      config = {}
    end)

    it("doesn't change the chain state", function()
      local before_state = chain:chain_state()
      FABRIK.solve(chain, target, config)
      local after_state = chain:chain_state()
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
      local before_state = chain:chain_state()
      FABRIK.solve(chain, target, config)
      local after_state = chain:chain_state()
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

      local expected_direction = target:normalize()

      for joint, _ in chain:forward_pairs() do
        local direction = joint:direction()
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
