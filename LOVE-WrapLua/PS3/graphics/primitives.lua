-- PS3 graphics: primitive hooks for core/primitives.lua.
-- Uses tiny3D untextured quads for filled and outlined shapes, and thin
-- oriented rectangles for lines.

local function gfxTable() return rawget(_G, "gfx") end

-- Emits a solid-color quad with no texture binding. r/g/b/a are 0..1.
local function solidQuad(g, x, y, w, h, color)
    local r, gr, b, a
    if type(color) == "table" and color.r then
        r, gr, b, a = color.r / 255, color.g / 255, color.b / 255, color.a / 255
    else
        local c = lv1lua.current.colorRGBA
        r, gr, b, a = c[1], c[2], c[3], c[4]
    end
    g.SetPolygon(g.QUADS, 0)
    g.VertexPosition(x,   y,   0); g.VertexColor(r, gr, b, a)
    g.VertexPosition(x+w, y,   0); g.VertexColor(r, gr, b, a)
    g.VertexPosition(x+w, y+h, 0); g.VertexColor(r, gr, b, a)
    g.VertexPosition(x,   y+h, 0); g.VertexColor(r, gr, b, a)
    g.End()
end

-- Emits a line of width lineWidth as a thin rotated quad.
local function thickLine(g, x1, y1, x2, y2, color)
    local lw = lv1lua.gfx.lineWidth or 1
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len == 0 then return end
    local nx = -dy / len * (lw * 0.5)
    local ny =  dx / len * (lw * 0.5)
    local r, gr, b, a
    if type(color) == "table" and color.r then
        r, gr, b, a = color.r / 255, color.g / 255, color.b / 255, color.a / 255
    else
        local c = lv1lua.current.colorRGBA
        r, gr, b, a = c[1], c[2], c[3], c[4]
    end
    g.SetPolygon(g.QUADS, 0)
    g.VertexPosition(x1-nx, y1-ny, 0); g.VertexColor(r, gr, b, a)
    g.VertexPosition(x2-nx, y2-ny, 0); g.VertexColor(r, gr, b, a)
    g.VertexPosition(x2+nx, y2+ny, 0); g.VertexColor(r, gr, b, a)
    g.VertexPosition(x1+nx, y1+ny, 0); g.VertexColor(r, gr, b, a)
    g.End()
end

-- Converts a LOVE-space coordinate to PS3 screen space. core/primitives.lua
-- already applies gfx.scale when lv1luaconf.imgscale or resscale is set; when
-- neither is, the hook does the conversion itself.
local function toScreen(x, y)
    local s  = (lv1luaconf.imgscale or lv1luaconf.resscale) and 1 or lv1lua.gfx.scale
    return x * s, y * s + lv1lua.gfx.yOffset
end

local function sizeToScreen(w, h)
    local s = (lv1luaconf.imgscale or lv1luaconf.resscale) and 1 or lv1lua.gfx.scale
    return w * s, h * s
end

local stack = lv1lua.gfx.transform

lv1lua.gfx.prims = {
    fillRect = function(x, y, w, h, color)
        local g = gfxTable()
        if not (g and g.SetPolygon) then return end
        local sx, sy = toScreen(x, y)
        local sw, sh = sizeToScreen(w, h)
        solidQuad(g, sx, sy, sw, sh, color)
    end,

    rectOutline = function(x, y, w, h, color)
        local g = gfxTable()
        if not (g and g.SetPolygon) then return end
        local sx, sy = toScreen(x, y)
        local sw, sh = sizeToScreen(w, h)
        thickLine(g, sx,    sy,    sx+sw, sy,    color)
        thickLine(g, sx+sw, sy,    sx+sw, sy+sh, color)
        thickLine(g, sx+sw, sy+sh, sx,    sy+sh, color)
        thickLine(g, sx,    sy+sh, sx,    sy,    color)
    end,

    line = function(x1, y1, x2, y2, color)
        local g = gfxTable()
        if not (g and g.SetPolygon) then return end
        local sx1, sy1 = toScreen(x1, y1)
        local sx2, sy2 = toScreen(x2, y2)
        thickLine(g, sx1, sy1, sx2, sy2, color)
    end,

    -- Primitives ride the transform stack.
    mapPoint = function(x, y) return stack:mapPoint(x, y) end,
    mapScale = function(w, h) return stack:mapScale(w, h) end,
}
