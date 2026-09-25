-- Shared love.audio: one Source object over per-backend native hooks
-- (FIX_PLAN T6.2).
--
-- The three backends carried three near-identical Source tables that all
-- stubbed the same four methods (`seek`, `tell`, `getDuration`, `isPaused`) and
-- disagreed about the rest. The native part is a hook table the backend
-- installs on `lv1lua.audio.hooks` before loading this file:
--
--   resolve(name) -> path        game-relative name to the path the SDK wants
--   load(path, sourcetype)       native handle (nil = the backend cannot load it)
--   play(src) / stop(src) / pause(src) / resume(src)
--   setVolume(src, v)            v is LOVE's 0-1; the backend scales it
--   getVolume(src) -> v          0-1, or nil to use the tracked value
--   isPlaying(src) -> bool       or nil to use the tracked value
--   setLooping(src, bool)        optional
--   seek(src, seconds)           optional; without it seeking only moves the
--                                reported position, see Source:seek
--   tell(src) -> seconds         optional; without it the position is timed
--   duration(src) -> seconds     optional; without it a WAV header is read
--   setPitch(src, p)             optional; tracked either way
--
-- Position: no SDK here reports a playback position, so it is timed from
-- love.timer.getTime() across play/pause/resume/seek. That is accurate for a
-- stream playing straight through (what a music-sync game needs) and it is why
-- `tell` no longer always answers 0.

lv1lua.audio = lv1lua.audio or {}
local hooks  = lv1lua.audio.hooks or {}
lv1lua.audio.hooks = hooks

local sources       = {}
local masterVolume  = 1.0

local function now()
    if love.timer and love.timer.getTime then return love.timer.getTime() end
    return os.time()
end

local function call(name, ...)
    local fn = hooks[name]
    if fn then return fn(...) end
    return nil
end

-- ── Duration from a WAV header ───────────────────────────────────
-- RIFF is the one container we can measure without a decoder: the fmt chunk
-- carries the byte rate and the data chunk its length. Anything else (MP3, OGG)
-- needs the SDK to tell us, and none of them does.
local function readWavDuration(path)
    local ok, f = pcall(io.open, path, "rb")
    if not ok or not f then return nil end
    local header = f:read(44)
    f:close()
    if type(header) ~= "string" or #header < 44 then return nil end
    if header:sub(1, 4) ~= "RIFF" or header:sub(9, 12) ~= "WAVE" then return nil end

    -- Little-endian unsigned integer, without 5.3+ bitwise operators.
    local function u32(at)
        local b1, b2, b3, b4 = header:byte(at, at + 3)
        if not b4 then return nil end
        return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    end

    local byteRate = u32(29)
    local dataSize = u32(41)
    if not byteRate or not dataSize or byteRate == 0 then return nil end
    return dataSize / byteRate
end

-- ── Source ───────────────────────────────────────────────────────
local Source = {}
Source.__index = Source

function Source:type()        return "Source" end
function Source:typeOf(t)     return t == "Source" or t == "Object" end
function Source:getType()     return self._type end
function Source:release()     love.audio.stop(self); return true end

function Source:play()
    if not self._handle then return false end
    self._offset    = 0
    self._startedAt = now()
    self._playing   = true
    self._paused    = false
    call("play", self)
    return true
end

function Source:stop()
    self._offset    = 0
    self._playing   = false
    self._paused    = false
    call("stop", self)
end

function Source:pause()
    if not self._playing then return end
    self._offset  = self:tell()
    self._playing = false
    self._paused  = true
    call("pause", self)
end

function Source:resume()
    if not self._paused then return end
    self._startedAt = now()
    self._playing   = true
    self._paused    = false
    call("resume", self)
end

function Source:isPlaying()
    local native = call("isPlaying", self)
    if native ~= nil then return native end
    return self._playing
end

function Source:isPaused()  return self._paused end
function Source:isStopped() return not self:isPlaying() and not self._paused end

function Source:setVolume(v)
    self._volume = v or 1
    call("setVolume", self, self._volume * masterVolume)
end

function Source:getVolume()
    local native = call("getVolume", self)
    if native ~= nil then return native end
    return self._volume
end

function Source:setLooping(loop)
    self._looping = loop and true or false
    call("setLooping", self, self._looping)
end

function Source:isLooping() return self._looping end

