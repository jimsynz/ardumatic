require "busted.runner"
local math = require "math"
local string = require("string")
local Angle = require("angle")

describe("Angle.zero", function()
  it("returns a zero angle", function()
    local angle = Angle.zero()
    assert.are.equal(angle:radians(), 0)
    assert.are.equal(angle:degrees(), 0)
  end)
end)

describe("Angle.from_radians", function()
  it("creates a new angle", function()
    local angle = Angle.from_radians(math.pi)
    assert.are.equal(angle:radians(), math.pi)
    assert.are.equal(angle:degrees(), 180)
  end)
end)

describe("Angle.from_degrees", function()
  it("creates a new angle", function()
    local angle = Angle.from_degrees(180)
    assert.are.equal(angle:radians(), math.pi)
    assert.are.equal(angle:degrees(), 180)
  end)
end)

describe("Angle:normalise", function()
  local angle

  describe("when the angle as a multiple rotation radian", function()
    before_each(function() angle = Angle.from_radians(6.5 * math.pi) end)

    it("normalises it within a single ratation", function()
      local actual = angle:normalise():radians()
      local expected = 0.5 * math.pi
      -- Thanks IEEE.
      assert.are.equal(string.format("%0.10f", actual), string.format("%0.10f", expected))
    end)
  end)

  describe("when the angle is a negative rotation radian", function()
    before_each(function() angle = Angle.from_radians(-0.75 * math.pi) end)

    it("normalises it within a single ratation", function()
      local actual = angle:normalise():radians()
      local expected = 1.25 * math.pi
      -- Thanks IEEE.
      assert.are.equal(string.format("%0.10f", actual), string.format("%0.10f", expected))
    end)
  end)

  describe("when the angle as a multiple rotation degree", function()
    before_each(function() angle = Angle.from_degrees(6.5 * 360) end)

    it("normalises it within a single ratation", function()
      local actual = angle:normalise():degrees()
      local expected = 180
      assert.are.equal(actual, expected)
    end)
  end)

  describe("when the angle is a negative rotation degree", function()
    before_each(function() angle = Angle.from_degrees(-270) end)

    it("normalises it within a single ratation", function()
      local actual = angle:normalise():degrees()
      local expected = 90
      assert.are.equal(actual, expected)
    end)
  end)
end)
