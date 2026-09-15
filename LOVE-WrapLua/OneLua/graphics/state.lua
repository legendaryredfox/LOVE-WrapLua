-- OneLua graphics: shared state, colour, blend mode, line style, filters.
--
-- `lv1lua.gfx` holds everything the graphics submodules share (the transform
-- stack, the font cache, platform constants). It is internal: games only ever
-- see the love.graphics surface.

local util = lv1lua.util

lv1lua.gfx = {
    defaultFontPath = lv1lua.dataloc .. "LOVE-WrapLua/Vera.ttf",
    -- OneLua blits at 0.75 of LÖVE's coordinate space when img/res scaling is on.
    scale        = 0.75,
    lineWidth    = 1,
    filter       = { min = 3, mag = 3, anisotropy = 0 },
    -- screen.print takes a *scale factor* relative to a 18.5px glyph box, and
    -- anchors text on that box's baseline. The same number therefore converts a
    -- LÖVE pixel size to a native scale and shifts text to LÖVE's top-left
    -- origin.
    fontUnit     = 18.5,
    fonts        = nil,  -- font cache, built in graphics/font.lua
    transform    = nil,  -- transform stack, built in graphics/transform.lua
}

lv1lua.current = {
    -- Font object, assigned in graphics/font.lua once newFont exists.
    font        = nil,
    color       = color.new(255, 255, 255, 255),
    colorRGBA   = {1, 1, 1, 1},
    bgcolor     = color.new(0, 0, 0, 255),
    bgColorRGBA = {0, 0, 0, 1},
    canvas      = nil,
    blendMode   = "alpha",
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

-- ── Blend mode (stub — OneLua exposes no blend state) ────────────
function love.graphics.setBlendMode(mode, alphamode)
    lv1lua.current.blendMode = mode
end

function love.graphics.getBlendMode()
    return lv1lua.current.blendMode, "alphamultiply"
end

-- ── Line width / style ───────────────────────────────────────────
function love.graphics.setLineWidth(w)  lv1lua.gfx.lineWidth = w or 1 end
function love.graphics.getLineWidth()   return lv1lua.gfx.lineWidth end
function love.graphics.setLineStyle(s)  end
function love.graphics.getLineStyle()   return "smooth" end
function love.graphics.setLineJoin(j)   end
function love.graphics.getLineJoin()    return "miter" end
function love.graphics.setPointSize(s)  end
function love.graphics.getPointSize()   return 1 end

-- ── Default texture filter ───────────────────────────────────────
function love.graphics.setDefaultFilter(min, mag, anisotropy)
    if min == "linear" then min = __IMG_FILTER_LINEAR
    elseif min == "nearest" or min == "point" then min = __IMG_FILTER_POINT end
    if mag == "linear" then mag = __IMG_FILTER_LINEAR
    elseif mag == "nearest" or mag == "point" then mag = __IMG_FILTER_POINT end
    lv1lua.gfx.filter.min = min
    lv1lua.gfx.filter.mag = mag
    lv1lua.gfx.filter.anisotropy = anisotropy and 1 or 0
end

function love.graphics.getDefaultFilter()
    local f = lv1lua.gfx.filter
    return f.min, f.mag, f.anisotropy
end

-- ── Stencil (stub) ───────────────────────────────────────────────
function love.graphics.stencil(fn, action, value, keepvalues) if fn then fn() end end
function love.graphics.setStencilTest(compare, value) end
function love.graphics.getStencilTest() return "always", 0 end
