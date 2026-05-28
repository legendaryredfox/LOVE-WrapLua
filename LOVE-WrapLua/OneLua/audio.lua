local _channel1     = nil
local _channel2     = nil
local _masterVolume = 1.0

local function _convertExt(source)
    local first, last = string.find(source, "%.%a+$")
    if not first then return source end
    local ext = string.lower(string.sub(source, first+1, last))
    if ext == "wav" or ext == "wma" or ext == "m4a" or ext == "3gp" or ext == "ogg" then
        return string.sub(source, 1, first) .. "mp3"
    end
    return source
end

function love.audio.newSource(source, sourcetype)
    local snd = sound.load(_convertExt(lv1lua.dataloc.."game/"..source))
    local src = {
        loadsound = snd,
        type      = sourcetype or "static",
        _volume   = 1.0,
        _looping  = false,
    }
    function src:play()        if self.loadsound then love.audio.play(self) end end
    function src:stop()        if self.loadsound then love.audio.stop(self) end end
    function src:pause()       if self.loadsound then love.audio.pause(self, 1) end end
    function src:resume()      if self.loadsound then love.audio.pause(self, 0) end end
    function src:getVolume()
        if self.loadsound then return sound.vol(self.loadsound) / 100 end
        return self._volume
    end
    function src:setVolume(vol)
        self._volume = vol
        if self.loadsound then sound.vol(self.loadsound, vol * 100) end
    end
    function src:setLooping(loop)
        self._looping = loop
        if self.loadsound and sound.looping(self.loadsound) ~= loop then
            sound.loop(self.loadsound)
        end
    end
    function src:isPlaying()
        if self.loadsound then return sound.playing(self.loadsound) end
        return false
    end
    function src:isLooping()   return self._looping end
    function src:isStopped()   return not self:isPlaying() end
    function src:isPaused()    return false end  -- OneLua has no paused state query
    function src:clone()       return love.audio.newSource(source, sourcetype) end
    function src:seek(pos)     end  -- not available in OneLua
    function src:tell()        return 0 end
    function src:getDuration() return 0 end
    function src:getType()     return self.type end
    return src
end

-- OneLua: only 2 channels (1=static/sfx, 2=stream/bgm)
function love.audio.play(source)
    if source.type == "static" then
        _channel1 = source
        sound.play(source.loadsound, 1)
    else
        _channel2 = source
        sound.play(source.loadsound, 2)
    end
end

function love.audio.stop(source)
    if source then
        if source == _channel1 then _channel1 = nil
        elseif source == _channel2 then _channel2 = nil end
        sound.stop(source.loadsound)
    else
        if _channel1 then sound.stop(_channel1.loadsound); _channel1 = nil end
        if _channel2 then sound.stop(_channel2.loadsound); _channel2 = nil end
    end
end

-- mode: 1=pause, 0=resume, -1=toggle
function love.audio.pause(source, mode)
    mode = mode == nil and 1 or mode
    if source == nil then
        if _channel1 then sound.pause(_channel1.loadsound, mode) end
        if _channel2 then sound.pause(_channel2.loadsound, mode) end
    else
        sound.pause(source.loadsound, mode)
    end
end

function love.audio.resume(source)
    love.audio.pause(source, 0)
end

function love.audio.getVolume()
    return _masterVolume
end

function love.audio.setVolume(vol)
    _masterVolume = vol
    if _channel1 then sound.vol(_channel1.loadsound, vol * 100) end
    if _channel2 then sound.vol(_channel2.loadsound, vol * 100) end
end

function love.audio.getActiveSourceCount()
    local n = 0
    if _channel1 and sound.playing(_channel1.loadsound) then n=n+1 end
    if _channel2 and sound.playing(_channel2.loadsound) then n=n+1 end
    return n
end

function love.audio.getSourceCount() return love.audio.getActiveSourceCount() end

function love.audio.isEffectsSupported() return false end