-- LOVE clamps pitch to a positive multiplier. No SDK here resamples, so unless
-- the backend has a native call this only scales the timed position.
function Source:setPitch(p)
    p = tonumber(p) or 1
    if p <= 0 then p = 1 end
    -- Keep the position continuous across the rate change.
    self._offset    = self:tell()
    self._startedAt = now()
    self._pitch     = p
    call("setPitch", self, p)
end

function Source:getPitch() return self._pitch end

function Source:getDuration()
    if self._duration then return self._duration end
    local native = call("duration", self)
    if native and native > 0 then
        self._duration = native
        return native
    end
    self._duration = readWavDuration(self._path) or 0
    return self._duration
end

function Source:tell(unit)
    local pos
    local native = call("tell", self)
    if native ~= nil then
        pos = native
    elseif self._playing then
        pos = self._offset + (now() - self._startedAt) * self._pitch
    else
        pos = self._offset
    end

    local duration = self._duration or 0
    if duration > 0 and pos > duration then
        pos = self._looping and (pos % duration) or duration
    end
    if unit == "samples" then return pos * (self._sampleRate or 44100) end
    return pos
end

-- Without a native seek the audio keeps playing where it was: only the position
-- this object reports moves. Documented in Implemented.md; `seekable` in the
-- capability table says which backends really seek.
function Source:seek(position, unit)
    position = tonumber(position) or 0
    if unit == "samples" then position = position / (self._sampleRate or 44100) end
    self._offset    = position
    self._startedAt = now()
    call("seek", self, position)
end

function Source:clone()
    local copy = love.audio.newSource(self._name, self._type)
    copy:setVolume(self._volume)
    copy:setPitch(self._pitch)
    copy:setLooping(self._looping)
    return copy
end

-- Single-channel console audio: LOVE's spatial API has nothing to drive.
function Source:getChannelCount()  return 1 end
function Source:setPosition()      end
function Source:getPosition()      return 0, 0, 0 end
function Source:setAttenuationDistances() end
function Source:setRelative()      end
function Source:isRelative()       return true end

lv1lua.audio.Source = Source

-- ── love.audio ───────────────────────────────────────────────────
function love.audio.newSource(name, sourcetype)
    sourcetype = sourcetype or "static"
    local path = call("resolve", name) or name

    local src = setmetatable({
        _name      = name,
        _path      = path,
        _type      = sourcetype,
        _handle    = nil,
        _volume    = 1.0,
        _pitch     = 1.0,
        _looping   = false,
        _playing   = false,
        _paused    = false,
        _offset    = 0,
        _startedAt = 0,
    }, Source)

    src._handle = call("load", path, sourcetype)
    -- `loadsound` is the name the older per-backend sources used; game code and
    -- the whileloops still read it.
    src.loadsound = src._handle

    sources[#sources + 1] = src
    return src
end

function love.audio.play(source)
    if source then return source:play() end
    for _, s in ipairs(sources) do s:play() end
end

function love.audio.stop(source)
    if source then return source:stop() end
    for _, s in ipairs(sources) do s:stop() end
end

function love.audio.pause(source)
    if source then return source:pause() end
    local paused = {}
    for _, s in ipairs(sources) do
        if s:isPlaying() then
            s:pause()
            paused[#paused + 1] = s
        end
    end
    return paused
end

function love.audio.resume(source)
    if source then return source:resume() end
    for _, s in ipairs(sources) do s:resume() end
end

function love.audio.setVolume(v)
    masterVolume = v or 1
    for _, s in ipairs(sources) do
        call("setVolume", s, s._volume * masterVolume)
    end
end

function love.audio.getVolume() return masterVolume end

function love.audio.getActiveSourceCount()
    local n = 0
    for _, s in ipairs(sources) do
        if s:isPlaying() then n = n + 1 end
    end
    return n
end

function love.audio.getSourceCount()     return love.audio.getActiveSourceCount() end
function love.audio.isEffectsSupported() return false end
function love.audio.getMaxSourceEffects()  return 0 end
function love.audio.getMaxSceneEffects()   return 0 end

-- Listener API: mono console output, nothing to place.
function love.audio.setPosition()    end
function love.audio.getPosition()    return 0, 0, 0 end
function love.audio.setOrientation() end
function love.audio.getOrientation() return 0, 0, -1, 0, 1, 0 end
function love.audio.setDistanceModel() end
function love.audio.getDistanceModel() return "none" end

-- Test/reset hook: drops the registry so a fresh backend starts empty.
function lv1lua.audio.reset()
    sources      = {}
    masterVolume = 1.0
end
