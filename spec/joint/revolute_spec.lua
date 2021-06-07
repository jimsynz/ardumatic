require "busted.runner"
local Angle = require("angle")
local RevoluteJoint = require("joint.revolute")
local RotationLimit = require("limit.rotation")
local Object = require("object")

describe("RevoluteJoint.new", function()
  it("creates a new RevoluteJoint instance", function()
    local rotation_limit = RotationLimit.new(Angle.zero(), Angle.zero())
    local joint = RevoluteJoint.new(rotation_limit)
    Object.assert_type(joint, RevoluteJoint)
  end)
end)

describe("RevoluteJoint:dof", function()
  it("is 1", function()
    local rotation_limit = RotationLimit.new(Angle.zero(), Angle.zero())
    local joint = RevoluteJoint.new(rotation_limit)
    assert.are.equal(joint.dof, 1)
  end)
end)