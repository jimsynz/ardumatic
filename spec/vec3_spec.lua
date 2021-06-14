require "busted.runner"
local Angle = require("angle")
local Scalar = require("scalar")
local Vec3 = require("vec3")
local Vector3f = require("ardupilot.vector3f")
local default = {x = 3, y = 4, z = 12}
local default_length = 13

describe("Vec3.from_vector3f", function()
  local vector3f, vec3
  before_each(function()
     vector3f = Vector3f():x(default.x):y(default.y):z(default.z)
     vec3 = Vec3.from_vector3f(vector3f)
  end)

  it("wraps the Vector3f", function()
    assert.are.equal(vec3._vector3f, vector3f)
  end)
end)

describe("Vec3.new", function()
  local vec
  before_each(function()
    vec = Vec3.new(default.x, default.y, default.z)
  end)

  it ("creates a new Vector", function()
    assert.are.equal(default.x, vec:x())
    assert.are.equal(default.y, vec:y())
    assert.are.equal(default.z, vec:z())
  end)
end)

for component, value in pairs(default) do
  describe("Vec3:" .. component, function()
    local vec
    before_each(function()
      vec = Vec3.new(default.x, default.y, default.z)
    end)

    it("returns the " .. component .. " component", function()
      assert.are.equal(value, vec[component](vec))
    end)
  end)
end

describe("Vec3.zero", function()
  local vec
  before_each(function()
    vec = Vec3.zero()
  end)

  for component, _ in pairs(default) do
    it("has a zero " .. component .. " component", function()
      assert.are.equal(0, vec[component](vec))

    end)
  end
end)

describe("Vec3:length", function()
  local vec
  before_each(function()
    vec = Vec3.new(default.x, default.y, default.z)
  end)

  it("calculates the correct value", function()
    assert.is.equal(default_length, vec:length())
  end)
end)

describe("Vec3:normalise", function()
  local vec
  before_each(function()
    vec = Vec3.new(default.x, default.y, default.z):normalise()
  end)

  for component, value in pairs(default) do
    describe(component .. " component", function()
      it("calculates the correct value", function()
        assert.are.equal(value / default_length, vec[component](vec))
      end)
    end)
  end
end)

describe("Vec3:dot", function()
  local vec0, vec1

  before_each(function()
    vec0 = Vec3.new(1,2,3)
    vec1 = Vec3.new(4,5,6)
  end)

  it("returns the dot product of the two vectors", function()
    assert.are.equal(32, vec0:dot(vec1))
  end)
end)

describe("Vec3:cross", function()
  local vec0, vec1

  before_each(function()
    vec0 = Vec3.new(1,-7,1)
    vec1 = Vec3.new(5,2,4)
  end)

  for component, value in pairs({x = -30, y = 1, z = 37}) do
    it("calculates the " .. component .. " component correctly", function()
      local cross = vec0:cross(vec1)
      assert.are.equal(value, cross[component](cross))
    end)
  end
end)

describe("Vec3:length_squared", function()
  local vec
  before_each(function()
    vec = Vec3.new(default.x, default.y, default.z)
  end)

  it("calculates the correct value", function()
    assert.are.equal(default_length ^ 2, vec:length_squared())
  end)
end)

describe("Vec3:distance", function()
  local vecs = {
    {Vec3.new(0, 0, 0), Vec3.new(10, 0, 0), 10},
    {Vec3.new(0, 0, 0), Vec3.new(3,4, 0), 5},
    {Vec3.new(40, 30, 0), Vec3.new(0, 0, 0), 50}
  }

  for _, example in ipairs(vecs) do
    local left = example[1]
    local right = example[2]
    local expected = example[3]

    describe("when the left-hand vector is " .. tostring(left) .. " and the right-hand vector is " .. tostring(right), function()
      it("is " .. tostring(expected), function()
        assert.are.equal(left:distance(right), expected)
      end)
    end)
  end
end)

