require "busted.runner"
local Object = require("object")
local Vector2f = require "ardupilot.vector2f"

describe("Vector2f", function()
  it("constructs a 2d vector", function()
    local v = Vector2f()
    assert.is.truthy(v)
  end)
end)

for _, component in pairs({"x", "y"}) do
  describe("Vector2f:" .. component, function()
    local vec

    before_each(function()
      vec = Vector2f()
      vec = vec[component](vec, 1)
    end)

    describe("when called without an argument", function()
      it("returns the " .. component .. " component of the vector", function()
        assert.are.equal(1, vec[component](vec))
      end)
    end)

    describe("when called with an argument", function()
      it("returns a new vector with the " .. component .. " component changed", function()
        local new_vec = vec[component](vec, 13)
        assert.are.equal(13, new_vec[component](new_vec))
      end)
    end)
  end)
end

describe("Vector2f:length", function()
  it("returns the length of the vector", function()
    local length = Vector2f():x(3):y(4):length()
    assert.are.equal(length, 5)
  end)
end)

describe("Vector2f:normalize", function()
  it("returns a new normalized vector", function()
    local norm = Vector2f():x(3):y(4):normalize()
    assert.are.equal(norm:x(), 3 / 5)
    assert.are.equal(norm:y(), 4 / 5)
  end)
end)

describe("Vector2f:is_nan", function()
  local vector

  before_each(function()
    vector = Vector2f():x(0):y(0)
  end)

  for _, component in pairs({"x", "y"}) do
    describe("when the vector's " .. component .. " component is NaN", function()
      before_each(function()
        vector = vector[component](vector, 0/0)
      end)

      it("is true", function()
        assert.is.truthy(vector:is_nan())
      end)
    end)
  end

  describe("when the vector doesn't contain any NaN components", function()
    it("is false", function()
      assert.is.falsy(vector:is_nan())
    end)
  end)
end)

describe("Vector2f:is_inf", function()
  local vector

  before_each(function()
    vector = Vector2f():x(0):y(0)
  end)

  for _, component in pairs({"x", "y"}) do
    describe("when the vector's " .. component .. " component is inf", function()
      before_each(function()
        vector = vector[component](vector, math.huge)
      end)

      it("is true", function()
        assert.is.truthy(vector:is_inf())
      end)
    end)
  end

  describe("when the vector doesn't contain any inf components", function()
    it("is false", function()
      assert.is.falsy(vector:is_inf())
    end)
  end)
end)

describe("Vector2f:is_zero", function()
  local vector
  before_each(function() vector = Vector2f():x(1):y(1) end)

  for _, component in pairs({"x", "y"}) do
    describe("when the vector's " .. component .. " component is zero", function()
      before_each(function() vector = vector[component](vector, 0) end)

      it("is false", function()
        assert.is.falsy(vector:is_zero())
      end)
    end)
  end

  describe("when the vector doesn't contain any zero components", function()
    it("is false", function()
      assert.is.falsy(vector:is_zero())
    end)
  end)

  describe("when the vector contains only zero components", function()
    before_each(function() vector = vector:x(0):y(0) end)

    it("is true", function()
      assert.is.truthy(vector:is_zero())
    end)
  end)
end)

describe("Vector2f + Vector2f", function()
  local vector0, vector1
  before_each(function()
    vector0 = Vector2f():x(1):y(2)
    vector1 = Vector2f():x(3):y(4)
  end)

  it("adds them together correctly", function()
    local vector = vector0 + vector1
    assert.are.equal(vector:x(), 4)
    assert.are.equal(vector:y(), 6)
  end)
end)

describe("Vector2f - Vector2f", function()
  local vector0, vector1
  before_each(function()
    vector0 = Vector2f():x(11):y(9)
    vector1 = Vector2f():x(3):y(5)
  end)

  it("adds them together correctly", function()
    local vector = vector0 - vector1
    assert.are.equal(vector:x(), 8)
    assert.are.equal(vector:y(), 4)
  end)
end)
