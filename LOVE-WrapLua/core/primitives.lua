-- Shared primitive shapes.
--
-- Every backend that can draw at all draws primitives out of the same four
-- native calls, so the geometry (ellipse, arc, polygon outline, circle outline,
-- points, the pre-0.10 arc signature) belongs here once. A backend supplies
-- `lv1lua.gfx.prims` before loading this file:
--
--   fillRect(x, y, w, h, color)          required
--   fillRuns(runs, dx, dy, color)        optional: {x, y, w, h, ...} rectangles shifted by dx, dy in
--                                        one call (a polygon fill), instead of one fillRect each
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
-- Transforms: every vertex a shape emits goes through `mapPoint` once, and
-- every size through `mapScale`, so translate/scale move primitives exactly as
-- they move images. Shapes built out of other shapes (circle outline, ellipse,
-- arc) generate their vertices in LOVE space and let `polygon` do the single
-- mapping; the native emit calls are already in device space. The optional
-- imgscale/resscale downscale is applied in the same place, so every shape
-- shrinks with the sprites.

local TWO_PI = math.pi * 2

local function prims() return lv1lua.gfx.prims end
local function color() return lv1lua.current.color end

-- Shapes take either a flat list of numbers or one table of them.
local function coords(...)
    local first = select(1, ...)
    if type(first) == "table" then return first end
    return {...}
end

-- The wrapper's optional downscale for small screens (lv1luaconf). A backend
-- with no factor (the 3DS) draws unscaled.
local function configFactor()
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        return lv1lua.gfx.scale or 1
    end
    return 1
end

-- A point in LOVE space to a point on the device.
local function mapPoint(x, y)
    local m = prims().mapPoint
    if m then x, y = m(x, y) end
    local k = configFactor()
    return x * k, y * k
end

-- A size in LOVE space to a size on the device (no translation).
local function mapScale(w, h)
    local m = prims().mapScale
    if m then w, h = m(w, h) end
    local k = configFactor()
    return w * k, h * k
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

-- Polygon fills are cached per vertex table: games redraw the same shapes every frame (rounded
-- boxes, panels). An entry holds the merged rectangles in device space plus a fingerprint of the
-- source vertices and of the transform; a pure integer translation reuses it with a shift,
-- anything else rebuilds. Weak keys: a shape built fresh each call is collected with its table.
local polyCache = setmetatable({}, { __mode = "k" })
local floor = math.floor

-- Entries above this many rectangles are drawn but not kept: one big shape must not take the memory
-- of a 32MB device. hit/miss/skipped feed tests/bench and `lv1lua.core.polygonCacheStats()`.
local MAX_CACHED_RECTS = 512
local polyStats = { hit = 0, miss = 0, skipped = 0 }
function lv1lua.core.polygonCacheStats() return polyStats end

-- `ox`, `oy` place a shape stored relative to its own origin (circles and ellipses), so one cached
-- table serves every position; `fixed` marks such a table as never mutated, which skips the fingerprint.
local function polygonFill(p, src, ox, oy, fixed)
    ox, oy = ox or 0, oy or 0
    local x0, y0 = mapPoint(ox, oy)
    local x1, y1 = mapPoint(ox + 1, oy + 1)
    local sx, sy = x1 - x0, y1 - y0
    local ix, iy = floor(x0), floor(y0)
    local fx, fy = x0 - ix, y0 - iy
    local n, sum = #src, 0
    if not fixed then
        for i = 1, n do sum = sum + src[i] * ((i % 13) + 1) end
    end
    local c = polyCache[src]
    if c and c.n == n and c.sum == sum and c.sx == sx and c.sy == sy and c.fx == fx and c.fy == fy then
        polyStats.hit = polyStats.hit + 1
    else
        local v = {}
        for i = 1, n - 1, 2 do v[i], v[i+1] = mapPoint(ox + src[i], oy + src[i+1]) end
        c = { n = n, sum = sum, sx = sx, sy = sy, fx = fx, fy = fy, ix = ix, iy = iy,
              runs = lv1lua.core.polygonRuns(v) }
        if #c.runs > MAX_CACHED_RECTS * 4 then
            polyStats.skipped = polyStats.skipped + 1
            polyCache[src] = nil
        else
            polyStats.miss = polyStats.miss + 1
            polyCache[src] = c
        end
    end
    local dx, dy, runs, col = ix - c.ix, iy - c.iy, c.runs, color()
    if p.fillRuns then return p.fillRuns(runs, dx, dy, col) end
    local fill = p.fillRect
    for i = 1, #runs, 4 do fill(runs[i] + dx, runs[i + 1] + dy, runs[i + 2], runs[i + 3], col) end
