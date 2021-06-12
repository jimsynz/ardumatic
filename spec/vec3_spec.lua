require "busted.runner"
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

describe("Vec3:normalize", function()
  local vec
  before_each(function()
    vec = Vec3.new(default.x, default.y, default.z):normalize()
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
