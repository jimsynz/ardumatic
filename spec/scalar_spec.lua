require "busted.runner"
local Scalar = require("scalar")

describe("Scalar.assert_type", function()
  it("can type check numbers", function()
    Scalar.assert_type(123, "number")
    Scalar.assert_type(1.23, "number")
  end)

  it("can type check strings", function()
    Scalar.assert_type("Marty McFly", "string")
  end)

  it("can type check nil", function()
    Scalar.assert_type(nil, "nil")
  end)

  it("can type check booleans", function()
    Scalar.assert_type(true, "boolean")
    Scalar.assert_type(false, "boolean")
  end)

  it("can type check tables", function()
    Scalar.assert_type({}, "table")
  end)

  it("can type check functions", function()
    Scalar.assert_type(function() return 0 end, "function")
  end)

  it("can type check integers", function()
    Scalar.assert_type(1, "integer")
  end)

  it("can type check floats", function()
    Scalar.assert_type(1.1, "float")
  end)
end)
