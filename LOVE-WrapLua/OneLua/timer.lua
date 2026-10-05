lv1lua.timer = timer.new()
local gtimer  = timer.new()
lv1lua.timer:start()
gtimer:start()
-- The main loop stores the update slice on lv1lua.dt (core/timestep.lua).
lv1lua.dt = lv1lua.dt or 0

function love.timer.getTime()
    return gtimer:time() / 1000
end

function love.timer.getDelta()
    return lv1lua.dt
end

function love.timer.getFPS()
    -- The render rate, which the fixed-timestep accumulator (core/timestep.lua)
    -- keeps separate from the update rate.
    return lv1lua.core.getFPS()
end

function love.timer.getAverageDelta()
    return lv1lua.core.getAverageDelta()
end

function love.timer.step()
    -- The main loop measures the frame; report what it measured.
    return lv1lua.frameDelta or 0
end

function love.timer.sleep(seconds)
    os.delay(math.floor(seconds * 1000))
end
