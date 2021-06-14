require "busted.runner"
local Mat3 = require("mat3")
local Object = require("object")
local Vec3 = require("vec3")

describe("Mat3.new", function()
  it("creates an instance of Mat3", function()
    local matrix = Mat3.new({0, 0, 0, 0, 0, 0, 0, 0, 0})
    Object.assert_type(matrix, Mat3)
  end)
end)

describe("Mat3:mul_vec3", function()
  it("correctly multiplies the matrix by the fector", function()
    local matrix = Mat3.new({
      1, 4, 6,
      2, 3, 0,
      0, 7, 0
    })

    local vec = Vec3.new(2, 0, 1)
    local result = matrix:mul_vec3(vec)

    assert.are.equal(result:x(), 8)
    assert.are.equal(result:y(), 4)
    assert.are.equal(result:z(), 0)
  end)
end)
