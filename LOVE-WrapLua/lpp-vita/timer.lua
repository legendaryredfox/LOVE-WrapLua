lv1lua.timer = Timer.new()
local gtimer  = Timer.new()
-- The main loop stores the frame delta on lv1lua.dt (see whileloop.lua); the
-- old file-global `dt` was never updated, so getDelta always read 0.
lv1lua.dt = lv1lua.dt or 0

function love.timer.getTime()
    return Timer.getTime(gtimer) / 1000
end

function love.timer.getDelta()
    return lv1lua.dt
end

function love.timer.getFPS()
    if lv1lua.dt > 0 then return math.floor(1 / lv1lua.dt + 0.5) end
    return 60
end

function love.timer.getAverageDelta()
    return lv1lua.dt
end

function love.timer.step() end

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
