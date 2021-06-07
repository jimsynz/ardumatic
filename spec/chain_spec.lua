require "busted.runner"
local Chain = require("chain")
local Frame = require("frame")
local Object = require("object")

describe("Chain.new", function()
  it("creates an instance of a chain", function()
    local frame = Frame.new()
    local chain = Chain.new(frame)
    Object.assert_type(chain, Chain)
  end)
end)
