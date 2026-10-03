-- lpp-3ds Sound (NDSP): openWav / openOgg / openAiff(path, streamed),
-- play(handle, loop), pause, resume, isPlaying, getTotalTime. There is no stop,
-- volume, seek or pitch call, so those stay tracked in core/audio.lua. play
-- resets the channel, so stop is a pause and the next play starts over.

Sound.init()

lv1lua.audio = lv1lua.audio or {}

local OPENERS = { wav = "openWav", ogg = "openOgg", aif = "openAiff", aiff = "openAiff" }

local function opener(path)
    local ext = string.lower(string.match(path, "%.([^%.]+)$") or "")
    return OPENERS[ext]
end

lv1lua.audio.hooks = {
    resolve = function(name) return lv1lua.dataloc .. "game/" .. name end,

    load = function(path, sourcetype)
        local fn = opener(path)
        if not fn then
            lv1lua.util.warn(path .. ": lpp-3ds decodes only WAV, OGG and AIFF")
            return nil
        end
        return Sound[fn](path, sourcetype == "stream")
    end,

    play   = function(src) Sound.play(src._handle, src._looping and true or false) end,
    stop   = function(src) Sound.pause(src._handle) end,
    pause  = function(src) Sound.pause(src._handle) end,
    resume = function(src) Sound.resume(src._handle) end,
    isPlaying = function(src) return Sound.isPlaying(src._handle) end,

    -- getTotalTime is whole seconds; a WAV header (read by core/audio.lua)
    -- is exact, so the native value is only used for the other formats.
    duration = function(src)
        local fn = opener(src._path or "")
        if not fn or fn == "openWav" then return nil end
        local t = Sound.getTotalTime(src._handle)
        if type(t) == "number" and t > 0 then return t end
        return nil
    end,
}

lv1lua.load("LOVE-WrapLua/core/audio.lua")
