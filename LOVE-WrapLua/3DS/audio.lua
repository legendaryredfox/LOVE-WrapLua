Sound.init()

lv1lua.audio = lv1lua.audio or {}

local function native(name)
    local fn = Sound[name]
    if type(fn) == "function" then return fn end
    return nil
end

lv1lua.audio.hooks = {
    resolve = function(name) return lv1lua.dataloc .. "game/" .. name end,
    load    = function(path) return Sound.open(path) end,

    play    = function(src) Sound.play(src._handle) end,
    stop    = function(src) Sound.stop(src._handle) end,
    pause   = function(src) Sound.pause(src._handle) end,
    resume  = function(src) Sound.play(src._handle) end,

    -- lpp-3ds volume is 0-127.
    setVolume = function(src, v) Sound.setVolume(src._handle, math.floor(v * 127 + 0.5)) end,
    getVolume = function(src) return Sound.getVolume(src._handle) / 127 end,
    isPlaying = function(src) return Sound.isPlaying(src._handle) end,

    seek = function(src, seconds)
        local fn = native("setPosition")
        if fn then fn(src._handle, seconds) end
    end,
    tell = function(src)
        local fn = native("getPosition")
        if fn then return fn(src._handle) end
        return nil
    end,
    duration = function(src)
        local fn = native("getDuration")
        if fn then return fn(src._handle) end
        return nil
    end,
    setPitch = function(src, p)
        local fn = native("setPitch")
        if fn then fn(src._handle, p) end
    end,
}

lv1lua.load("LOVE-WrapLua/core/audio.lua")
