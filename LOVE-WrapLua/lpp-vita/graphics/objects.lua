-- lpp-vita graphics: Canvas / Shader stubs, SpriteBatch, Text.
--
-- vita2d can create render-target textures, but lpp-vita exposes no "bind draw
-- target" call, so Canvas cannot render offscreen here; it draws straight to
-- the screen. See FIX_PLAN T4.3.

function love.graphics.newCanvas(w, h)
    return {
        _width  = w or lv1lua.screenWidth,
        _height = h or lv1lua.screenHeight,
        getWidth  = function(s) return s._width end,
        getHeight = function(s) return s._height end,
        renderTo  = function(s, fn) if fn then fn() end end,
    }
end

function love.graphics.setCanvas(c) end
function love.graphics.getCanvas()  return nil end

function love.graphics.newShader(code)
    return { send = function() end, hasUniform = function() return false end }
end
function love.graphics.setShader() end
function love.graphics.getShader() return nil end

-- ── SpriteBatch ──────────────────────────────────────────────────
-- No GPU batching is exposed: queued draws are replayed one by one.
function love.graphics.newSpriteBatch(img, max, usage)
    local sb = { _image = img, _sprites = {} }
    function sb:add(q, x, y, r, sx, sy, ox, oy)
        if type(q) == "table" and q.getViewport then
            table.insert(self._sprites, {quad=q, x=x, y=y, r=r, sx=sx, sy=sy, ox=ox, oy=oy})
        else
            table.insert(self._sprites, {x=q, y=x, r=y, sx=r, sy=sx})
        end
        return #self._sprites
    end
    function sb:clear()    self._sprites = {} end
    function sb:flush()    end
    function sb:getCount() return #self._sprites end
    function sb:_draw(bx, by)
        for _, s in ipairs(self._sprites) do
            love.graphics.draw(self._image, (s.x or 0)+(bx or 0), (s.y or 0)+(by or 0),
                               s.r, s.sx, s.sy)
        end
    end
    return sb
end

-- ── Text ─────────────────────────────────────────────────────────
function love.graphics.newText(fnt, text)
    local t = { _font = fnt, _batches = {} }
    function t:set(s) self._batches = {{text=s, x=0, y=0}} end
    function t:add(s, x, y)
        table.insert(self._batches, {text=s, x=x or 0, y=y or 0})
        return #self._batches
    end
    function t:clear()     self._batches = {} end
    function t:getWidth()  return 0 end
    function t:getHeight() return 0 end
    function t:_draw(x, y)
        for _, b in ipairs(self._batches) do
            love.graphics.print(b.text, (x or 0)+b.x, (y or 0)+b.y)
        end
    end
    if text then t:set(text) end
    return t
end

love.graphics.newTextBatch = love.graphics.newText
