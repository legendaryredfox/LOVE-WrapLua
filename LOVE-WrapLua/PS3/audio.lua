-- PS3 audio: the native hooks core/audio.lua drives.
--
-- The PS3 Lua Player streams one background voice: snd.SetVoice binds a file to
-- a channel and PlayVoice has to be re-issued every frame (lv1lua.playsound,
-- called from whileloop.lua). Static one-shot effects have no binding at all,
-- so a "static" source loads nothing and stays silent; it still answers every
-- Source method so game code keeps running.

snd.Init()
snd.SetVolumeBGMusic(127)

lv1lua.audio = lv1lua.audio or {}

local STREAM_CHANNEL = 1
local playing        = {}

-- The frame loop re-issues PlayVoice for every channel still marked playing.
function lv1lua.playsound()
    for ch, on in pairs(playing) do
        if on then
            snd.PlayVoice(ch, 0, 0, 200, 200, 0)
            sys.TimerUsleep(0)
        end
    end
end

lv1lua.audio.hooks = {
    resolve = function(name) return lv1lua.dataloc .. "game/" .. name end,

    load = function(path, sourcetype)
        if sourcetype ~= "stream" then return nil end
        snd.SetVoice(STREAM_CHANNEL, path)
        return STREAM_CHANNEL
    end,

    play   = function(src) if src._handle then playing[src._handle] = true  end end,
    pause  = function(src) if src._handle then playing[src._handle] = false end end,
    resume = function(src) if src._handle then playing[src._handle] = true  end end,
    stop   = function(src)
        if not src._handle then return end
        playing[src._handle] = false
        snd.StopVoice(src._handle)
        snd.FreeVoice(src._handle)
    end,

    -- SetVolumeBGMusic is 0-127 and global to the background voice.
    setVolume = function(src, v) snd.SetVolumeBGMusic(math.floor(v * 127 + 0.5)) end,
    isPlaying = function(src)
        if not src._handle then return false end
        return playing[src._handle] == true
    end,
}

lv1lua.load("LOVE-WrapLua/core/audio.lua")
