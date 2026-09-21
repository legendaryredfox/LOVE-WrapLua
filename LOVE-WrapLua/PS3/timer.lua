-- Fixed 60 fps delta; PS3 Lua Player has no high-res timer. The main loop
-- overwrites lv1lua.dt each frame (whileloop.lua), so honour it if already set.
lv1lua.dt = lv1lua.dt or 1 / 60

function love.timer.getTime()
    return os.time()
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
    sys.TimerUsleep(math.floor(seconds * 1000000))
end
