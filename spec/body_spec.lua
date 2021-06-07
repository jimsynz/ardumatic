require "busted.runner"
local Body = require("body")

describe("Body.new", function()
  it("creates an instance of a body", function()
    local body = Body.new(13)
    assert.are.equal(body:length(), 13)
  end)
end)
