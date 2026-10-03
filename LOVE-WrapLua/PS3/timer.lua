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
    -- Nothing here measures a frame, so this is the assumed rate the
    -- accumulator runs at (core/timestep.lua).
    return lv1lua.core.getFPS()
end

function love.timer.getAverageDelta()
    return lv1lua.core.getAverageDelta()
end

function love.timer.step()
    return lv1lua.frameDelta or 0
end

function love.timer.sleep(seconds)
    sys.TimerUsleep(math.floor(seconds * 1000000))
end
