require "busted.runner"
local Chain = require("chain")
local Joint = require("joint")
local Limb = require("body.limb")
local Link = require("link")
local Vec3 = require("vec3")
local object = require "object"

describe("Limb.new", function()
  local chain, limb, offset

  before_each(function()
    offset = Vec3.new(3, 3, 0)
    chain = Chain.new()
      :add(Joint.ball(Vec3.new(1, 0, 0)))
      :add(Link.new(10))
    limb = Limb.new(offset, chain)
  end)

  it("returns a Limb instance", function()
    object.assert_type(limb, Limb)
  end)
end)

describe("Limb:end_location", function()
  local chain, limb, offset

  before_each(function()
    offset = Vec3.new(3, 3, 0)
    chain = Chain.new()
      :add(Joint.ball(Vec3.new(1, 0, 0)))
      :add(Link.new(10))
    limb = Limb.new(offset, chain)
  end)

  it("correctly calculates the end location", function()
    local end_location = limb:end_location()

    assert.are.equal(end_location:x(), 13)
    assert.are.equal(end_location:y(), 3)
    assert.are.equal(end_location:z(), 0)
  end)
end)
