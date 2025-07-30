-- Example custom robot configuration using table specification
-- This demonstrates how to define a robot using a declarative table format

local RobotBuilder = require("robot_builder")
local ConfigValidator = require("config_validator")

-- Define a custom robot specification
local robot_spec = {
  name = "custom_quadruped",
  chains = {
    -- Front left leg with custom joint constraints
    front_left = {
      origin = {-60, 80, 0},
      segments = {
        {
          joint = {
            type = "hinge",
            rotation_axis = {0, 0, 1},
            reference_axis = {1, 0, 0},
            clockwise_constraint = 60,
            anticlockwise_constraint = 60
          },
          link = {
            length = 45,
            name = "shoulder"
          }
        },
        {
          joint = {
            type = "hinge", 
            rotation_axis = {0, 1, 0},
            reference_axis = {1, 0, 0},
            clockwise_constraint = 90,
            anticlockwise_constraint = 45
          },
          link = {
            length = 70,
            name = "upper_leg"
          }
        },
        {
          joint = {
            type = "hinge",
            rotation_axis = {0, 1, 0},
            reference_axis = {1, 0, 0},
            clockwise_constraint = 120,
            anticlockwise_constraint = 10
          },
          link = {
            length = 85,
            name = "lower_leg"
          }
        }
      }
    },
    
    -- Front right leg (mirrored)
    front_right = {
      origin = {60, 80, 0},
      segments = {
        {
          joint = {
            type = "hinge",
            rotation_axis = {0, 0, 1},
            reference_axis = {-1, 0, 0},
            clockwise_constraint = 60,
            anticlockwise_constraint = 60
          },
          link = {
            length = 45,
            name = "shoulder"
          }
        },
        {
          joint = {
            type = "hinge",
            rotation_axis = {0, 1, 0},
            reference_axis = {-1, 0, 0},
            clockwise_constraint = 90,
            anticlockwise_constraint = 45
          },
          link = {
            length = 70,
            name = "upper_leg"
          }
        },
        {
          joint = {
            type = "hinge",
            rotation_axis = {0, 1, 0},
            reference_axis = {-1, 0, 0},
            clockwise_constraint = 120,
            anticlockwise_constraint = 10
          },
          link = {
            length = 85,
            name = "lower_leg"
          }
        }
      }
    },
    
    -- Rear legs with different proportions
    rear_left = {
      origin = {-60, -80, 0},
      segments = {
        {
          joint = {
            type = "hinge",
            rotation_axis = {0, 0, 1},
            reference_axis = {1, 0, 0},
            clockwise_constraint = 45,
            anticlockwise_constraint = 45
          },
          link = {
            length = 50,
            name = "hip"
          }
        },
        {
          joint = {
            type = "hinge",
            rotation_axis = {0, 1, 0},
            reference_axis = {1, 0, 0},
            clockwise_constraint = 100,
            anticlockwise_constraint = 30
          },
          link = {
            length = 80,
            name = "thigh"
          }
        },
        {
          joint = {
            type = "hinge",
            rotation_axis = {0, 1, 0},
            reference_axis = {1, 0, 0},
            clockwise_constraint = 130,
            anticlockwise_constraint = 5
          },
          link = {
            length = 90,
            name = "shin"
          }
        }
      }
    },
    
    rear_right = {
      origin = {60, -80, 0},
      segments = {
        {
          joint = {
            type = "hinge",
            rotation_axis = {0, 0, 1},
            reference_axis = {-1, 0, 0},
            clockwise_constraint = 45,
            anticlockwise_constraint = 45
          },
          link = {
            length = 50,
            name = "hip"
          }
        },
        {
          joint = {
            type = "hinge",
            rotation_axis = {0, 1, 0},
            reference_axis = {-1, 0, 0},
            clockwise_constraint = 100,
            anticlockwise_constraint = 30
          },
          link = {
            length = 80,
            name = "thigh"
          }
        },
        {
          joint = {
            type = "hinge",
            rotation_axis = {0, 1, 0},
            reference_axis = {-1, 0, 0},
            clockwise_constraint = 130,
            anticlockwise_constraint = 5
          },
          link = {
            length = 90,
            name = "shin"
          }
        }
      }
    }
  }
}

-- Build the robot from the specification
local custom_robot = RobotBuilder.from_spec(robot_spec)

-- Validate the configuration
local validator = ConfigValidator.new()
if validator:validate(custom_robot) then
  print("Custom robot configuration is valid!")
  
  -- Build the kinematic chains
  local chains = custom_robot:build_chains()
  
  -- Print information about each chain
  for name, chain in pairs(chains) do
    print(string.format("Chain '%s': %d segments, reach = %.1f, origin = %s", 
                       name, chain:length(), chain:reach(), chain:origin()))
  end
  
else
  print("Custom robot configuration has errors:")
  for _, error in ipairs(validator:get_errors()) do
    print("  ERROR: " .. error)
  end
  
  for _, warning in ipairs(validator:get_warnings()) do
    print("  WARNING: " .. warning)
  end
end

return custom_robot