-- Backend-agnostic helpers shared by every platform module.
-- Pure Lua, no native calls, safe on Lua 5.1 through 5.4 and LuaJIT.

lv1lua.util = lv1lua.util or {}
local util = lv1lua.util

-- Round half up, toward +inf (LÖVE blits on whole pixels).
function util.round(value)
    local remain = value % 1
    if remain >= 0.5 then return value + 1 - remain end
    return value - remain
end

-- LÖVE colour components are 0-1; every console SDK here wants 0-255.
function util.to255(r, g, b, a)
    return math.floor(r * 255 + 0.5),
           math.floor(g * 255 + 0.5),
           math.floor(b * 255 + 0.5),
           math.floor((a or 1) * 255 + 0.5)
end

-- One UTF-8 glyph: a lead byte plus its continuation bytes. Written as
-- "not a continuation byte" so the pattern also covers \0 without needing
-- Lua 5.1's %z.
util.UTF8_GLYPH = "[^\128-\191][\128-\191]*"

-- Iterates whole glyphs, so multibyte characters are measured and wrapped as
-- single units instead of once per byte.
function util.glyphs(s)
    return string.gmatch(tostring(s), util.UTF8_GLYPH)
end

function util.glyphCount(s)
    local n = 0
    for _ in util.glyphs(s) do n = n + 1 end
    return n
end

-- Diagnostic warnings (bad texture size, POT, …). Recorded so tests can assert
-- one fired, and de-duplicated so a per-frame caller does not spam the console.
-- `lv1lua.warn` is the public sink; override it to route warnings elsewhere.
util.warnings = {}
local _warned = {}

function util.warn(msg)
    if _warned[msg] then return end
    _warned[msg] = true
    util.warnings[#util.warnings + 1] = msg
    if lv1lua and lv1lua.warn then lv1lua.warn(msg) else print("[LOVE-WrapLua] " .. msg) end
end

-- Test hook: forget every warning already emitted so the next identical one fires.
function util.resetWarnings()
    util.warnings = {}
    _warned = {}
end

-- Drawables written in Lua (SpriteBatch, Text, Mesh, ParticleSystem) replay
-- themselves through love.graphics.draw instead of hitting a native blit. Each
-- backend's draw has to tell them apart from a native image, and probing for a
-- `_draw` field is not enough: some native image objects answer any field
-- lookup. Registering them keeps the test exact.
local drawObjects = setmetatable({}, { __mode = "k" })

function util.registerDrawObject(obj)
    if type(obj) == "table" then drawObjects[obj] = true end
    return obj
end

function util.isDrawObject(obj)
    return type(obj) == "table" and drawObjects[obj] == true
           and type(obj._draw) == "function"
end

-- vita2d and sf2d place a rotated, scaled sub-rect by its centre, while LOVE
-- places a sprite so that its origin (ox, oy) sits on the pivot (px, py) and
-- rotates around it. Returns the screen-space centre that puts the sprite where
-- LOVE would. The scale is signed, so a mirrored sprite lands on the correct
-- side of its pivot.
function util.spriteCentre(px, py, rad, sx, sy, ox, oy, w, h)
    local lx = (w / 2 - (ox or 0)) * sx
    local ly = (h / 2 - (oy or 0)) * sy
    local c, s = math.cos(rad), math.sin(rad)
    return px + c * lx - s * ly, py + s * lx + c * ly
end

-- Axis-aligned box (x, y, w, h) around a w x h sprite centred on (cx, cy) and
-- rotated by rad. Used for the software scissor reject.
function util.spriteBox(cx, cy, rad, w, h)
    local c, s = math.abs(math.cos(rad)), math.abs(math.sin(rad))
    w, h = math.abs(w), math.abs(h)
    local ew = w * c + h * s
    local eh = w * s + h * c
    return cx - ew / 2, cy - eh / 2, ew, eh
end

-- Kept as a global: game code and older platform modules call it directly.
__mathRound = util.round
