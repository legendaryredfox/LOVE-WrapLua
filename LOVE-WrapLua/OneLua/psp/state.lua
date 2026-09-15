-- PSP graphics: shared state and colour.
--
-- The PSP runs OneLua too, but with a 480x272 screen, the bundled PGF system
-- font and no transform support, so it has its own thin backend instead of
-- branching the Vita one everywhere.

local util = lv1lua.util

lv1lua.gfx = {
    -- The PGF system font ships with OneLua; TTF loading is Vita-only.
    defaultFont = { font = font.load("oneFont.pgf"), size = 15 },
    -- PSP renders at 0.375 of LÖVE's coordinate space when scaling is on.
    scale       = 0.375,
    -- Text needs a smaller factor than geometry to stay legible at 480x272.
    fontScale   = 0.6,
    -- screen.print takes a scale factor relative to a 18.5px glyph box.
    fontUnit    = 18.5,
    lineWidth   = 1,
}

lv1lua.current = {
    -- Font object, assigned in psp/font.lua once newFont exists.
    font        = nil,
    color       = color.new(255, 255, 255, 255),
    colorRGBA   = {1, 1, 1, 1},
    bgcolor     = color.new(0, 0, 0, 255),
    bgColorRGBA = {0, 0, 0, 1},
    canvas      = nil,
}

-- ── Colour ───────────────────────────────────────────────────────
function love.graphics.setColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    a = a or 1
    lv1lua.current.colorRGBA = {r, g, b, a}
    lv1lua.current.color = color.new(util.to255(r, g, b, a))
end

function love.graphics.getColor()
    local c = lv1lua.current.colorRGBA
    return c[1], c[2], c[3], c[4]
end

function love.graphics.setBackgroundColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    a = a or 1
    lv1lua.current.bgColorRGBA = {r, g, b, a}
    lv1lua.current.bgcolor = color.new(util.to255(r, g, b, a))
end

function love.graphics.getBackgroundColor()
    local c = lv1lua.current.bgColorRGBA
    return c[1], c[2], c[3], c[4]
end

function love.graphics.clear(r, g, b, a)
    if r == nil then
        screen.clear(lv1lua.current.bgcolor)
    elseif type(r) == "table" then
        screen.clear(color.new(util.to255(r[1], r[2], r[3], r[4] or 1)))
    else
        screen.clear(color.new(util.to255(r, g or 0, b or 0, a or 1)))
    end
end

-- ── Line width / style ───────────────────────────────────────────
function love.graphics.setLineWidth(w) lv1lua.gfx.lineWidth = w or 1 end
function love.graphics.getLineWidth()  return lv1lua.gfx.lineWidth end
function love.graphics.setLineStyle()  end
function love.graphics.getLineStyle()  return "smooth" end

-- ── Not exposed on PSP ───────────────────────────────────────────
function love.graphics.setDefaultFilter() end
function love.graphics.getDefaultFilter() return "linear","linear",1 end
function love.graphics.setBlendMode()     end
function love.graphics.getBlendMode()     return "alpha","alphamultiply" end
function love.graphics.stencil(fn)        if fn then fn() end end
function love.graphics.setStencilTest()   end
function love.graphics.getStencilTest()   return "always", 0 end
