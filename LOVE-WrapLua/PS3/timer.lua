dt = 0.0167  -- fixed 60 fps delta; PS3 Lua Player has no high-res timer

function love.timer.getTime()
    return os.time()
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
    sys.TimerUsleep(math.floor(seconds * 1000000))
end
