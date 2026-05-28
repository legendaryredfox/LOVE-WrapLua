lv1lua.timer = Timer.new()
local gtimer  = Timer.new()
dt = 0

function love.timer.getTime()
    return Timer.getTime(gtimer) / 1000
end

function love.timer.getDelta()
    return dt
end

function love.timer.getFPS()
    if dt > 0 then return math.floor(1 / dt + 0.5) end
    return 60
end

function love.timer.getAverageDelta()
    return dt
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
