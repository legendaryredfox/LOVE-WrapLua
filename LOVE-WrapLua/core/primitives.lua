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
--   mapPoint(x, y) -> x, y               optional: point through the transform
--   mapScale(w, h) -> w, h               optional: size through the transform
--
-- The hooks take LOVE's argument order, so a backend whose native call wants a
-- different one (lpp-vita passes both x values before both y values) adapts in
-- its own one-line hook instead of in every shape.
--
-- Transforms (T5.2): every vertex a shape emits goes through `mapPoint` once,
-- so translate/scale move primitives exactly as they move images. Backends
-- without a transform stack (PSP, PS3) install no hook and their coordinates
-- pass through untouched. Shapes built out of other shapes (circle outline,
-- ellipse, arc) generate their vertices in LOVE space and let `polygon` do the
-- single mapping; the native emit calls are already in device space.

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

-- A point in LOVE space to a point on the device.
local function mapPoint(x, y)
    local m = prims().mapPoint
    if m then return m(x, y) end
    return x, y
end

-- A size in LOVE space to a size on the device (no translation).
local function mapScale(w, h)
    local m = prims().mapScale
    if m then return m(w, h) end
    return w, h
end

function love.graphics.rectangle(mode, x, y, w, h, rx, ry)
    local p = prims()
    x, y = mapPoint(x, y)
    w, h = mapScale(w, h)
    x, y, w, h = configScale(x, y, w, h)
    if mode == "fill" then
        p.fillRect(x, y, w, h, color())
    elseif mode == "line" then
        p.rectOutline(x, y, w, h, color())
    end
end

function love.graphics.line(...)
    local c, p = coords(...), prims()
    for i = 1, #c - 2, 2 do
        local x1, y1 = mapPoint(c[i], c[i+1])
        local x2, y2 = mapPoint(c[i+2], c[i+3])
        p.line(x1, y1, x2, y2, color())
    end
end

function love.graphics.points(...)
    local c, p = coords(...), prims()
    for i = 1, #c - 1, 2 do
        local x, y = mapPoint(c[i], c[i+1])
        p.fillRect(x, y, 1, 1, color())
    end
end

function love.graphics.polygon(mode, vertices, ...)
    local src = (type(vertices) == "table" and vertices or {vertices, ...})
    local p   = prims()
    if #src < 4 then return end
    -- Mapped once, here: the emit calls below are already device coordinates.
    local v = {}
    for i = 1, #src - 1, 2 do
        v[i], v[i+1] = mapPoint(src[i], src[i+1])
    end
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
    if mode == "fill" and p.fillCircle then
        local cx, cy = mapPoint(x, y)
        local r = mapScale(radius, radius)
        p.fillCircle(cx, cy, r, color(), segments)
        return
    end
    -- Vertices stay in LOVE space; polygon maps them.
    local pts = {}
    for i = 0, segments - 1 do
        local a = i / segments * TWO_PI
        pts[#pts+1] = x + radius * math.cos(a)
        pts[#pts+1] = y + radius * math.sin(a)
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
