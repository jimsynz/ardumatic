describe("Vec3 Extensions", function()
  local Vec3 = require("vec3")
  
  describe("convenience constructors", function()
    it("should create up vector", function()
      local up = Vec3.up()
      assert.are.equal(0, up:x())
      assert.are.equal(0, up:y())
      assert.are.equal(1, up:z())
      assert.are.equal(1, up:length())
    end)
    
    it("should create down vector", function()
      local down = Vec3.down()
      assert.are.equal(0, down:x())
      assert.are.equal(0, down:y())
      assert.are.equal(-1, down:z())
      assert.are.equal(1, down:length())
    end)
    
    it("should create forward vector", function()
      local forward = Vec3.forward()
      assert.are.equal(1, forward:x())
      assert.are.equal(0, forward:y())
      assert.are.equal(0, forward:z())
      assert.are.equal(1, forward:length())
    end)
    
    it("should create backward vector", function()
      local backward = Vec3.backward()
      assert.are.equal(-1, backward:x())
      assert.are.equal(0, backward:y())
      assert.are.equal(0, backward:z())
      assert.are.equal(1, backward:length())
    end)
    
    it("should create right vector", function()
      local right = Vec3.right()
      assert.are.equal(0, right:x())
      assert.are.equal(1, right:y())
      assert.are.equal(0, right:z())
      assert.are.equal(1, right:length())
    end)
    
    it("should create left vector", function()
      local left = Vec3.left()
      assert.are.equal(0, left:x())
      assert.are.equal(-1, left:y())
      assert.are.equal(0, left:z())
      assert.are.equal(1, left:length())
    end)
    
    it("should create zero vector", function()
      local zero = Vec3.zero()
      assert.are.equal(0, zero:x())
      assert.are.equal(0, zero:y())
      assert.are.equal(0, zero:z())
      assert.are.equal(0, zero:length())
    end)
  end)
  
  describe("vector relationships", function()
    it("should have perpendicular unit vectors", function()
      local up = Vec3.up()
      local forward = Vec3.forward()
      local right = Vec3.right()
      
      -- Test perpendicularity (dot product should be 0)
      assert.are.equal(0, up:dot(forward))
      assert.are.equal(0, up:dot(right))
      assert.are.equal(0, forward:dot(right))
    end)
    
    it("should have opposite vectors", function()
      local up = Vec3.up()
      local down = Vec3.down()
      
      assert.are.equal(-1, up:dot(down))  -- Opposite vectors have dot product -1
      
      local forward = Vec3.forward()
      local backward = Vec3.backward()
      
      assert.are.equal(-1, forward:dot(backward))
      
      local right = Vec3.right()
      local left = Vec3.left()
      
      assert.are.equal(-1, right:dot(left))
    end)
    
    it("should form right-handed coordinate system", function()
      local forward = Vec3.forward()  -- X
      local right = Vec3.right()      -- Y  
      local up = Vec3.up()            -- Z
      
      -- In a right-handed system: X × Y = Z
      local cross_product = forward:cross(right)
      
      assert.is_true(math.abs(cross_product:x() - up:x()) < 0.001)
      assert.is_true(math.abs(cross_product:y() - up:y()) < 0.001)
      assert.is_true(math.abs(cross_product:z() - up:z()) < 0.001)
    end)
  end)
  
  describe("usage in robot configurations", function()
    it("should work with joint configurations", function()
      local Vec3 = require("vec3")
      local Joint = require("joint")
      local Angle = require("angle")
      
      -- This should not throw errors
      local hinge = Joint.hinge(
        Vec3.up(),      -- rotation axis
        Vec3.forward(), -- reference axis
        Angle.from_degrees(90),
        Angle.from_degrees(90)
      )
      
      assert.is_not_nil(hinge)
      assert.is_true(hinge:is_hinge())
    end)
    
    it("should work with ball joint configurations", function()
      local Vec3 = require("vec3")
      local Joint = require("joint")
      local Angle = require("angle")
      
      -- This should not throw errors
      local ball = Joint.ball(
        Vec3.forward(),  -- reference axis
        Angle.from_degrees(45)
      )
      
      assert.is_not_nil(ball)
      assert.is_true(ball:is_ball())
    end)
    
    it("should work with chain origins", function()
      local Vec3 = require("vec3")
      local Chain = require("chain")
      
      local chain_up = Chain.new(Vec3.up(), "up_chain")
      local chain_forward = Chain.new(Vec3.forward(), "forward_chain")
      
      assert.are.equal(1, chain_up:origin():z())
      assert.are.equal(1, chain_forward:origin():x())
    end)
  end)
  
  describe("vector arithmetic with convenience constructors", function()
    it("should support addition", function()
      local result = Vec3.forward() + Vec3.right()
      
      assert.are.equal(1, result:x())
      assert.are.equal(1, result:y())
      assert.are.equal(0, result:z())
    end)
    
    it("should support subtraction", function()
      local result = Vec3.up() - Vec3.down()
      
      assert.are.equal(0, result:x())
      assert.are.equal(0, result:y())
      assert.are.equal(2, result:z())  -- 1 - (-1) = 2
    end)
    
    it("should support scalar multiplication", function()
      local result = Vec3.forward() * 5
      
      assert.are.equal(5, result:x())
      assert.are.equal(0, result:y())
      assert.are.equal(0, result:z())
    end)
    
    it("should support normalization", function()
      local scaled = Vec3.up() * 10
      assert.are.equal(10, scaled:length())
      
      local normalized = scaled:normalise()
      assert.is_true(math.abs(normalized:length() - 1) < 0.001)
      assert.are.equal(0, normalized:x())
      assert.are.equal(0, normalized:y())
      assert.are.equal(1, normalized:z())
    end)
  end)
  
  describe("integration with existing Vec3 functionality", function()
    it("should work with existing Vec3 methods", function()
      local up = Vec3.up()
      
      -- Test existing methods still work
      assert.is_false(up:is_zero())
      assert.are.equal(1, up:length())
      
      local inverted = up:invert()
      assert.are.equal(0, inverted:x())
      assert.are.equal(0, inverted:y())
      assert.are.equal(-1, inverted:z())
    end)
    
    it("should work with angle calculations", function()
      local up = Vec3.up()
      local down = Vec3.down()
      
      local angle = up:angle_to(down)
      assert.is_true(math.abs(angle:degrees() - 180) < 0.1)
    end)
    
    it("should work with cross products", function()
      local forward = Vec3.forward()
      local right = Vec3.right()
      
      local cross = forward:cross(right)
      local up = Vec3.up()
      
      -- Cross product should equal up vector
      assert.is_true(math.abs(cross:x() - up:x()) < 0.001)
      assert.is_true(math.abs(cross:y() - up:y()) < 0.001)
      assert.is_true(math.abs(cross:z() - up:z()) < 0.001)
    end)
    
    it("should work with dot products", function()
      local forward = Vec3.forward()
      local right = Vec3.right()
      local up = Vec3.up()
      
      -- Perpendicular vectors should have dot product 0
      assert.are.equal(0, forward:dot(right))
      assert.are.equal(0, forward:dot(up))
      assert.are.equal(0, right:dot(up))
      
      -- Parallel vectors should have dot product 1
      assert.are.equal(1, forward:dot(forward))
      assert.are.equal(1, right:dot(right))
      assert.are.equal(1, up:dot(up))
    end)
  end)
end)