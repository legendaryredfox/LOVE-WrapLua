-- Shared primitive shapes (FIX_PLAN T5.1, third slice).
--
-- Every backend that can draw at all draws primitives out of the same four
-- native calls, so the geometry (ellipse, arc, polygon outline, circle outline,
-- points, the old LOVE arc signature) belongs here once. A backend supplies
-- `lv1lua.gfx.prims` before loading this file:
--
--   fillRect(x, y, w, h, color)          required
--   rectOutline(x, y, w, h, color)       required
--   line(x1, y1, x2, y2, color)          required
--   fillCircle(x, y, r, color, segments) optional; falls back to a filled polygon
--   mapRect(x, y, w, h) -> x, y, w, h    optional device mapping (transform scale)
--   mapRadius(r) -> r                    optional device mapping for a radius
--
-- The hooks take LOVE's argument order, so a backend whose native call wants a
-- different one (lpp-vita passes both x values before both y values) adapts in
-- its own one-line hook instead of in every shape.
--
-- Note on transforms: only the scale part of the transform stack reaches a
-- primitive, and only where the backend maps it. Translating and then drawing a
-- rectangle is still unscoped work, tracked as T5.2, and is deliberately not
-- changed by this refactor.

local TWO_PI = math.pi * 2

local function prims() return lv1lua.gfx.prims end
local function color() return lv1lua.current.color end

-- Shapes take either a flat list of numbers or one table of them.
local function coords(...)
    local first = select(1, ...)
    if type(first) == "table" then return first end
    return {...}
end

-- The wrapper's optional 75% downscale for small screens.
local function configScale(x, y, w, h)
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        local s = lv1lua.gfx.scale
        return x * s, y * s, w * s, h * s
    end
    return x, y, w, h
end

function love.graphics.rectangle(mode, x, y, w, h, rx, ry)
    local p = prims()
    x, y, w, h = configScale(x, y, w, h)
    if p.mapRect then x, y, w, h = p.mapRect(x, y, w, h) end
    if mode == "fill" then
        p.fillRect(x, y, w, h, color())
    elseif mode == "line" then
        p.rectOutline(x, y, w, h, color())
    end
end

function love.graphics.line(...)
    local c, p = coords(...), prims()
    for i = 1, #c - 2, 2 do
        p.line(c[i], c[i+1], c[i+2], c[i+3], color())
    end
end

function love.graphics.points(...)
    local c, p = coords(...), prims()
    for i = 1, #c - 1, 2 do
        p.fillRect(c[i], c[i+1], 1, 1, color())
    end
end

function love.graphics.polygon(mode, vertices, ...)
    local v, p = (type(vertices) == "table" and vertices or {vertices, ...}), prims()
    if #v < 4 then return end
    if mode == "fill" then
        -- Scanline fill through the shared even-odd rasteriser, correct for
        -- convex and concave polygons alike.
        lv1lua.core.fillPolygon(v, function(sx, sy, sw, c)
            p.fillRect(sx, sy, sw, 1, c)
        end, color())
    else
        for i = 1, #v - 2, 2 do
            p.line(v[i], v[i+1], v[i+2], v[i+3], color())
        end
        p.line(v[#v-1], v[#v], v[1], v[2], color())  -- close
    end
end

function love.graphics.circle(mode, x, y, radius, segments)
    local p = prims()
    segments = segments or 32
    local r = p.mapRadius and p.mapRadius(radius) or radius
    if mode == "fill" and p.fillCircle then
        p.fillCircle(x, y, r, color(), segments)
        return
    end
    local pts = {}
    for i = 0, segments - 1 do
        local a = i / segments * TWO_PI
        pts[#pts+1] = x + r * math.cos(a)
        pts[#pts+1] = y + r * math.sin(a)
    end
    love.graphics.polygon(mode, pts)
end

function love.graphics.ellipse(mode, x, y, rx, ry, segments)
    ry = ry or rx
    segments = segments or 32
    local pts = {}
    for i = 0, segments do
        local a = i / segments * TWO_PI
        pts[#pts+1] = x + rx * math.cos(a)
        pts[#pts+1] = y + ry * math.sin(a)
    end
    love.graphics.polygon(mode, pts)
end

function love.graphics.arc(mode, arctype, x, y, radius, angle1, angle2, segments)
    -- Pre-0.10 LOVE had no arctype: arc(mode, x, y, radius, a1, a2, segments).
    -- The old per-backend copies shifted every argument by one here, including
    -- `mode` into `x`, which drew the arc at a string coordinate.
    if type(arctype) == "number" then
        segments = angle2; angle2 = angle1; angle1 = radius
        radius   = y; y = x; x = arctype
        arctype  = "pie"
    end
    -- Even older call form with no mode either: arc(x, y, radius, a1, a2).
    if type(mode) == "number" then
        segments = angle1; angle2 = radius; angle1 = y
        radius   = x; y = arctype; x = mode
        arctype  = "pie"; mode = "line"
    end
    arctype  = arctype  or "pie"
    segments = segments or 12
    local pts = {}
    if arctype == "pie" then
        pts[#pts+1] = x; pts[#pts+1] = y
    end
    for i = 0, segments do
        local a = angle1 + (angle2 - angle1) * i / segments
        pts[#pts+1] = x + radius * math.cos(a)
        pts[#pts+1] = y + radius * math.sin(a)
    end
    if arctype == "closed" then
        pts[#pts+1] = pts[1]; pts[#pts+1] = pts[2]
    end
    love.graphics.polygon(mode, pts)
end
