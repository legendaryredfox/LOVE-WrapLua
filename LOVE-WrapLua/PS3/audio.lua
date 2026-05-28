snd.Init()
snd.SetVolumeBGMusic(127)
local _audioplaying = {}
local _masterVolume = 1.0

function lv1lua.playsound()
    for i = 1, #_audioplaying do
        if _audioplaying[i] == 1 then
            snd.PlayVoice(i, 0, 0, 200, 200, 0)
            sys.TimerUsleep(0)
        end
    end
end

function love.audio.newSource(source, sourcetype)
    local ch
    if sourcetype == "stream" then
        ch = 1
        _audioplaying[ch] = 0
        snd.SetVoice(ch, lv1lua.dataloc.."game/"..source)
    end
    local src = {
        channel  = ch,
        type     = sourcetype or "static",
        _volume  = 1.0,
        _looping = false,
    }
    function src:play()       love.audio.play(self) end
    function src:stop()       love.audio.stop(self) end
    function src:pause()      if self.channel then _audioplaying[self.channel] = 0 end end
    function src:resume()     if self.channel then _audioplaying[self.channel] = 1 end end
    function src:getVolume()  return self._volume end
    function src:setVolume(v) self._volume = v end
    function src:setLooping() end
    function src:isPlaying()  return self.channel and (_audioplaying[self.channel] == 1) or false end
    function src:isLooping()  return self._looping end
    function src:isStopped()  return not self:isPlaying() end
    function src:isPaused()   return self.channel and (_audioplaying[self.channel] == 0) or false end
    function src:clone()      return love.audio.newSource(source, sourcetype) end
    function src:seek(pos)    end
    function src:tell()       return 0 end
    function src:getDuration() return 0 end
    function src:getType()    return self.type end
    return src
end

function love.audio.play(source)
    if source.channel then
        _audioplaying[source.channel] = 1
    end
end

function love.audio.stop(source)
    if source then
        if source.channel then
            _audioplaying[source.channel] = 0
            snd.StopVoice(source.channel)
            snd.FreeVoice(source.channel)
        end
    else
        for i = 1, #_audioplaying do
            _audioplaying[i] = 0
        end
    end
end

function love.audio.pause(source)
    if source then
        if source.channel then _audioplaying[source.channel] = 0 end
    else
        for i = 1, #_audioplaying do _audioplaying[i] = 0 end
    end
end

function love.audio.resume(source)
    if source and source.channel then _audioplaying[source.channel] = 1 end
end

function love.audio.getVolume()    return _masterVolume end
function love.audio.setVolume(vol) _masterVolume = vol end

function love.audio.getActiveSourceCount()
    local n = 0
    for _, v in ipairs(_audioplaying) do if v == 1 then n=n+1 end end
    return n
end

function love.audio.getSourceCount()     return love.audio.getActiveSourceCount() end
function love.audio.isEffectsSupported() return false end
