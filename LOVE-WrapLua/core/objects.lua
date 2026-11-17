-- Shared graphics objects: Canvas, Shader, SpriteBatch, Text/TextBatch.
--
-- None of these need native calls: they are pure Lua over the public
-- love.graphics surface (draw / print / printf / setFont), so one copy serves
-- every backend and a backend only has to implement the native primitives.
--
-- Requires: lv1lua.current (from the backend's state.lua) and
-- lv1lua.screenWidth/Height (from core/runtime.lua).

-- `unpack` is a global in Lua 5.1/LuaJIT and moved to table.unpack in 5.2+.
local unpack = unpack or table.unpack

lv1lua.core = lv1lua.core or {}

lv1lua.loadOnce("LOVE-WrapLua/core/drawobject.lua")
local withDrawTransform = lv1lua.core.withDrawTransform

-- ── Canvas ───────────────────────────────────────────────────────
-- No backend exposes a render target (getSupported().canvas is false), so a
-- Canvas exists only so call sites do not crash; renderTo draws to the screen.
-- Drawing the canvas afterwards is therefore a no-op: its content is already
-- on screen, and handing the Lua table to a native blit raises on device.
local Canvas = {}
Canvas.__index = Canvas
local CANVAS_TYPES = { Canvas = true, Texture = true, Drawable = true, Object = true }
function Canvas:type()      return "Canvas" end
function Canvas:typeOf(t)   return CANVAS_TYPES[t] == true end
function Canvas:_draw()     end
function Canvas:release()   return false end
function Canvas:getWidth()  return self._width end
function Canvas:getHeight() return self._height end
function Canvas:getDimensions() return self._width, self._height end
function Canvas:getPixelWidth()  return self._width end
function Canvas:getPixelHeight() return self._height end
function Canvas:getPixelDimensions() return self._width, self._height end
function Canvas:getFormat() return "rgba8" end
function Canvas:getMSAA()   return 0 end
function Canvas:getFilter() return "linear", "linear", 1 end
function Canvas:setFilter() end
function Canvas:getWrap()   return "clamp", "clamp" end
function Canvas:setWrap()   end
function Canvas:newImageData() return nil end
function Canvas:renderTo(fn) if fn then fn() end end

function love.graphics.newCanvas(width, height, settings)
    return lv1lua.util.registerDrawObject(setmetatable({
        _width  = width  or lv1lua.screenWidth,
        _height = height or lv1lua.screenHeight,
    }, Canvas))
end

function love.graphics.setCanvas(canvas)
    lv1lua.current.canvas = canvas
end

function love.graphics.getCanvas()
    return lv1lua.current.canvas
end

-- ── Shader ───────────────────────────────────────────────────────
-- No programmable pipeline on any backend; the object is inert.
local Shader = {}
Shader.__index = Shader
function Shader:send()        end
function Shader:sendColor()   end
function Shader:hasUniform()  return false end
function Shader:getWarnings() return "" end

function love.graphics.newShader(code, pixelcode)
    return setmetatable({}, Shader)
end

function love.graphics.setShader(shader)
    lv1lua.current.shader = shader
end

function love.graphics.getShader()
    return lv1lua.current.shader
end

lv1lua.loadOnce("LOVE-WrapLua/core/spritebatch.lua")

-- ── Text / TextBatch ─────────────────────────────────────────────
-- Holds a list of strings and replays them through print/printf on draw, with
-- the object's own font temporarily active.
local Text = {}
Text.__index = Text

function love.graphics.newText(fnt, text)
    local t = setmetatable({
        _font    = fnt or lv1lua.current.font,
        _batches = {},
        _width   = 0,
        _height  = 0,
    }, Text)
    if text then t:set(text) end
    return lv1lua.util.registerDrawObject(t)
end

love.graphics.newTextBatch = love.graphics.newText

function Text:set(text)
    self._batches = {}
    self._width, self._height = 0, 0
    if text then
        table.insert(self._batches, {text=text, x=0, y=0})
        self._width  = self._font:getWidth(text)
        self._height = self._font:getHeight()
    end
end

function Text:add(text, x, y, angle, sx, sy, ox, oy)
    table.insert(self._batches, {text=text, x=x or 0, y=y or 0})
    self._width  = math.max(self._width,  (self._font:getWidth(text) or 0) + (x or 0))
    self._height = math.max(self._height, (self._font:getHeight()    or 0) + (y or 0))
    return #self._batches
end

function Text:addf(text, wraplimit, align, x, y)
    table.insert(self._batches, {text=text, x=x or 0, y=y or 0, wrap=wraplimit, align=align})
    local widest, lines = self._font:getWrap(text, wraplimit)
    local lineH = lv1lua.core.lineHeight and lv1lua.core.lineHeight(self._font)
                  or self._font:getHeight()
    self._width  = math.max(self._width,  widest + (x or 0))
    self._height = math.max(self._height, #lines * lineH + (y or 0))
    return #self._batches
end

function Text:clear()
    self._batches = {}; self._width = 0; self._height = 0
end

function Text:getFont()       return self._font end
function Text:getWidth()      return self._width end
function Text:getHeight()     return self._height end
function Text:getDimensions() return self._width, self._height end

-- The replay closure is made once per Text: _draw runs every frame.
local function replayText(self)
    local batches = self._batches
    for i = 1, #batches do
        local b = batches[i]
        if b.wrap then
            love.graphics.printf(b.text, b.x, b.y, b.wrap, b.align)
        else
            love.graphics.print(b.text, b.x, b.y)
        end
    end
end

function Text:_draw(x, y, r, sx, sy, ox, oy)
    local prev = lv1lua.current.font
    local replay = self._replay
    if not replay then
        replay = function() replayText(self) end
        self._replay = replay
    end
    love.graphics.setFont(self._font)
    withDrawTransform(x, y, r, sx, sy, ox, oy, replay)
    love.graphics.setFont(prev)
end
