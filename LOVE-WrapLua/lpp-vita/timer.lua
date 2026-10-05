lv1lua.timer = Timer.new()
local gtimer  = Timer.new()
-- The main loop stores the update slice on lv1lua.dt (core/timestep.lua).
lv1lua.dt = lv1lua.dt or 0

function love.timer.getTime()
    return Timer.getTime(gtimer) / 1000
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
    return lv1lua.frameDelta or 0
end

function love.timer.sleep(seconds)
    -- lpp-vita: Timer.delay takes milliseconds (if available), else busy-wait
    local ms = math.floor(seconds * 1000)
    if Timer.delay then
        Timer.delay(ms)
    else
        local start = Timer.getTime(gtimer)
        while Timer.getTime(gtimer) - start < ms do end
    end
end
