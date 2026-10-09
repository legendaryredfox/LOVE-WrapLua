local desAnim8 = {
    _VERSION     = 'desAnim8 v0.5.0',
    _DESCRIPTION = 'An animation library for LÖVE 11.5 games',
    _URL         = 'https://github.com/legendaryredfox/desAnim8',
    _THANKS      = 'All thanks, recognition and incentives should go to https://github.com/kikito',
    _LICENSE     = [[
      MIT LICENSE

      Copyright (c) 2024 Legendary Redfox

      Permission is hereby granted, free of charge, to any person obtaining a
      copy of this software and associated documentation files (the
      "Software"), to deal in the Software without restriction, including
      without limitation the rights to use, copy, modify, merge, publish,
      distribute, sublicense, and/or sell copies of the Software, and to
      permit persons to whom the Software is furnished to do so, subject to
      the following conditions:

      The above copyright notice and this permission notice shall be included
      in all copies or substantial portions of the Software.

      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
      OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
      MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
      IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
      CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
      TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
      SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    ]]
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- `level` arguments below follow error(): the number of stack frames from the
-- raising function up to the user's call, so messages point at user code.

local function assertPositiveInteger(value, name, level)
    if type(value) ~= 'number' or value < 1 or value == math.huge or value ~= math.floor(value) then
        error(('%s must be a positive integer, got %s'):format(name, tostring(value)), level)
    end
end

local function assertNonNegativeInteger(value, name, level)
    if type(value) ~= 'number' or value < 0 or value == math.huge or value ~= math.floor(value) then
        error(('%s must be a non-negative integer, got %s'):format(name, tostring(value)), level)
    end
end

-- Binary search: find i such that intervals[i] <= t < intervals[i+1].
-- Correctly returns the last index when t == totalDuration.
local function seekIndex(intervals, t)
    local low, high, i = 1, #intervals - 1, 1
    while low <= high do
        i = math.floor((low + high) / 2)
        if     t >= intervals[i + 1] then low  = i + 1
        elseif t <  intervals[i]     then high = i - 1
        else   break
        end
    end
    return i
end

-- Returns (from, to, step) with no table allocation.
-- Accepts a number, a "n" string, or a "n-m" range string (spaces ignored).
-- `what` names the argument in error messages.
local function parseRange(v, max, level, what)
    if v == nil then
        error(('missing %s argument: ranges come in (columns, rows) pairs'):format(what), level)
    end
    local a, b
    if type(v) == 'number' then
        if v ~= math.floor(v) then
            error(('%s must be an integer, got %s'):format(what, tostring(v)), level)
        end
        a, b = v, v
    else
        local s = tostring(v):gsub('%s+', '')
        local x, y = s:match('^(%d+)-(%d+)$')
        if x then
            a, b = tonumber(x), tonumber(y)
        else
            a = tonumber(s:match('^(%d+)$'))
            b = a
        end
        if not a then
            error(('invalid %s %q, expected a number or "n-m"'):format(what, tostring(v)), level)
        end
    end
    if a < 1 or a > max or b < 1 or b > max then
        error(('%s %s out of range [1,%d]'):format(what, tostring(v), max), level)
    end
    return a, b, a <= b and 1 or -1
end

-- ── Grid ──────────────────────────────────────────────────────────────────────

local Grid = {}
Grid.__index = Grid

-- newGrid(frameWidth, frameHeight, imageWidth, imageHeight [, left, top, border])
-- border: pixel gap around every frame in the spritesheet (default 0). Like
-- anim8, one border precedes the first frame as well as separating frames.
function desAnim8.newGrid(frameWidth, frameHeight, imageWidth, imageHeight, left, top, border)
    assertPositiveInteger(frameWidth,  'frameWidth',  3)
    assertPositiveInteger(frameHeight, 'frameHeight', 3)
    assertPositiveInteger(imageWidth,  'imageWidth',  3)
    assertPositiveInteger(imageHeight, 'imageHeight', 3)
    left, top, border = left or 0, top or 0, border or 0
    assertNonNegativeInteger(left,   'left',   3)
    assertNonNegativeInteger(top,    'top',    3)
    assertNonNegativeInteger(border, 'border', 3)
    return setmetatable({
        frameWidth  = frameWidth,
        frameHeight = frameHeight,
        imageWidth  = imageWidth,
        imageHeight = imageHeight,
        left        = left,
        top         = top,
        border      = border,
        cols        = math.max(0, math.floor((imageWidth  - left - border) / (frameWidth  + border))),
        rows        = math.max(0, math.floor((imageHeight - top  - border) / (frameHeight + border))),
    }, Grid)
end

-- getFrames(colRange, rowRange [, colRange, rowRange ...])
-- Each pair selects a rectangle of frames in row-major order.
-- Returns a list of love.graphics.newQuad objects.
function Grid:getFrames(...)
    local count  = select('#', ...)
    local args   = { ... }
    local frames = {}
    local fw, fh, bw = self.frameWidth, self.frameHeight, self.border
    local iw, ih     = self.imageWidth, self.imageHeight
    local i = 1
    while i <= count do
        local cmin, cmax, cstep = parseRange(args[i],     self.cols, 3, 'column')
        local rmin, rmax, rstep = parseRange(args[i + 1], self.rows, 3, 'row')
        i = i + 2
        for row = rmin, rmax, rstep do
            for col = cmin, cmax, cstep do
                local x = self.left + (col - 1) * (fw + bw) + bw
                local y = self.top  + (row - 1) * (fh + bw) + bw
                frames[#frames + 1] = love.graphics.newQuad(x, y, fw, fh, iw, ih)
            end
        end
    end
    if #frames == 0 then error('getFrames: no frames selected', 2) end
    return frames
end

Grid.__call = Grid.getFrames

-- ── Duration handling ─────────────────────────────────────────────────────────

local function assertDuration(dur, what, level)
    if type(dur) ~= 'number' or not (dur > 0) or dur == math.huge then
        error(('%s must be a positive number, got %s'):format(what, tostring(dur)), level)
    end
end

-- durations can be:
--   number              -> same duration for every frame
--   {d1, d2, ...}       -> per-frame array
--   {['2-4'] = 0.2, ..} -> range-keyed table
local function parseDurations(durations, frameCount, level)
    if type(durations) == 'number' then
        assertDuration(durations, 'frameDuration', level + 1)
        local t = {}
        for i = 1, frameCount do t[i] = durations end
        return t
    end
    if type(durations) ~= 'table' then
        error('durations must be a positive number or a table', level)
    end
    local result = {}
    for key, dur in pairs(durations) do
        assertDuration(dur, ('duration for key %q'):format(tostring(key)), level + 1)
        local from, to, step = parseRange(key, frameCount, level + 1, 'durations key')
        for k = from, to, step do
            if result[k] then
                error(('durations: frame %d is assigned more than once (key %q)'):format(k, tostring(key)), level)
            end
            result[k] = dur
        end
    end
    for i = 1, frameCount do
        if not result[i] then error(('no duration specified for frame %d'):format(i), level) end
    end
    return result
end

local function buildIntervals(durations)
    local t, intervals = 0, { 0 }
    for i = 1, #durations do
        t = t + durations[i]
        intervals[i + 1] = t
    end
    return intervals, t
end

-- ── Sequence (encodes play mode as a frame-index list) ────────────────────────

local VALID_MODES  = { loop=true, once=true, bounce=true, bounceOnce=true }
local PAUSE_AT_END = { once=true, bounceOnce=true }

-- Expand play mode into a flat sequence of frame indices:
--   loop/once      -> [1, 2, ..., n]
--   bounce         -> [1, 2, ..., n, n-1, ..., 2]   endpoints appear once
--   bounceOnce     -> [1, 2, ..., n, n-1, ..., 1]
local function buildSequence(n, playMode)
    if n == 1 then return { 1 } end
    local seq = {}
    if playMode == 'loop' or playMode == 'once' then
        for i = 1, n do seq[i] = i end
    elseif playMode == 'bounce' then
        for i = 1, n         do seq[#seq + 1] = i end
        for i = n - 1, 2, -1 do seq[#seq + 1] = i end
    else -- bounceOnce
        for i = 1, n         do seq[#seq + 1] = i end
        for i = n - 1, 1, -1 do seq[#seq + 1] = i end
    end
    return seq
end

local function initTiming(self)
    local seq    = buildSequence(#self.frames, self.playMode)
    local seqDur = {}
    for i, fi in ipairs(seq) do seqDur[i] = self._durations[fi] end
    local intervals, total = buildIntervals(seqDur)
    self._seq           = seq
    self._intervals     = intervals
    self._totalDuration = total
    self._timer         = 0
    self._position      = 1
    self.currentFrame   = seq[1]
    self.status         = 'playing'
end

-- ── Animation ─────────────────────────────────────────────────────────────────

-- Instances get their own class table so they do not inherit the module's
-- constructors and metadata.
local Animation = {}
Animation.__index = Animation

local USAGE = 'desAnim8.new: expected (image, frames, durations [, playMode]) or the legacy ' ..
    '(image, frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight [, playMode]); ' ..
    'for an animation without an image use desAnim8.newAnimation(frames, durations [, playMode])'

-- Legacy single-row form. Returns the frame list, durations and play mode.
-- Called from desAnim8.new, so the user's call is 3 frames up (4 from a helper).
local function legacyArgs(...)
    local fw, fh, n, dur, iw, ih, mode = ...
    if type(fw) ~= 'number' or select('#', ...) < 3 then error(USAGE, 3) end
    assertPositiveInteger(fw, 'frameWidth',  4)
    assertPositiveInteger(fh, 'frameHeight', 4)
    assertPositiveInteger(n,  'numFrames',   4)
    assertPositiveInteger(iw, 'imageWidth',  4)
    assertPositiveInteger(ih, 'imageHeight', 4)
    local frames = {}
    for i = 0, n - 1 do
        frames[#frames + 1] = love.graphics.newQuad(i * fw, 0, fw, fh, iw, ih)
    end
    return frames, dur, mode
end

-- Called from desAnim8.new / newAnimation, so the user's call is 3 frames up.
local function build(image, frames, durations, playMode)
    if type(frames) ~= 'table' then
        error('frames must be a list of quads, e.g. from grid(\'1-4\', 1)', 3)
    end
    if #frames == 0 then error('desAnim8.new: frames list is empty', 3) end
    playMode = playMode or 'loop'
    if not VALID_MODES[playMode] then
        error(('desAnim8.new: unknown play mode %s; expected \'loop\', \'once\', \'bounce\' or \'bounceOnce\' ' ..
            '(callbacks go in the onLoop field: anim.onLoop = fn)'):format(
            type(playMode) == 'string' and ('%q'):format(playMode) or tostring(playMode)), 3)
    end

    local self = setmetatable({}, Animation)
    self.image    = image
    self.flippedH = false
    self.flippedV = false
    self.onLoop   = nil
    self.playMode = playMode
    -- Copied so later changes to the caller's list cannot desync the timing data.
    self.frames   = {}
    for i = 1, #frames do self.frames[i] = frames[i] end
    self._durations = parseDurations(durations, #self.frames, 4)

    initTiming(self)
    return self
end

-- New API:    new(image, frames, durations [, playMode])
--             frames is a list of Quads, typically from Grid:getFrames()
-- Legacy API: new(image, frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight [, playMode])
-- image may be nil: the image is then supplied at draw time (see newAnimation
-- and :draw), so one animation can be reused across several images and the
-- library never has to hold a backend's image handle.
function desAnim8.new(image, ...)
    local frames, durations, playMode
    if type((...)) == 'table' then
        frames, durations, playMode = ...
    else
        frames, durations, playMode = legacyArgs(...)
    end
    local anim = build(image, frames, durations, playMode)
    return anim
end

-- Image-less constructor. Equivalent to new(nil, frames, durations, playMode);
-- the image is passed to :draw at render time.
function desAnim8.newAnimation(frames, durations, playMode)
    local anim = build(nil, frames, durations, playMode)
    return anim
end

function Animation:update(dt)
    if type(dt) ~= 'number' then
        error(('update: dt must be a number, got %s'):format(type(dt)), 2)
    end
    -- Also rejects NaN, which would otherwise poison the timer permanently.
    if self.status ~= 'playing' or not (dt > 0) or dt == math.huge then return end

    self._timer = self._timer + dt
    local loops = math.floor(self._timer / self._totalDuration)
    if loops ~= 0 then
        self._timer = self._timer - self._totalDuration * loops
        if PAUSE_AT_END[self.playMode] then
            self:pauseAtEnd()
        end
        local cb = self.onLoop
        if type(cb) == 'string' then
            local method = self[cb]
            if type(method) ~= 'function' then
                error(('onLoop: animation has no method %q'):format(cb), 2)
            end
            cb = method
        end
        if cb ~= nil then
            if type(cb) ~= 'function' then
                error('onLoop must be a function or a method name', 2)
            end
            cb(self, loops)
        end
    end

    self._position    = seekIndex(self._intervals, self._timer)
    self.currentFrame = self._seq[self._position]
end

-- Returns the quad and all love.graphics.draw transform parameters, with flip
-- adjustments applied. Use this when you need to draw with extra transforms, or
-- to add the animation to a SpriteBatch.
function Animation:getFrameInfo(x, y, r, sx, sy, ox, oy, kx, ky)
    local frame = self.frames[self.currentFrame]
    if self.flippedH or self.flippedV then
        r,  sx = r or 0, sx or 1
        sy     = sy or sx -- love.graphics.draw defaults sy to sx
        ox, oy = ox or 0, oy or 0
        kx, ky = kx or 0, ky or 0
        local _, _, w, h = frame:getViewport()
        if self.flippedH then
            sx = -sx
            ox = w - ox
            kx = -kx
            ky = -ky
        end
        if self.flippedV then
            sy = -sy
            oy = h - oy
            kx = -kx
            ky = -ky
        end
    end
    return frame, x, y, r, sx, sy, ox, oy, kx, ky
end

-- With a bound image:    anim:draw(x, y [, r, sx, sy, ox, oy, kx, ky])
-- Without one (image=nil): anim:draw(image, x, y [, ...]) -- the leading
-- argument is the image to draw onto.
function Animation:draw(a, b, ...)
    if self.image ~= nil then
        if type(a) ~= 'number' then
            error('draw: this animation has an image bound; call anim:draw(x, y [, ...]) without the image', 2)
        end
        love.graphics.draw(self.image, self:getFrameInfo(a, b, ...))
    else
        if a == nil or type(a) == 'number' then
            error('draw: no image bound; call anim:draw(image, x, y [, ...])', 2)
        end
        love.graphics.draw(a, self:getFrameInfo(b, ...))
    end
end

-- Returns the current 1-based frame index and its Quad.
function Animation:getCurrentFrame()
    return self.currentFrame, self.frames[self.currentFrame]
end

function Animation:getDimensions()
    local _, _, w, h = self.frames[self.currentFrame]:getViewport()
    return w, h
end

function Animation:getFrameCount()
    return #self.frames
end

-- Length in seconds of one full play-through. For 'bounce' modes that includes
-- the return trip.
function Animation:getDuration()
    return self._totalDuration
end

function Animation:getPlayMode()
    return self.playMode
end

-- Toggle horizontal flip. Returns self so calls can be chained.
function Animation:flipH()
    self.flippedH = not self.flippedH
    return self
end

-- Toggle vertical flip. Returns self so calls can be chained.
function Animation:flipV()
    self.flippedV = not self.flippedV
    return self
end

-- Absolute flip setters; safe to call every frame, unlike the toggles.
function Animation:setFlipH(flipped)
    if type(flipped) ~= 'boolean' then error('setFlipH: expected a boolean', 2) end
    self.flippedH = flipped
    return self
end

function Animation:setFlipV(flipped)
    if type(flipped) ~= 'boolean' then error('setFlipV: expected a boolean', 2) end
    self.flippedV = flipped
    return self
end

function Animation:pause()
    self.status = 'paused'
end

-- Does nothing once a 'once'/'bounceOnce' animation has finished (it would only
-- re-fire onLoop); use reset() or gotoFrame() to play it again.
function Animation:resume()
    if PAUSE_AT_END[self.playMode] and self._timer >= self._totalDuration then return end
    self.status = 'playing'
end

-- "End" is the last entry of the play sequence: the last frame for loop and
-- once, frame 2 for bounce (the frame before the cycle repeats) and frame 1
-- for bounceOnce.
function Animation:pauseAtEnd()
    self._position    = #self._seq
    self._timer       = self._totalDuration
    self.currentFrame = self._seq[self._position]
    self.status       = 'paused'
end

function Animation:pauseAtStart()
    self._position    = 1
    self._timer       = 0
    self.currentFrame = self._seq[1]
    self.status       = 'paused'
end

-- Alias for pauseAtStart (backward compat).
function Animation:stop()
    self:pauseAtStart()
end

function Animation:reset()
    self._position    = 1
    self._timer       = 0
    self.currentFrame = self._seq[1]
    self.status       = 'playing'
end

function Animation:gotoFrame(n)
    if type(n) ~= 'number' or n ~= math.floor(n) then
        error(('gotoFrame: frame must be an integer, got %s'):format(tostring(n)), 2)
    end
    if n < 1 or n > #self.frames then
        error(('gotoFrame: %d out of range [1,%d]'):format(n, #self.frames), 2)
    end
    for i, fi in ipairs(self._seq) do
        if fi == n then
            self._position    = i
            self._timer       = self._intervals[i]
            self.currentFrame = n
            return
        end
    end
end

function Animation:isPlaying()
    return self.status == 'playing'
end

function Animation:isPaused()
    return self.status == 'paused'
end

-- Returns a new animation sharing the same immutable data (frames, durations,
-- sequence, intervals). Playback state starts fresh; flip and onLoop are copied.
function Animation:clone()
    local c = setmetatable({}, Animation)
    for k, v in pairs(self) do c[k] = v end
    c._timer       = 0
    c._position    = 1
    c.currentFrame = c._seq[1]
    c.status       = 'playing'
    return c
end

return desAnim8
