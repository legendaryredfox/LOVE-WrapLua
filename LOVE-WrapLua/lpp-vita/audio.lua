Sound.init()
local _masterVolume = 1.0
local _sources      = {}

function love.audio.newSource(source, sourcetype)
    local snd = Sound.open(lv1lua.dataloc.."game/"..source)
    local src = {
        loadsound = snd,
        type      = sourcetype or "static",
        _volume   = 1.0,
        _looping  = false,
    }
    function src:play()   if self.loadsound then love.audio.play(self) end end
    function src:stop()   if self.loadsound then love.audio.stop(self) end end
    function src:pause()  if self.loadsound then Sound.pause(self.loadsound) end end
    function src:resume() if self.loadsound then Sound.play(self.loadsound, self._looping) end end
    function src:getVolume()
        if self.loadsound then return Sound.getVolume(self.loadsound) / 32767 end
        return self._volume
    end
    function src:setVolume(vol)
        self._volume = vol
        if self.loadsound then Sound.setVolume(self.loadsound, vol * 32767) end
    end
    function src:setLooping(loop) self._looping = loop end
    function src:isPlaying()
        if self.loadsound then return Sound.isPlaying(self.loadsound) end
        return false
    end
    function src:isLooping()   return self._looping end
    function src:isStopped()   return not self:isPlaying() end
    function src:isPaused()    return false end
    function src:clone()       return love.audio.newSource(source, sourcetype) end
    function src:seek(pos)     end
    function src:tell()        return 0 end
    function src:getDuration() return 0 end
    function src:getType()     return self.type end
    _sources[#_sources+1] = src
    return src
end

function love.audio.play(source)
    if not source.loop then source.loop = false end
    Sound.play(source.loadsound, source._looping)
end

function love.audio.stop(source)
    if source then
        Sound.pause(source.loadsound)
        Sound.close(source.loadsound)
    else
        for _, src in ipairs(_sources) do
            if src.loadsound then Sound.pause(src.loadsound) end
        end
    end
end

function love.audio.pause(source)
    if source then
        Sound.pause(source.loadsound)
    else
        for _, src in ipairs(_sources) do
            if src.loadsound and Sound.isPlaying(src.loadsound) then
                Sound.pause(src.loadsound)
            end
        end
    end
end

function love.audio.resume(source)
    if source then
        Sound.play(source.loadsound, source._looping)
    end
end

function love.audio.getVolume()    return _masterVolume end
function love.audio.setVolume(vol) _masterVolume = vol end

function love.audio.getActiveSourceCount()
    local n = 0
    for _, src in ipairs(_sources) do
        if src.loadsound and Sound.isPlaying(src.loadsound) then n=n+1 end
    end
    return n
end

function love.audio.getSourceCount()        return love.audio.getActiveSourceCount() end
function love.audio.isEffectsSupported()    return false end
