-- lpp-vita graphics: shared state, colour, and the capability stubs.

local util = lv1lua.util

lv1lua.gfx = {
    -- Native font handle for the bundled default face. Font wrappers built in
    -- graphics/font.lua point at this when the game asks for no specific file.
    defaultFont = Font.load(lv1lua.dataloc .. "LOVE-WrapLua/Vera.ttf"),
    -- lpp-vita blits at 0.75 of LÖVE's coordinate space when scaling is on.
    scale     = 0.75,
    lineWidth = 1,
}
Font.setPixelSizes(lv1lua.gfx.defaultFont, 12)

lv1lua.current = {
    -- Font wrapper object, assigned in graphics/font.lua.
    font        = nil,
    color       = Color.new(255, 255, 255, 255),
    colorRGBA   = {1, 1, 1, 1},
    bgcolor     = Color.new(0, 0, 0, 255),
    bgColorRGBA = {0, 0, 0, 1},
    canvas      = nil,
}

-- ── Colour ───────────────────────────────────────────────────────
function love.graphics.setColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    a = a or 1
    lv1lua.current.colorRGBA = {r, g, b, a}
    lv1lua.current.color = Color.new(util.to255(r, g, b, a))
end

function love.graphics.getColor()
    local c = lv1lua.current.colorRGBA
    return c[1], c[2], c[3], c[4]
end

function love.graphics.setBackgroundColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    a = a or 1
    lv1lua.current.bgColorRGBA = {r, g, b, a}
    lv1lua.current.bgcolor = Color.new(util.to255(r, g, b, a))
end

function love.graphics.getBackgroundColor()
    local c = lv1lua.current.bgColorRGBA
    return c[1], c[2], c[3], c[4]
end

function love.graphics.clear(r, g, b, a)
    -- The frame clear happens in lv1lua.draw (whileloop.lua), which owns the
    -- Screen.clear/flip pair.
end

-- ── Line width / style ───────────────────────────────────────────
function love.graphics.setLineWidth(w) lv1lua.gfx.lineWidth = w or 1 end
function love.graphics.getLineWidth()  return lv1lua.gfx.lineWidth end
function love.graphics.setLineStyle()  end
function love.graphics.getLineStyle()  return "smooth" end

-- ── Not exposed by the native layer ──────────────────────────────
function love.graphics.setDefaultFilter() end
function love.graphics.getDefaultFilter() return "linear","linear",1 end
function love.graphics.setBlendMode()     end
function love.graphics.getBlendMode()     return "alpha","alphamultiply" end
function love.graphics.stencil(fn)        if fn then fn() end end
function love.graphics.setStencilTest()   end
function love.graphics.getStencilTest()   return "always", 0 end
