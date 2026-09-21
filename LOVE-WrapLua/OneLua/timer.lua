lv1lua.timer = timer.new()
local gtimer  = timer.new()
lv1lua.timer:start()
gtimer:start()
-- The main loop stores the frame delta on lv1lua.dt (see whileloop.lua); the
-- old file-global `dt` was never updated, so getDelta always read 0.
lv1lua.dt = lv1lua.dt or 0

function love.timer.getTime()
    return gtimer:time() / 1000
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

function love.timer.step()
    -- In the wrapper the main loop drives stepping; this is a no-op.
end

function love.timer.sleep(seconds)
    os.delay(math.floor(seconds * 1000))
end
