local Object = require("object")
local Scalar = require("scalar")
local string = require("string")

local Link = Object.new("Link", {
  __tostring = function(self)
    if self.name then
      return string.format("Link{name=%s,length=%f}", self._name, self._length)
    else
      return string.format("Link{length=%f}", self._length)
    end
  end
})

function Link.new(length, name)
  Scalar.assert_type(length, "number")
  Scalar.assert_type(name, "string", true)

  return Object.instance({
    _length = length,
    _name = name
  }, Link)
end

Link.length = Object.reader("length")
Link.name = Object.reader("name")

return Link
