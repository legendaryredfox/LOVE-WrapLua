-- Shared SpriteBatch, pure Lua over love.graphics.draw. Needs lv1lua.util (registerDrawObject) and
-- lv1lua.core.withDrawTransform (core/drawobject.lua).

local unpack = unpack or table.unpack
lv1lua.loadOnce("LOVE-WrapLua/core/drawobject.lua")
local withDrawTransform = lv1lua.core.withDrawTransform

-- ── SpriteBatch ──────────────────────────────────────────────────
-- There is no GPU batching to hook into, so a batch is a list of queued draws
-- replayed on draw. It still buys the game the LÖVE API and one shared image.
-- Arguments a backend cannot honour (rotation on PSP, everything but position
-- on PS3) are dropped by that backend's own draw, not here.
--
-- Sprites live in parallel arrays (quad or false, x, y, r, sx, sy, ox, oy), so adding a sprite allocates no
-- table, a field the game left out costs no slot at all, and a replay is one numeric loop over plain
-- indexes. The replay function is built once per batch; clear only resets the count.
function love.graphics.newSpriteBatch(image, maxsprites, usage)
    local count = 0
    local qs, xs, ys, rs, sxs, sys, oxs, oys = {}, {}, {}, {}, {}, {}, {}, {}
    local cs, colored = {}, false          -- the colour setColor had when each sprite was added, or false
    local sb = {
        _image      = image,
        _maxsprites = maxsprites or 1000,
        _color      = nil,
    }
    -- Every slot is written, nil included, so a slot reused after clear holds nothing of the old sprite.
    local function put(i, quad_or_x, x, y, r, sx, sy, ox, oy)
        cs[i] = sb._color or false
        if sb._color then colored = true end
        if type(quad_or_x) == "table" and quad_or_x.getViewport then
            qs[i], xs[i], ys[i], rs[i], sxs[i], sys[i], oxs[i], oys[i] = quad_or_x, x, y, r, sx, sy, ox, oy
        else
            qs[i], xs[i], ys[i], rs[i], sxs[i], sys[i], oxs[i], oys[i] = false, quad_or_x, x, y, r, sx, sy, ox
        end
    end
    function sb:add(quad_or_x, x, y, r, sx, sy, ox, oy, kx, ky)
        local i = count + 1
        count = i
        put(i, quad_or_x, x, y, r, sx, sy, ox, oy)
        return i
    end
    function sb:set(id, quad_or_x, x, y, r, sx, sy, ox, oy, kx, ky)
        if type(id) ~= "number" or id < 1 or id > count then return end
        put(id, quad_or_x, x, y, r, sx, sy, ox, oy)
    end
    function sb:clear()    count = 0; colored = false end
    function sb:flush()    end
    function sb:getImage() return image end
    function sb:getCount() return count end
    function sb:setColor(r,g,b,a)
        if r == nil then self._color = nil else self._color = {r, g, b, a or 1} end
    end
    function sb:getColor() if self._color then return unpack(self._color, 1, 4) end end
    function sb:attachAttribute() end
    local function replay()
        local lg = love.graphics
        local draw = lg.draw
        local qs, xs, ys, rs, sxs, sys, oxs, oys = qs, xs, ys, rs, sxs, sys, oxs, oys
        local br, bg, bb, ba
        if colored then br, bg, bb, ba = lg.getColor() end
        for i = 1, count do
            if colored then
                local c = cs[i]
                if c then lg.setColor(br * c[1], bg * c[2], bb * c[3], ba * c[4]) else lg.setColor(br, bg, bb, ba) end
            end
            local quad = qs[i]
            if quad then
                draw(image, quad, xs[i] or 0, ys[i] or 0, rs[i], sxs[i], sys[i], oxs[i], oys[i])
            else
                draw(image, xs[i] or 0, ys[i] or 0, rs[i], sxs[i], sys[i], oxs[i], oys[i])
            end
        end
        if colored then lg.setColor(br, bg, bb, ba) end
    end
    function sb:_draw(x, y, r, sx, sy, ox, oy)
        withDrawTransform(x, y, r, sx, sy, ox, oy, replay)
    end
    return lv1lua.util.registerDrawObject(sb)
end
