require "busted.runner"
local Body = require("body")
local Chain = require("chain")
local Frame = require("frame")
local Joint = require("joint")
local Link = require("link")
local Object = require("object")
local Vec3 = require("vec3")
local chain = require "src.chain"

describe("Body.new", function()
  local body

  local rotation

  before_each(function()
    rotation = Vec3.new(1, 0, 0)
  end)

  describe("when created without an origin", function()
    it("raises an exception", function()
      assert.has_errors(function()
        Body.new()
      end)
    end)
  end)

  describe("when created with an origin", function()
    local origin
    before_each(function()
      origin = Frame.new(rotation, Vec3.new(1, 2, 3))
      body = Body.new(origin)
    end)

    it("sets the origin", function()
      assert.are.equal(body:origin(), origin)
    end)
  end)
end)

describe("Body:attach_chain", function()
  it("attaches the chain to the body", function()
    local rotation = Vec3.new(1, 0, 0)
    local origin = Frame.new(rotation, Vec3.zero())
    local body = Body.new(origin)

    local chain = Chain.new()
      :add(Joint.ball(Vec3.new(1, 0, 0)), Link.new(10))
      :add(Joint.ball(Vec3.new(1, 0, 0)), Link.new(10))


    assert.is.equal(body:chain_count(), 0)

    body:attach_chain(chain)

    assert.is.equal(body:chain_count(), 1)
  end)
end)

describe("Body:end_locations", function()
  it("returns the end locations of the limbs", function()
    local origin = Frame.new(Vec3.new(0, 0, 1))
    local body = Body.new(origin)

    local left_leg = Chain.new(Vec3.new(-5, 0, 0))
      :add(Joint.hinge(Vec3.new(0, 0, 1), Vec3.new(-1, 0, 0)), Link.new(10))

    local right_leg = Chain.new(Vec3.new(5, 0, 0))
      :add(Joint.hinge(Vec3.new(0, 0, 1), Vec3.new(1, 0, 0)), Link.new(10))

    body:attach_chain(left_leg)
    body:attach_chain(right_leg)

    local end_locations = body:end_locations()
    local left_end_location = end_locations[1]
    local right_end_location = end_locations[2]

    assert.are.equal(left_end_location:x(), -15)
    assert.are.equal(left_end_location:y(), 0)
    assert.are.equal(left_end_location:z(), 0)

    assert.are.equal(right_end_location:x(), 15)
    assert.are.equal(right_end_location:y(), 0)
    assert.are.equal(right_end_location:z(), 0)
  end)
end)
