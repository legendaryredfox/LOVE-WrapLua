-- PS3 graphics: shared state and colour.
--
-- The PS3 Lua Player exposes BlitToScreen/DrawText and little else, so most of
-- this backend is an honest stub. It is the least-supported tier; see
-- Implemented.md.

-- Bring up the native layer before anything draws.
InitGFX(720, 480)
InitFont("/dev_flash/data/font/SCE-PS3-RD-R-LATIN.TTF", 12)

lv1lua.gfx = {
    -- PS3 output is 720x480 while the game thinks in LÖVE's 1280x720-ish space.
    scale     = 0.5625,
    yOffset   = 37,
    lineWidth = 1,
}

lv1lua.current = {
    -- Font wrapper object, assigned in graphics/font.lua.
    font        = nil,
    color       = nil,
    colorRGBA   = {1, 1, 1, 1},
    bgcolor     = nil,
    bgColorRGBA = {0, 0, 0, 1},
    canvas      = nil,
}

-- ── Colour ───────────────────────────────────────────────────────
-- DrawText/BlitToScreen take no colour argument, so colour is only tracked.
function love.graphics.setColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    lv1lua.current.colorRGBA = {r, g or 0, b or 0, a or 1}
end

function love.graphics.getColor()
    local c = lv1lua.current.colorRGBA
    return c[1], c[2], c[3], c[4]
end

function love.graphics.setBackgroundColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    lv1lua.current.bgColorRGBA = {r, g or 0, b or 0, a or 1}
end

function love.graphics.getBackgroundColor()
    local c = lv1lua.current.bgColorRGBA
    return c[1], c[2], c[3], c[4]
end

function love.graphics.clear(r, g, b, a)
    -- The frame clear happens in lv1lua.draw (whileloop.lua).
end

-- ── Line width / style ───────────────────────────────────────────
function love.graphics.setLineWidth(w) lv1lua.gfx.lineWidth = w or 1 end
function love.graphics.getLineWidth()  return lv1lua.gfx.lineWidth end
function love.graphics.setLineStyle()  end
function love.graphics.getLineStyle()  return "smooth" end
function love.graphics.setLineJoin()   end
function love.graphics.getLineJoin()   return "miter" end
function love.graphics.setPointSize()  end
function love.graphics.getPointSize()  return 1 end

-- ── Not exposed by the native layer ──────────────────────────────
function love.graphics.setDefaultFilter() end
function love.graphics.getDefaultFilter() return "linear","linear",1 end
function love.graphics.setBlendMode()     end
function love.graphics.getBlendMode()     return "alpha","alphamultiply" end
function love.graphics.stencil(fn)        if fn then fn() end end
function love.graphics.setStencilTest()   end
function love.graphics.getStencilTest()   return "always", 0 end
