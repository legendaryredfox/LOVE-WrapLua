-- OneLua audio: the native hooks core/audio.lua drives (Vita + PSP).
--
-- OneLua plays on exactly two channels: 1 for static sound effects and 2 for
-- the stream/background track, so a source's channel follows its type and a
-- third simultaneous sound replaces one of them. No seek, tell, duration or
-- pitch call exists here, so those come from the shared timed position.

lv1lua.audio = lv1lua.audio or {}

local STATIC_CHANNEL, STREAM_CHANNEL = 1, 2

local function channelOf(src)
    return src._type == "static" and STATIC_CHANNEL or STREAM_CHANNEL
end

-- The SDK decodes MP3; the common LOVE formats are accepted by name and the
-- game is expected to ship the converted file next to the original.
local function convertExt(name)
    local first, last = string.find(name, "%.%a+$")
    if not first then return name end
    local ext = string.lower(string.sub(name, first + 1, last))
    if ext == "wav" or ext == "wma" or ext == "m4a" or ext == "3gp" or ext == "ogg" then
        return string.sub(name, 1, first) .. "mp3"
    end
    return name
end

lv1lua.audio.hooks = {
    resolve = function(name) return convertExt(lv1lua.dataloc .. "game/" .. name) end,
    load    = function(path) return sound.load(path) end,

    play    = function(src) sound.play(src._handle, channelOf(src)) end,
    stop    = function(src) sound.stop(src._handle) end,
    pause   = function(src) sound.pause(src._handle, 1) end,
    resume  = function(src) sound.pause(src._handle, 0) end,

    setVolume = function(src, v) sound.vol(src._handle, v * 100) end,
    getVolume = function(src) return sound.vol(src._handle) / 100 end,
    isPlaying = function(src) return sound.playing(src._handle) end,

    -- sound.loop is a toggle, not a setter.
    setLooping = function(src, loop)
        if sound.looping(src._handle) ~= loop then sound.loop(src._handle) end
    end,
}

lv1lua.load("LOVE-WrapLua/core/audio.lua")