end

-- `open` leaves the outline unclosed; only arc("line", "open", ...) asks. `ox`, `oy` and `fixed` are
-- described at polygonFill.
local function polygon(mode, src, open, ox, oy, fixed)
    local p = prims()
    if #src < 4 then return end
    if mode == "fill" then
        polygonFill(p, src, ox, oy, fixed)
        return
    end
    ox, oy = ox or 0, oy or 0
    -- Mapped once, here: the emit calls below are already device coordinates.
    local v = {}
    for i = 1, #src - 1, 2 do
        v[i], v[i+1] = mapPoint(ox + src[i], oy + src[i+1])
    end
    for i = 1, #v - 2, 2 do
        p.line(v[i], v[i+1], v[i+2], v[i+3], color())
    end
    if not open then
        p.line(v[#v-1], v[#v], v[1], v[2], color())
    end
end

function love.graphics.polygon(mode, vertices, ...)
    polygon(mode, type(vertices) == "table" and vertices or {vertices, ...})
end

-- Unit-less point tables for circles and ellipses, relative to the shape's centre and shared by every
-- draw with the same radii and segment count. Reset when full: an animated radius never repeats.
local shapeCache, shapeCount, SHAPE_LIMIT = {}, 0, 64

local function shapeSlot(key)
    local pts = shapeCache[key]
    if pts then return pts end
    if shapeCount >= SHAPE_LIMIT then shapeCache, shapeCount = {}, 0 end
    pts = {}
    shapeCache[key] = pts
    shapeCount = shapeCount + 1
    return nil, pts
end

local function ellipsePoints(rx, ry, segments, closed)
    local key = rx .. "," .. ry .. "," .. segments .. (closed and "c" or "o")
    local pts, fresh = shapeSlot(key)
    if pts then return pts end
    pts = fresh
    for i = 0, closed and segments or segments - 1 do
        local a = i / segments * TWO_PI
        pts[#pts+1] = rx * math.cos(a)
        pts[#pts+1] = ry * math.sin(a)
    end
    return pts
end

-- Corner arcs of a rounded rectangle, relative to its top-left corner, clockwise on screen.
local function roundedPoints(w, h, rx, ry, segments)
    local key = "r" .. w .. "," .. h .. "," .. rx .. "," .. ry .. "," .. segments
    local pts, fresh = shapeSlot(key)
    if pts then return pts end
    pts = fresh
    local corners = {
        { rx, ry, math.pi }, { w - rx, ry, 1.5 * math.pi },
        { w - rx, h - ry, 0 }, { rx, h - ry, 0.5 * math.pi },
    }
    for _, c in ipairs(corners) do
        for i = 0, segments do
            local a = c[3] + i / segments * (math.pi / 2)
            pts[#pts+1] = c[1] + rx * math.cos(a)
            pts[#pts+1] = c[2] + ry * math.sin(a)
        end
    end
    return pts
end

function love.graphics.rectangle(mode, x, y, w, h, rx, ry, segments)
    if rx and rx > 0 then
        ry = ry or rx
        rx, ry = math.min(rx, w / 2), math.min(ry, h / 2)
        if rx > 0 and ry > 0 then
            segments = segments or math.max(3, math.ceil(math.sqrt(math.max(rx, ry)) * 2))
            return polygon(mode, roundedPoints(w, h, rx, ry, segments), nil, x, y, true)
        end
    end
    local p = prims()
    x, y = mapPoint(x, y)
    w, h = mapScale(w, h)
    if mode == "fill" then
        p.fillRect(x, y, w, h, color())
    elseif mode == "line" then
        p.rectOutline(x, y, w, h, color())
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
    polygon(mode, ellipsePoints(radius, radius, segments, false), nil, x, y, true)
end

function love.graphics.ellipse(mode, x, y, rx, ry, segments)
    ry = ry or rx
    polygon(mode, ellipsePoints(rx, ry, segments or 32, true), nil, x, y, true)
end

function love.graphics.arc(mode, arctype, x, y, radius, angle1, angle2, segments)
    -- Pre-0.10 LOVE had no arctype: arc(mode, x, y, radius, a1, a2, segments),
    -- so every argument after `mode` sits one slot to the left.
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
    -- "closed" and "pie" outlines close back to their first point; "open"
    -- stops at the last arc vertex. A filled arc is always a closed region.
    polygon(mode, pts, mode == "line" and arctype == "open")
end
