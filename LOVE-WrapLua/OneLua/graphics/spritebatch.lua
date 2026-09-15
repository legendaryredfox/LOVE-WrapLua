-- OneLua graphics: SpriteBatch.
--
-- There is no GPU batching to hook into, so a batch is a list of queued draws
-- replayed on draw. It still buys the game the LÖVE API and one shared image.

-- `unpack` is a global in Lua 5.1/LuaJIT and moved to table.unpack in 5.2+.
local unpack = unpack or table.unpack

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
    function sb:_draw(bx, by, br, bsx, bsy)
        for _, s in ipairs(self._sprites) do
            local dx = (s.x or 0) + (bx or 0)
            local dy = (s.y or 0) + (by or 0)
            if s.quad then
                love.graphics.draw(self._image, s.quad, dx, dy, s.r, s.sx, s.sy, s.ox, s.oy)
            else
                love.graphics.draw(self._image, dx, dy, s.r, s.sx, s.sy, s.ox, s.oy)
            end
        end
    end
    return sb
end
