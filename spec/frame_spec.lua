require "busted.runner"
local Frame = require("frame")
local Vec3 = require("vec3")

describe("Frame.new", function()
  describe("when passed a position and rotation", function()
    local position, rotation
    before_each(function()
      position = Vec3.new(1,2,3)
      rotation = Vec3.new(-3, -2, -1)
    end)

    it("creates a frame instance", function()
      local frame = Frame.new(position, rotation)
      assert.is.truthy(frame:type_of(Frame))
      assert.are.equal(frame.position, position)
      assert.are.equal(frame.rotation, rotation)
    end)
  end)

  describe("when initialised with no arguments", function()
    it("creates a frame instance with zero vectors", function()
      local frame = Frame.new(position, rotation)
      assert.is.truthy(frame:type_of(Frame))
      assert.are.equal(frame.position, Vec3.zero())
      assert.are.equal(frame.rotation, Vec3.zero())
    end)
  end)
end)
