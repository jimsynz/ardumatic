require "busted.runner"
local Angle = require("angle")
local Joint = require("joint")
local Object = require("object")
local Vec3 = require("vec3")

describe("Joint.ball", function()
  local joint

  describe("when not passed a constraint angle", function()
    before_each(function()
      joint = Joint.ball(Vec3.new(0, 0, 1))
    end)

    it("creates a new joint instance", function()
      Object.assert_type(joint, Joint)
    end)

    it("sets the joint type to ball", function()
      assert.is_true(joint:is_ball())
    end)

    it("sets the anticlockwise constraint to 0º", function()
      assert.are.equal(joint:anticlockwise_constraint(), Angle.zero())
    end)

    it("sets the clockwise constraint to 180º", function()
      assert.are.equal(joint:clockwise_constraint(), Angle.from_degrees(180))
    end)
  end)

  describe("when passed a constraint angle that is less than 0º", function()
    it("is an error", function()
      assert.has.errors(function()
        Joint.ball(Vec3.new(0, 0, 1), Angle.from_degrees(-30))
      end)
    end)
  end)

  describe("when passed a constraint angle that is greater than 1 80º", function()
    it("is an error", function()
      assert.has.errors(function()
        Joint.ball(Vec3.new(0, 0, 1), Angle.from_degrees(270))
      end)
    end)
  end)

  describe("when passed a valid constraint angle", function()
    local angle
    before_each(function()
      angle = Angle.from_degrees(30)
      joint = Joint.ball(Vec3.new(0, 0, 1), angle)
    end)

    it("creates a new joint instance", function()
      Object.assert_type(joint, Joint)
    end)

    it("sets the joint type to ball", function()
      assert.is_true(joint:is_ball())
    end)

    it("sets the anticlockwise constraint to 0º", function()
      assert.are.equal(joint:anticlockwise_constraint(), Angle.zero())
    end)

    it("sets the clockwise constraint the provided value", function()
      assert.are.equal(joint:clockwise_constraint(), angle)
    end)
  end)
end)

describe("Joint.hinge", function()
  local rotation_axis, reference_axis, clockwise_constraint, anticlockwise_constraint, joint

  before_each(function()
    rotation_axis = Vec3.new(0, 0, 1)
    reference_axis = Vec3.new(1, 0, 0)
  end)

  describe("when created without constraints", function()
    before_each(function()
      joint = Joint.hinge(rotation_axis, reference_axis)
    end)

    it("creates a new joint instance", function()
      Object.assert_type(joint, Joint)
    end)

    it("sets the joint type to ball", function()
      assert.is_true(joint:is_hinge())
    end)

    it("sets the anticlockwise constraint to 180º", function()
      assert.are.equal(joint:anticlockwise_constraint(), Angle.from_degrees(180))
    end)

    it("sets the clockwise constraint to 180º", function()
      assert.are.equal(joint:clockwise_constraint(), Angle.from_degrees(180))
    end)
  end)

  describe("when created with only a clockwise constraint", function()
    before_each(function()
      clockwise_constraint = Angle.from_degrees(30)
      joint = Joint.hinge(rotation_axis, reference_axis, clockwise_constraint)
    end)

    it("sets the clockwise constraint to the supplied value", function()
      assert.are.equal(joint:clockwise_constraint(), clockwise_constraint)
    end)

    it("sets the anticlockwise constraint to the same value", function()
      assert.are.equal(joint:anticlockwise_constraint(), clockwise_constraint)
    end)
  end)

  describe("when created with constraints in both rotation directions", function()
    before_each(function()
      anticlockwise_constraint = Angle.from_degrees(60)
      clockwise_constraint = Angle.from_degrees(30)
      joint = Joint.hinge(rotation_axis, reference_axis, clockwise_constraint, anticlockwise_constraint)
    end)

    it("sets the clockwise constraint to the supplied value", function()
      assert.are.equal(joint:clockwise_constraint(), clockwise_constraint)
    end)

    it("sets the anticlockwise constraint to the supplied value", function()
      assert.are.equal(joint:anticlockwise_constraint(), anticlockwise_constraint)
    end)
  end)

  describe("when the reference axis is not perpendicular to the rotation axis", function()
    before_each(function()
      reference_axis = Vec3.new(0, 1, 1)
    end)

    it("raises an exception", function()
      assert.has.errors(function()
        Joint.hinge(rotation_axis, reference_axis)
      end)
    end)
  end)
end)
