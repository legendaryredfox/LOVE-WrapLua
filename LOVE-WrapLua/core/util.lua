-- Backend-agnostic helpers shared by every platform module.
-- Pure Lua, no native calls, safe on Lua 5.1 through 5.4 and LuaJIT.

lv1lua.util = lv1lua.util or {}
local util = lv1lua.util

-- Round half away from zero (LÖVE blits on whole pixels).
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

-- Kept as a global: game code and older platform modules call it directly.
__mathRound = util.round
