-- PS3 audio: the native hooks core/audio.lua drives.
--
-- The PS3 Lua Player streams one background voice: snd.SetVoice binds a file to
-- the channel and PlayVoice has to be re-issued every frame (lv1lua.playsound,
-- called from whileloop.lua). The last stream to play holds the voice. Static one-shot effects have no binding at all,
-- so a "static" source loads nothing and stays silent; it still answers every
-- Source method so game code keeps running.

snd.Init()
snd.SetVolumeBGMusic(127)

lv1lua.audio = lv1lua.audio or {}

local STREAM_CHANNEL = 1
local playing        = {}
-- The source whose file the voice holds. Bound at play, because the voice is
-- one channel: binding at newSource let the last source created own it.
local bound          = nil

-- The frame loop re-issues PlayVoice for every channel still marked playing.
function lv1lua.playsound()
    for ch, on in pairs(playing) do
        if on then
            snd.PlayVoice(ch, 0, 0, 200, 200, 0)
            sys.TimerUsleep(0)
        end
    end
end

local function release(ch)
    if not bound then return end
    playing[ch] = false
    snd.StopVoice(ch)
    snd.FreeVoice(ch)
    bound = nil
end

lv1lua.audio.hooks = {
    resolve = function(name) return lv1lua.dataloc .. "game/" .. name end,

    load = function(path, sourcetype)
        if sourcetype ~= "stream" then return nil end
        return STREAM_CHANNEL
    end,

    play = function(src)
        if not src._handle then return end
        if bound ~= src then
            release(src._handle)
            snd.SetVoice(src._handle, src._path)
            bound = src
        end
        playing[src._handle] = true
    end,
    pause  = function(src) if bound == src then playing[src._handle] = false end end,
    resume = function(src) if bound == src then playing[src._handle] = true  end end,
    stop   = function(src) if bound == src then release(src._handle) end end,

    -- SetVolumeBGMusic is 0-127 and global to the background voice.
    setVolume = function(src, v) snd.SetVolumeBGMusic(math.floor(v * 127 + 0.5)) end,
    isPlaying = function(src)
        return bound == src and playing[src._handle] == true
    end,
}

lv1lua.load("LOVE-WrapLua/core/audio.lua")
