-- OneLua graphics: Text / TextBatch object.
--
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
    return t
end

love.graphics.newTextBatch = love.graphics.newText

function Text:set(text)
    self._batches = {}
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
    return #self._batches
end

function Text:clear()
    self._batches = {}; self._width = 0; self._height = 0
end

function Text:getFont()       return self._font end
function Text:getWidth()      return self._width end
function Text:getHeight()     return self._height end
function Text:getDimensions() return self._width, self._height end

function Text:_draw(x, y, r, sx, sy)
    local prev = lv1lua.current.font
    love.graphics.setFont(self._font)
    for _, b in ipairs(self._batches) do
        local dx, dy = (x or 0) + b.x, (y or 0) + b.y
        if b.wrap then
            love.graphics.printf(b.text, dx, dy, b.wrap, b.align)
        else
            love.graphics.print(b.text, dx, dy)
        end
    end
    love.graphics.setFont(prev)
end
