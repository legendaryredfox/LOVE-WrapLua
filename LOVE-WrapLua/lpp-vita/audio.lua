-- lpp-vita audio: the native hooks core/audio.lua drives.
--
-- Sound.play takes the loop flag, so looping is applied at play time rather
-- than stored on the handle. Seek, tell, duration and pitch are probed: older
-- lpp-vita builds do not expose them, and the shared layer falls back to its
-- timed position when they are missing.

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

    play    = function(src) Sound.play(src._handle, src._looping) end,
    stop    = function(src) Sound.pause(src._handle) end,
    pause   = function(src) Sound.pause(src._handle) end,
    resume  = function(src) Sound.play(src._handle, src._looping) end,

    -- lpp-vita volume is 0-32767.
    setVolume = function(src, v) Sound.setVolume(src._handle, v * 32767) end,
    getVolume = function(src) return Sound.getVolume(src._handle) / 32767 end,
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
