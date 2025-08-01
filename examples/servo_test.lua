-- Simple 2-Servo Test Script
-- Tests 2 servo channels for simple hexapod legs

local test_state = {
    initialized = false,
    start_time = 0,
    current_time = 0,
    test_phase = 1,
    phase_start_time = 0
}

function log_message(level, message)
    gcs:send_text(level, message)
end

function initialize_servo_test()
    log_message(6, "Initializing Simple 2-Servo Test")
    
    -- Configure 2 servo channels
    for i = 1, 2 do
        param:set_and_save(string.format("SERVO%d_FUNCTION", i), 1) -- Manual/PassThru
        param:set_and_save(string.format("SERVO%d_MIN", i), 1000)
        param:set_and_save(string.format("SERVO%d_MAX", i), 2000)
        param:set_and_save(string.format("SERVO%d_TRIM", i), 1500)
    end
    
    test_state.initialized = true
    test_state.start_time = millis()
    test_state.phase_start_time = test_state.start_time
    
    log_message(6, "2-servo test initialized - will test right and left legs")
end

function update_test_phase()
    local elapsed = (test_state.current_time - test_state.phase_start_time) / 1000.0
    
    -- Change test phase every 5 seconds
    if elapsed > 5.0 then
        test_state.test_phase = test_state.test_phase + 1
        test_state.phase_start_time = test_state.current_time
        
        if test_state.test_phase > 3 then
            test_state.test_phase = 1  -- Reset to start
        end
        
        if test_state.test_phase == 1 then
            log_message(6, "Testing RIGHT leg (red cylinder)")
        elseif test_state.test_phase == 2 then
            log_message(6, "Testing LEFT leg (green cylinder)")
        else
            log_message(6, "Testing BOTH legs together")
        end
    end
end

function update_servos()
    local time_in_phase = (test_state.current_time - test_state.phase_start_time) / 1000.0
    
    -- Create a sine wave motion for testing
    local sine_value = math.sin(time_in_phase * 2 * math.pi / 3.0)  -- 3 second period
    local servo_pwm = 1500 + (sine_value * 400)  -- 1100-1900 range
    
    if test_state.test_phase == 1 then
        -- Test right leg only
        SRV_Channels:set_output_pwm_chan_timeout(0, servo_pwm, 100)  -- Channel 1 (right)
        SRV_Channels:set_output_pwm_chan_timeout(1, 1500, 100)      -- Channel 2 (left) neutral
    elseif test_state.test_phase == 2 then
        -- Test left leg only
        SRV_Channels:set_output_pwm_chan_timeout(0, 1500, 100)      -- Channel 1 (right) neutral
        SRV_Channels:set_output_pwm_chan_timeout(1, servo_pwm, 100) -- Channel 2 (left)
    else
        -- Test both legs together (opposite phases)
        SRV_Channels:set_output_pwm_chan_timeout(0, servo_pwm, 100)                    -- Right
        SRV_Channels:set_output_pwm_chan_timeout(1, 1500 + (-sine_value * 400), 100)  -- Left (opposite)
    end
end

function update()
    test_state.current_time = millis()
    
    if not test_state.initialized then
        if test_state.current_time > 3000 then  -- Wait 3 seconds for system startup
            initialize_servo_test()
        end
        return update, 1000
    end
    
    -- Update test phase
    update_test_phase()
    
    -- Update servo outputs
    update_servos()
    
    return update, 50  -- 20Hz update rate
end

log_message(6, "Simple 2-Servo Test Script Loaded")
return update, 1000  -- Initial 1-second delay