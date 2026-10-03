-- lpp-3ds Timer: new / getTime (integer milliseconds) / reset. There is no
-- delay or sleep call, so love.timer.sleep spins on a timer.
lv1lua.timer = Timer.new()
local gtimer  = Timer.new()
lv1lua.dt = lv1lua.dt or 0

function love.timer.getTime()
    return Timer.getTime(gtimer) / 1000
end

function love.timer.getDelta()
    return lv1lua.dt
end

function love.timer.getFPS()
    return lv1lua.core.getFPS()
end

function love.timer.getAverageDelta()
    return lv1lua.core.getAverageDelta()
end

function love.timer.step()
    return lv1lua.frameDelta or 0
end

function love.timer.sleep(seconds)
    local ms = (seconds or 0) * 1000
    local start = Timer.getTime(gtimer)
    while Timer.getTime(gtimer) - start < ms do end
end