describe("Vec3:direction", function()
  local vecs = {
    {Vec3.new(0, 0, 0), Vec3.new(10, 0, 0), Vec3.new(1, 0, 0)},
    {Vec3.new(0, 0, 0), Vec3.new(-1, -1, 0), Vec3.new(-0.70710678118654746172, -0.70710678118654746172, 0)}
  }

  for _, example in ipairs(vecs) do
    local left = example[1]
    local right = example[2]
    local expected = example[3]

    describe("when the left-hand vector is " .. tostring(left) .. " and the right-hand vector is " .. tostring(right), function()
      it("is " .. tostring(expected), function()
        assert.are.equal(left:direction(right), expected)
      end)
    end)
  end
end)

describe("Vec3:angle_to", function()
  local vecs = {
    {Vec3.new(1, 0, 0), Vec3.new(0, 1, 0), Angle.from_degrees(90)},
    {Vec3.new(1, 0, 0), Vec3.new(1, 1, 0), Angle.from_degrees(45)},
    {Vec3.new(1, 0, 0), Vec3.new(1,0, 1), Angle.from_degrees(45)},
    {Vec3.new(-1, 0, 0), Vec3.new(1,0, 0), Angle.from_degrees(180)},
    {Vec3.new(-1, 0, 0), Vec3.new(1,0, -1), Angle.from_degrees(135)},
  }

  for _, example in ipairs(vecs) do
    local left = example[1]:normalise()
    local right = example[2]:normalise()
    local expected = example[3]

    describe("when the left-hand vector is " .. tostring(left) .. " and the right-hand vector is " .. tostring(right), function()
      it("is " .. tostring(expected:degrees()) .. "º", function()
        assert.are.near(left:angle_to(right):degrees(), expected:degrees(), Scalar.FLOAT_EPSILON)
      end)
    end)
  end
end)

describe("Vec3:constrained_rotation_towards", function()
  local vecs = {
    {Vec3.new(1, 0, 0), Vec3.new(0, 1, 0), Angle.from_degrees(45), Angle.from_degrees(45)},
    {Vec3.new(1, 0, 0), Vec3.new(0, 1, 0), Angle.from_degrees(270), Angle.from_degrees(90)},
  }

  for _, example in ipairs(vecs) do
    local origin_axis = example[1]:normalise()
    local target_axis = example[2]:normalise()
    local constraint = example[3]
    local expected = example[4]

    describe(
        "when the origin axis is " .. tostring(origin_axis)
        .. " and the target axis is " .. tostring(target_axis)
        .. " and it is constrained by " .. tostring(constraint:degrees()) .. "º", function()
      it("it is rotated by " .. tostring(expected:degrees()) .. "º", function()
        local constrained_axis = origin_axis:constrained_rotation_towards(target_axis, constraint)
        local constrained_rotation = origin_axis:angle_to(constrained_axis)

        assert.are.near(constrained_rotation:degrees(), expected:degrees(), Scalar.FLOAT_EPSILON)
      end)
    end)
  end
end)

describe("Vec3:rotate_about_axis", function()
  local vecs = {
    {Vec3.new(1, 0, 0), Vec3.new(0, 1, 0), Angle.from_degrees(90), Vec3.new(0, 0, 1)},
    {Vec3.new(1, 0, 0), Vec3.new(0, 0, 1), Angle.from_degrees(45), Vec3.new(1, -1, 0)}
  }

  for _, example in ipairs(vecs) do
    local origin_axis = example[1]:normalise()
    local rotation_axis = example[2]:normalise()
    local rotation = example[3]
    local expected = example[4]:normalise()

    describe(
        "when the origin axis is " .. tostring(origin_axis)
        .. " and it is rotated by " .. tostring(rotation:degrees()) .. "º"
        .. " around " .. tostring(rotation_axis), function()
      it("it is rotated to " .. tostring(expected), function()
        local result = origin_axis:rotate_about_axis(rotation_axis, rotation)

        assert.are.near(result:x(), expected:x(), Scalar.FLOAT_EPSILON)
        assert.are.near(result:y(), expected:y(), Scalar.FLOAT_EPSILON)
        assert.are.near(result:z(), expected:z(), Scalar.FLOAT_EPSILON)
      end)
    end)
  end
end)
