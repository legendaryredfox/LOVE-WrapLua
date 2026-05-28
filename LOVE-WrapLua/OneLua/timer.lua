lv1lua.timer = timer.new()
local gtimer  = timer.new()
lv1lua.timer:start()
gtimer:start()
dt = 0

function love.timer.getTime()
    return gtimer:time() / 1000
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

function love.timer.step()
    -- In the wrapper the main loop drives stepping; this is a no-op.
end

function love.timer.sleep(seconds)
    os.delay(math.floor(seconds * 1000))
end
