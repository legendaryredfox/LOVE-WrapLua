local desAnim8 = {
    _VERSION     = 'desAnim8 v0.1.0',
    _DESCRIPTION = 'A backend-independent animation library for LOVE-WrapLua',
    _URL         = 'https://github.com/legendaryredfox/desAnim8',
    _THANKS      = [[
        Modelled on kikito's anim8 (https://github.com/kikito/anim8).
    ]],
    _LICENSE     = [[
      MIT LICENSE

      Copyright (c) 2024

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

-- Design notes
-- ------------
-- The library talks only to the public love.graphics.* surface (newQuad and
-- draw(image, quad, ...)), never to a backend's native image data. That makes
-- it reusable on every LOVE-WrapLua target (OneLua/Vita, PSP, lpp-vita, PS3).
--
-- It is split into two self-contained units:
--   * Grid      — turns a spritesheet layout into love quads.
--   * Animation — plays a list of quads back over time.
-- Neither keeps shared mutable module state; each Grid owns its own frame cache.

local function assertPositiveInteger(value, name)
    if type(value) ~= 'number' then
        error(("%s should be a number, was %q"):format(name, tostring(value)))
    end
    if value < 1 then
        error(("%s should be a positive number, was %s"):format(name, tostring(value)))
    end
    if value ~= math.floor(value) then
        error(("%s should be an integer, was %s"):format(name, tostring(value)))
    end
end

-- Parses "min-max" (or a bare number) into min, max, step.
local function parseInterval(str)
    if type(str) == 'number' then return str, str, 1 end
    str = str:gsub('%s', '')
    local min, max = str:match('^(%-?%d+)-(%-?%d+)$')
    assert(min and max, ("Could not parse interval from %q"):format(str))
    min, max = tonumber(min), tonumber(max)
    local step = min <= max and 1 or -1
    return min, max, step
end

-- ── Grid ─────────────────────────────────────────────────────────
local Grid = {}
Grid.__index = Grid

local function newGrid(frameWidth, frameHeight, imageWidth, imageHeight, left, top, border)
    assertPositiveInteger(frameWidth,  'frameWidth')
    assertPositiveInteger(frameHeight, 'frameHeight')
    assertPositiveInteger(imageWidth,  'imageWidth')
    assertPositiveInteger(imageHeight, 'imageHeight')

    return setmetatable({
        frameWidth  = frameWidth,
        frameHeight = frameHeight,
        imageWidth  = imageWidth,
        imageHeight = imageHeight,
        left        = left   or 0,
        top         = top    or 0,
        border      = border or 0,
        width       = math.floor(imageWidth  / frameWidth),
        height      = math.floor(imageHeight / frameHeight),
        _cache      = {},  -- [x][y] -> quad, owned by this grid
    }, Grid)
end

function Grid:_createFrame(x, y)
    local fw, fh = self.frameWidth, self.frameHeight
    return love.graphics.newQuad(
        self.left + (x - 1) * fw + x * self.border,
        self.top  + (y - 1) * fh + y * self.border,
        fw, fh,
        self.imageWidth, self.imageHeight
    )
end

function Grid:_frame(x, y)
    if x < 1 or x > self.width or y < 1 or y > self.height then
        error(("There is no frame for x=%d, y=%d"):format(x, y))
    end
    local col = self._cache[x]
    if not col then col = {}; self._cache[x] = col end
    if not col[y] then col[y] = self:_createFrame(x, y) end
    return col[y]
end

-- grid:getFrames('1-6', 1) or grid('1-6', 1) -> list of quads.
function Grid:getFrames(...)
    local result, args = {}, {...}
    for i = 1, #args, 2 do
        local minx, maxx, stepx = parseInterval(args[i])
        local miny, maxy, stepy = parseInterval(args[i + 1])
        for y = miny, maxy, stepy do
            for x = minx, maxx, stepx do
                result[#result + 1] = self:_frame(x, y)
            end
        end
    end
    return result
end

Grid.__call = Grid.getFrames

-- ── Animation ────────────────────────────────────────────────────
local Animation = {}
Animation.__index = Animation

local function cloneArray(arr)
    local result = {}
    for i = 1, #arr do result[i] = arr[i] end
    return result
end

-- Expands a per-frame duration spec (a number, or a { ['min-max']=dur } table)
-- into one duration per frame.
local function parseDurations(durations, frameCount)
    local result = {}
    if type(durations) == 'number' then
        for i = 1, frameCount do result[i] = durations end
    else
        for key, duration in pairs(durations) do
            assert(type(duration) == 'number',
                   'Duration [' .. tostring(duration) .. '] should be a number')
            local min, max, step = parseInterval(key)
            for i = min, max, step do result[i] = duration end
        end
    end
    if #result < frameCount then
        error(('The durations table has length %d, but should be >= %d')
              :format(#result, frameCount))
    end
    return result
end

-- Cumulative start time of each frame, plus the total loop length.
local function parseIntervals(durations)
    local result, time = {0}, 0
    for i = 1, #durations do
        time = time + durations[i]
        result[i + 1] = time
    end
    return result, time
end

local function seekFrameIndex(intervals, timer)
    local high, low, i = #intervals - 1, 1, 1
    while low <= high do
        i = math.floor((low + high) / 2)
        if     timer >= intervals[i + 1] then low  = i + 1
        elseif timer <  intervals[i]     then high = i - 1
        else   return i end
    end
    return i
end

local nop = function() end

-- newAnimation(frames, durations [, onLoop])
--   frames    : list of quads (e.g. from a Grid)
--   durations : a number, or a { ['1-3']=0.1, ['4']=0.5 } table
--   onLoop    : optional. Either
--                 * a function(self, loops)  called every time the loop wraps,
--                 * a method name string ('pauseAtEnd' / 'pauseAtStart'), or
--                 * a table { once = true, onComplete = fn } for a play-once
--                   animation that stops on the last frame and fires fn exactly
--                   once.
local function newAnimation(frames, durations, onLoop)
    local td = type(durations)
    if (td ~= 'number' or durations <= 0) and td ~= 'table' then
        error('durations must be a positive number or a table. Was ' .. tostring(durations))
    end

    local once, onComplete = false, nil
    if type(onLoop) == 'table' then
        once, onComplete = onLoop.once and true or false, onLoop.onComplete
        onLoop = nil
    end
    onLoop = onLoop or nop

    durations = parseDurations(durations, #frames)
    local intervals, totalDuration = parseIntervals(durations)

    return setmetatable({
        frames        = cloneArray(frames),
        durations     = durations,
        intervals     = intervals,
        totalDuration = totalDuration,
        onLoop        = onLoop,
        once          = once,
        onComplete    = onComplete or nop,
        _completed    = false,
        timer         = 0,
        position      = 1,
        status        = 'playing',
        flippedH      = false,
        flippedV      = false,
    }, Animation)
end

function Animation:clone()
    local other = newAnimation(self.frames, self.durations, self.onLoop)
    other.flippedH, other.flippedV = self.flippedH, self.flippedV
    other.once       = self.once
    other.onComplete = self.onComplete
    return other
end

function Animation:flipH() self.flippedH = not self.flippedH; return self end
function Animation:flipV() self.flippedV = not self.flippedV; return self end

function Animation:update(dt)
    if self.status ~= 'playing' then return end

    self.timer = self.timer + dt
    local loops = math.floor(self.timer / self.totalDuration)

    if loops ~= 0 then
        if self.once then
            -- Play once: stop on the last frame and fire onComplete a single
            -- time (anim8 issue #48).
            self.timer    = self.totalDuration
            self.position = #self.frames
            self.status   = 'paused'
            if not self._completed then
                self._completed = true
                self.onComplete(self)
            end
            return
        end
        self.timer = self.timer - self.totalDuration * loops
        local f = type(self.onLoop) == 'function' and self.onLoop or self[self.onLoop]
        f(self, loops)
    end

    self.position = seekFrameIndex(self.intervals, self.timer)
end

function Animation:pause()  self.status = 'paused'  end
function Animation:resume() self.status = 'playing' end

function Animation:gotoFrame(position)
    self.position = position
    self.timer    = self.intervals[position]
end

function Animation:pauseAtEnd()
    self.position = #self.frames
    self.timer    = self.totalDuration
    self:pause()
end

function Animation:pauseAtStart()
    self.position = 1
    self.timer    = 0
    self:pause()
end

-- Current frame index (anim8 issue #33). Second return is the quad itself.
function Animation:getCurrentFrame()
    return self.position, self.frames[self.position]
end

function Animation:getDimensions()
    local _, _, w, h = self.frames[self.position]:getViewport()
    return w, h
end

-- Applies flip state to the draw arguments, so a flipped clone renders
-- independently of the original (anim8 issue #44) without mutating any image.
function Animation:getFrameInfo(x, y, r, sx, sy, ox, oy, kx, ky)
    local frame = self.frames[self.position]
    if self.flippedH or self.flippedV then
        r, sx, sy = r or 0, sx or 1, sy or 1
        ox, oy, kx, ky = ox or 0, oy or 0, kx or 0, ky or 0
        local _, _, w, h = frame:getViewport()
        if self.flippedH then
            sx = -sx; ox = w - ox; kx = -kx; ky = -ky
        end
        if self.flippedV then
            sy = -sy; oy = h - oy; kx = -kx; ky = -ky
        end
    end
    return frame, x, y, r, sx, sy, ox, oy, kx, ky
end

function Animation:draw(image, x, y, r, sx, sy, ox, oy, kx, ky)
    love.graphics.draw(image, self:getFrameInfo(x, y, r, sx, sy, ox, oy, kx, ky))
end

-- ── Public API ───────────────────────────────────────────────────
desAnim8.newGrid      = newGrid
desAnim8.newAnimation = newAnimation

-- Backwards-compatible shim for the old single-strip constructor used by
-- game/main.lua: desAnim8.new(image, fw, fh, numFrames, frameDuration, iw, ih).
-- Returns an object that remembers its image, so :draw(x, y, ...) still works.
function desAnim8.new(image, frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight)
    imageWidth  = imageWidth  or (image.getWidth  and image:getWidth())  or (frameWidth  * numFrames)
    imageHeight = imageHeight or (image.getHeight and image:getHeight()) or frameHeight
    local grid   = newGrid(frameWidth, frameHeight, imageWidth, imageHeight)
    local frames = grid('1-' .. numFrames, 1)
    local anim   = newAnimation(frames, frameDuration)

    return setmetatable({
        image     = image,
        animation = anim,
    }, {
        __index = function(self, key)
            local v = anim[key]
            if type(v) == 'function' then
                -- draw is special: it needs the stored image prepended.
                if key == 'draw' then
                    return function(_, x, y, r, sx, sy, ox, oy, kx, ky)
                        anim:draw(self.image, x, y, r, sx, sy, ox, oy, kx, ky)
                    end
                end
                return function(_, ...) return v(anim, ...) end
            end
            return v
        end,
    })
end

return desAnim8
