-- lpp-vita audio: the native hooks core/audio.lua drives.
--
-- Grounded in source/luaSound.cpp. Sound.play takes the loop flag, resets the
-- track volume to 32767, and on a track already in an audio thread starts a
-- duplicate instead. There is no stop: stop closes the track and opens it
-- again, which rewinds without leaving a paused copy holding a thread. The
-- volume and every handle are read with luaL_checkinteger. Seek, tell,
-- duration and pitch are probed for builds that add them; the shared layer
-- times the position when they are missing.

Sound.init()

lv1lua.audio = lv1lua.audio or {}

-- LOVE's 0-1 to lpp-vita's integer 0-32767.
local function volume(v)
    return math.max(0, math.min(32767, math.floor(v * 32767 + 0.5)))
end

local function native(name)
    local fn = Sound[name]
    if type(fn) == "function" then return fn end
    return nil
end

lv1lua.audio.hooks = {
    resolve = function(name) return lv1lua.dataloc .. "game/" .. name end,
    load    = function(path) return Sound.open(path) end,

    play    = function(src)
        Sound.play(src._handle, src._looping)
        Sound.setVolume(src._handle, volume(src._volume * love.audio.getVolume()))
    end,
    stop    = function(src)
        Sound.close(src._handle)
        src._handle = Sound.open(src._path)
        src.loadsound = src._handle
    end,
    pause   = function(src) Sound.pause(src._handle) end,
    resume  = function(src) Sound.resume(src._handle) end,
    release = function(src) Sound.close(src._handle) end,

    setVolume = function(src, v) Sound.setVolume(src._handle, volume(v)) end,
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
