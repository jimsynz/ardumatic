require "busted.runner"
local Angle = require("angle")
local CylindricalJoint = require("joint.cylindrical")
local Frame = require("frame")
local Joint = require("joint")
local Object = require("object")
local PrismaticJoint = require("joint.prismatic")
local RevoluteJoint = require("joint.revolute")
local RotationLimit = require("limit.rotation")
local TranslationLimit = require("limit.translation")

describe("Joint.cylindrical", function()
  it("creates a cylindrical joint", function()
    local frame = Frame.new()
    local rotation_limit = RotationLimit.new(Angle.zero(), Angle.zero())
    local translation_limit = TranslationLimit.new(0, 0)
    local joint = Joint.cylindrical(frame, rotation_limit, translation_limit)
    Object.assert_type(joint, Joint)
    Object.assert_type(joint._joint, CylindricalJoint)
  end)
end)

describe("Joint.prismatic", function()
  it("creates a prismatic joint", function()
    local frame = Frame.new()
    local translation_limit = TranslationLimit.new(0, 0)
    local joint = Joint.prismatic(frame, translation_limit)
    Object.assert_type(joint, Joint)
    Object.assert_type(joint._joint, PrismaticJoint)
  end)
end)

describe("Joint.revolute", function()
  it("creates a revolute joint", function()
    local frame = Frame.new()
    local rotation_limit = RotationLimit.new(Angle.zero(), Angle.zero())
    local joint = Joint.revolute(frame, rotation_limit)
    Object.assert_type(joint, Joint)
    Object.assert_type(joint._joint, RevoluteJoint)
  end)
end)

describe("Joint.dof", function()
  local joint

  describe("when passed a cylindrical joint", function()
    before_each(function()
      local frame = Frame.new()
      local rotation_limit = RotationLimit.new(Angle.zero(), Angle.zero())
      local translation_limit = TranslationLimit.new(0, 0)
      joint = Joint.cylindrical(frame, rotation_limit, translation_limit)
    end)

    it("is 2", function()
      assert.are.equal(joint:dof(), 2)
    end)
  end)

  describe("when passed a prismatic joint", function()
    before_each(function()
      local frame = Frame.new()
      local translation_limit = TranslationLimit.new(0, 0)
      joint = Joint.prismatic(frame, translation_limit)
    end)

    it("is 1", function()
      assert.are.equal(joint:dof(), 1)
    end)
  end)

  describe("when passed a revolute joint", function()
    before_each(function()
      local frame = Frame.new()
      local rotation_limit = RotationLimit.new(Angle.zero(), Angle.zero())
      joint = Joint.revolute(frame, rotation_limit)
    end)

    it("is 1", function()
      assert.are.equal(joint:dof(), 1)
    end)
  end)
end)
