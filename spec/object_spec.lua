require "busted.runner"
local Object = require("object")

local Example = Object.new("Example")

function Example.is_example()
  return true
end

describe("Object.instance", function()
  describe("when called with a table and a class", function()
    it("creates a new instance of the class", function()
      local instance = Object.instance({}, Example)

      assert.is.truthy(instance.is_example())
      assert.are.equal(instance.class, Example)
      assert.is.truthy(instance:type_of(Example))
    end)
  end)

  describe("when called with a table, class and metatable", function()
    before_each(function()
      Example = Object.new("Example", Example, {
        __add = function(self, other)
          return self.value + other.value
        end
      })
    end)

    it("creates a new instance of the class", function()
      local instance = Object.instance({}, Example)

      assert.is.truthy(instance.is_example())
      assert.are.equal(instance.class, Example)
      assert.is.truthy(instance:type_of(Example))
    end)

    it("merges the existing metatable with the default one", function()
      local instance0 = Object.instance({value = 13}, Example)
      local instance1 = Object.instance({value = -6}, Example)

      assert.are.equal(instance0 + instance1, 7)
    end)
  end)
end)

describe("Object.reader", function()
  describe("when called without an attribute name", function()
    it("generates a reader function which reads the underscored version of it's own name", function()
      local reader = Object.reader("name")
      local result = reader({_name = "Marty McFly"})
      assert.are.equal(result, "Marty McFly")
    end)
  end)

  describe("When called with an attribute name", function()
    it("generates a reader function for the specified attribute", function()
      local reader = Object.reader("name", "character_name")
      local result = reader({character_name = "Marty McFly"})
      assert.are.equal(result, "Marty McFly")
    end)
  end)
end)

describe("Object.writer", function()
  describe("when called without an attribute name", function()
    it("generates a writer function which reads the underscored version of it's own name", function()
      local writer = Object.writer("name")
      local object = {}
      writer(object, "Marty McFly")
      assert.are.equal(object._name, "Marty McFly")
    end)
  end)

  describe("When called with an attribute name", function()
    it("generates a writer function for the specified attribute", function()
      local writer = Object.writer("name", "character_name")
      local object = {}
      writer(object, "Marty McFly")
      assert.are.equal(object.character_name, "Marty McFly")
    end)
  end)
end)

describe("Object.accessor", function()
  describe("when called without an attribute name", function()
    local accessor, object

    before_each(function()
      accessor = Object.accessor("name")
      object = { _name = "Marty McFly"}
    end)

    describe("when called without a value", function()
      it("returns the attributes value", function()
        assert.are.equal(accessor(object), "Marty McFly")
      end)
    end)

    describe("when called with a value", function()
      it("returns a mutated object", function()
        local new_object = accessor(object, "Doc Brown")
        assert.are.equal(new_object._name, "Doc Brown")
        assert.are.equal(new_object, object)
      end)
    end)
  end)

  describe("when called with an attribute name", function()
        local accessor, object

    before_each(function()
      accessor = Object.accessor("name", "character_name")
      object = { character_name = "Marty McFly"}
    end)

    describe("when called without a value", function()
      it("returns the attributes value", function()
        assert.are.equal(accessor(object), "Marty McFly")
      end)
    end)

    describe("when called with a value", function()
      it("returns a mutated object", function()
        local new_object = accessor(object, "Doc Brown")
        assert.are.equal(new_object.character_name, "Doc Brown")
        assert.are.equal(new_object, object)
      end)
    end)
  end)
end)
