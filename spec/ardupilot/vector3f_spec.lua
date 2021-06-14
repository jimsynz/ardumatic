require "busted.runner"
local Vector3f = require("ardupilot.vector3f")

describe("Vector3f", function()
  it("constructs a 3d vector", function()
    local v = Vector3f()
    assert.is.truthy(v)
  end)
end)

for _, component in pairs({"x", "y", "z"}) do
  describe("Vector3f:" .. component, function()
    local vec

    before_each(function()
      vec = Vector3f()
      vec = vec[component](vec, 1)
    end)

    describe("when called without an argument", function()
      it("returns the " .. component .. " of the vector", function()
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

describe("Vector3f:length", function()
  it("returns the length of the vector", function()
    local length = Vector3f():x(3):y(4):z(12):length()
    assert.are.equal(length, 13)
  end)
end)

describe("Vector3f:normalise", function()
  it("returns a new normalised vector", function()
    local norm = Vector3f():x(3):y(4):z(12):normalise()
    assert.are.equal(norm:x(), 3 / 13)
    assert.are.equal(norm:y(), 4 / 13)
    assert.are.equal(norm:z(), 12 / 13)
  end)
end)


describe("Vector3f:is_nan", function()
  local vector

  before_each(function()
    vector = Vector3f():x(0):y(0):z(0)
  end)

  for _, component in pairs({"x", "y", "z"}) do
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

describe("Vector3f:is_inf", function()
  local vector

  before_each(function()
    vector = Vector3f():x(0):y(0):z(0)
  end)

  for _, component in pairs({"x", "y", "z"}) do
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

describe("Vector3f:is_zero", function()
  local vector
  before_each(function() vector = Vector3f():x(1):y(1):z(1) end)

  for _, component in pairs({"x", "y", "z"}) do
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
    before_each(function() vector = vector:x(0):y(0):z(0) end)

    it("is true", function()
      assert.is.truthy(vector:is_zero())
    end)
  end)
end)

describe("Vector3f + Vector3f", function()
  local vector0, vector1
  before_each(function()
    vector0 = Vector3f():x(1):y(3):z(5)
    vector1 = Vector3f():x(2):y(4):z(6)
  end)

  it("adds them together correctly", function()
    local vector = vector0 + vector1
    assert.are.equal(vector:x(), 3)
    assert.are.equal(vector:y(), 7)
    assert.are.equal(vector:z(), 11)
  end)
end)

describe("Vector3f - Vector3f", function()
  local vector0, vector1
  before_each(function()
    vector0 = Vector3f():x(4):y(8):z(16)
    vector1 = Vector3f():x(1):y(3):z(5)
  end)

  it("adds them together correctly", function()
    local vector = vector0 - vector1
    assert.are.equal(vector:x(), 3)
    assert.are.equal(vector:y(), 5)
    assert.are.equal(vector:z(), 11)
  end)
end)
