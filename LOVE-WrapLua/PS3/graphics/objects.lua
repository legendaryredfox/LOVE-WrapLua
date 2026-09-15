-- PS3 graphics: Canvas / Shader stubs, SpriteBatch, Text.
--
-- tiny3D does expose scene-to-texture surfaces, so a real Canvas is reachable
-- once the backend moves onto it (FIX_PLAN T6.6). Until then Canvas draws
-- straight to the screen.

function love.graphics.newCanvas(w, h)
    return {
        _w = w, _h = h,
        getWidth  = function(s) return s._w end,
        getHeight = function(s) return s._h end,
        renderTo  = function(s, fn) if fn then fn() end end,
    }
end

function love.graphics.setCanvas(c) end
function love.graphics.getCanvas()  return nil end

function love.graphics.newShader()
    return { send = function() end, hasUniform = function() return false end }
end
function love.graphics.setShader() end
function love.graphics.getShader() return nil end

-- ── SpriteBatch ──────────────────────────────────────────────────
-- Position only: the PS3 draw call takes no scale or rotation.
function love.graphics.newSpriteBatch(img, max, usage)
    local sb = { _image = img, _sprites = {} }
    function sb:add(q, x, y, r, sx, sy, ox, oy)
        if type(q) == "table" and q.getViewport then
            table.insert(self._sprites, {quad=q, x=x, y=y})
        else
            table.insert(self._sprites, {x=q, y=x})
        end
        return #self._sprites
    end
    function sb:clear()    self._sprites = {} end
    function sb:flush()    end
    function sb:getCount() return #self._sprites end
    function sb:_draw(bx, by)
        for _, s in ipairs(self._sprites) do
            love.graphics.draw(self._image, (s.x or 0)+(bx or 0), (s.y or 0)+(by or 0))
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
