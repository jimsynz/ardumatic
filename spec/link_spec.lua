require "busted.runner"
local Link = require("link")
local Object = require("object")

describe("Link.new", function()
  describe("when given a length", function()
    local link
    before_each(function() link = Link.new(13) end)

    it("creates a new Link instance", function()
      Object.assert_type(link, Link)
    end)

    it("calculates the Link length", function()
      assert.are.equal(link:length(), 13)
    end)
  end)
end)
