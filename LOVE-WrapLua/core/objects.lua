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

-- draw(object, x, y, r, sx, sy, ox, oy) places a whole batch, text or particle
-- system the way it places one sprite. The object replays its own draws inside
-- that transform, pushed onto the stack every backend folds into its draws.
function lv1lua.core.withDrawTransform(x, y, r, sx, sy, ox, oy, fn)
    local lg = love.graphics
    sx = sx or 1; sy = sy or sx
    lg.push()
    lg.translate(x or 0, y or 0)
    if r and r ~= 0 then lg.rotate(r) end
    if sx ~= 1 or sy ~= 1 then lg.scale(sx, sy) end
    if (ox and ox ~= 0) or (oy and oy ~= 0) then lg.translate(-(ox or 0), -(oy or 0)) end
    local ok, err = pcall(fn)
    lg.pop()
    if not ok then error(err, 0) end
end
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

-- ── SpriteBatch ──────────────────────────────────────────────────
-- There is no GPU batching to hook into, so a batch is a list of queued draws
-- replayed on draw. It still buys the game the LÖVE API and one shared image.
-- Arguments a backend cannot honour (rotation on PSP, everything but position
-- on PS3) are dropped by that backend's own draw, not here.
function love.graphics.newSpriteBatch(image, maxsprites, usage)
    local sb = {
        _image      = image,
        _maxsprites = maxsprites or 1000,
        _sprites    = {},
        _color      = nil,
    }
    function sb:add(quad_or_x, x, y, r, sx, sy, ox, oy, kx, ky)
        local entry
        if type(quad_or_x) == "table" and quad_or_x.getViewport then
            entry = {quad=quad_or_x, x=x, y=y, r=r, sx=sx, sy=sy, ox=ox, oy=oy}
        else
            entry = {x=quad_or_x, y=x, r=y, sx=r, sy=sx, ox=sy, oy=ox}
        end
        table.insert(self._sprites, entry)
        return #self._sprites
    end
    function sb:set(id, quad_or_x, x, y, r, sx, sy, ox, oy, kx, ky)
        local e = self._sprites[id]
        if not e then return end
        if type(quad_or_x) == "table" and quad_or_x.getViewport then
            e.quad,e.x,e.y,e.r,e.sx,e.sy,e.ox,e.oy = quad_or_x,x,y,r,sx,sy,ox,oy
        else
            e.quad = nil
            e.x,e.y,e.r,e.sx,e.sy,e.ox,e.oy = quad_or_x,x,y,r,sx,sy,ox
        end
    end
    function sb:clear()    self._sprites = {} end
    function sb:flush()    end
    function sb:getImage() return self._image end
    function sb:getCount() return #self._sprites end
    function sb:setColor(r,g,b,a) self._color={r,g,b,a} end
    function sb:getColor() return self._color and unpack(self._color) end
    function sb:attachAttribute() end
    function sb:_draw(x, y, r, sx, sy, ox, oy)
        local sprites, image = self._sprites, self._image
        withDrawTransform(x, y, r, sx, sy, ox, oy, function()
            for _, s in ipairs(sprites) do
                if s.quad then
                    love.graphics.draw(image, s.quad, s.x or 0, s.y or 0, s.r, s.sx, s.sy, s.ox, s.oy)
                else
                    love.graphics.draw(image, s.x or 0, s.y or 0, s.r, s.sx, s.sy, s.ox, s.oy)
                end
            end
        end)
    end
    return lv1lua.util.registerDrawObject(sb)
end

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

function Text:_draw(x, y, r, sx, sy, ox, oy)
    local prev, batches = lv1lua.current.font, self._batches
    love.graphics.setFont(self._font)
    withDrawTransform(x, y, r, sx, sy, ox, oy, function()
        for _, b in ipairs(batches) do
            if b.wrap then
                love.graphics.printf(b.text, b.x, b.y, b.wrap, b.align)
            else
                love.graphics.print(b.text, b.x, b.y)
            end
        end
    end)
    love.graphics.setFont(prev)
end
