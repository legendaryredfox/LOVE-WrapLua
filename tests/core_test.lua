-- Unit tests for the backend-agnostic core modules.
--
-- These have no native dependencies at all, so they are tested directly rather
-- than through a backend.

local T = dofile("tests/runner.lua")

__MODE = "OneLua"
dofile("tests/setup.lua")
dofile("LOVE-WrapLua/core/loader.lua")
lv1lua.load("LOVE-WrapLua/core/util.lua")
lv1lua.load("LOVE-WrapLua/core/transform.lua")
lv1lua.load("LOVE-WrapLua/core/textwrap.lua")
lv1lua.load("LOVE-WrapLua/core/polyfill.lua")

local util = lv1lua.util
local core = lv1lua.core

-- "áéí": 3 glyphs, 6 bytes.
local MULTIBYTE = "\195\161\195\169\195\173"

-- ── polyfill (scanline polygon fill, T4.2) ───────────────────────
-- Runs fillPolygon and returns the spans emitted on a given integer row.
local function spansOnRow(vertices, row)
    local rows = {}
    core.fillPolygon(vertices, function(x, y, w)
        rows[y] = rows[y] or {}
        table.insert(rows[y], { x = x, w = w })
    end, nil)
    return rows[row] or {}
end

T.describe("core.fillPolygon", function()
    T.it("fills a convex square with one contiguous span per row", function()
        local spans = spansOnRow({0,0, 10,0, 10,10, 0,10}, 5)
        T.eq(#spans, 1)
        T.eq(spans[1].x, 0)
        T.eq(spans[1].w, 10)
    end)

    T.it("splits a concave notch into two spans (even-odd rule)", function()
        -- A U shape: a hollow notch between x=5 and x=15 below y=5.
        local u = {0,0, 20,0, 20,20, 15,20, 15,5, 5,5, 5,20, 0,20}
        -- Above the notch the top bar is solid.
        local top = spansOnRow(u, 2)
        T.eq(#top, 1)
        T.eq(top[1].w, 20)
        -- Through the notch there are two arms, each 5px wide.
        local mid = spansOnRow(u, 10)
        T.eq(#mid, 2)
        T.eq(mid[1].x, 0);  T.eq(mid[1].w, 5)
        T.eq(mid[2].x, 15); T.eq(mid[2].w, 5)
    end)

    T.it("ignores degenerate polygons with fewer than three vertices", function()
        local called = false
        core.fillPolygon({0,0, 10,10}, function() called = true end, nil)
        T.nok(called)
    end)
end)

-- ── util ─────────────────────────────────────────────────────────
T.describe("core.util.round", function()
    T.it("rounds half away from zero", function()
        T.eq(util.round(1.5), 2)
        T.eq(util.round(1.4), 1)
        T.eq(util.round(2.0), 2)
    end)

    T.it("is exposed as the legacy __mathRound global", function()
        T.ok(__mathRound == util.round)
    end)
end)

T.describe("core.util.to255", function()
    T.it("maps 0-1 to 0-255", function()
        local r, g, b, a = util.to255(1, 0.5, 0, 1)
        T.eq(r, 255); T.eq(g, 128); T.eq(b, 0); T.eq(a, 255)
    end)

    T.it("defaults alpha to opaque", function()
        local _, _, _, a = util.to255(0, 0, 0)
        T.eq(a, 255)
    end)
end)

T.describe("core.util glyph handling", function()
    T.it("counts UTF-8 glyphs, not bytes", function()
        T.eq(#MULTIBYTE, 6)
        T.eq(util.glyphCount(MULTIBYTE), 3)
    end)

    T.it("iterates whole glyphs", function()
        local seen = {}
        for c in util.glyphs(MULTIBYTE) do seen[#seen+1] = c end
        T.eq(#seen, 3)
        T.eq(#seen[1], 2)  -- each glyph keeps both of its bytes
    end)

    T.it("counts ASCII one per byte", function()
        T.eq(util.glyphCount("abc"), 3)
    end)
end)

-- ── transform stack ──────────────────────────────────────────────
T.describe("core.transform stack", function()
    T.it("starts empty and flattens to identity", function()
        local s = core.newTransformStack()
        s:updateTransform()
        T.eq(s.transform._offsetX, 0)
        T.eq(s.transform._scaleX, 1)
    end)

    T.it("accumulates two translates within one level", function()
        local s = core.newTransformStack()
        s:push()
        local top = s:top()
        top._offsetX = top._offsetX + 10
        top._offsetX = top._offsetX + 5
        s:invalidate()
        s:updateTransform()
        T.eq(s.transform._offsetX, 15)
    end)

    T.it("pop discards the level", function()
        local s = core.newTransformStack()
        s:push()
        s:top()._scaleX = 4
        s:pop()
        s:updateTransform()
        T.eq(s.transform._scaleX, 1)
    end)

    T.it("multiplies scales across levels and adds rotations", function()
        local s = core.newTransformStack()
        s:push(); s:top()._scaleX = 2; s:top()._rotation = 1
        s:push(); s:top()._scaleX = 3; s:top()._rotation = 2
        s:invalidate()
        s:updateTransform()
        T.eq(s.transform._scaleX, 6)
        T.eq(s.transform._rotation, 3)
    end)

    T.it("clear leaves no levels", function()
        local s = core.newTransformStack()
        s:push(); s:push()
        s:clear()
        T.eq(#s.stack, 0)
    end)
end)

-- ── word wrap ────────────────────────────────────────────────────
-- 10px per glyph keeps the arithmetic obvious.
local function measure10(s) return util.glyphCount(s) * 10 end

T.describe("core.wrapText", function()
    T.it("keeps text on one line when it fits", function()
        local lines = core.wrapText("ab cd", 100, measure10)
        T.eq(#lines, 1)
        T.eq(lines[1], "ab cd")
    end)

    T.it("breaks between words at the limit", function()
        -- "abc abc" measures 70; a 45px box fits one 30px word per line.
        local lines = core.wrapText("abc abc", 45, measure10)
        T.eq(#lines, 2)
        T.eq(lines[1], "abc")
        T.eq(lines[2], "abc")
    end)

    T.it("honours explicit newlines regardless of the limit", function()
        local lines = core.wrapText("a\nb", 1000, measure10)
        T.eq(#lines, 2)
        T.eq(lines[1], "a")
        T.eq(lines[2], "b")
    end)

    T.it("gives a word wider than the limit its own line", function()
        local lines = core.wrapText("a abcdefgh b", 25, measure10)
        T.eq(lines[1], "a")
        T.eq(lines[2], "abcdefgh")
        T.eq(lines[3], "b")
    end)

    T.it("wraps multibyte text by glyph width", function()
        -- 3 glyphs per word = 30px; two words do not fit in 45px.
        local lines = core.wrapText(MULTIBYTE .. " " .. MULTIBYTE, 45, measure10)
        T.eq(#lines, 2)
    end)
end)

T.describe("core.alignOffset", function()
    T.it("left aligns at zero", function()
        T.eq(core.alignOffset("left", 30, 100), 0)
    end)

    T.it("centers on the leftover space", function()
        T.eq(core.alignOffset("center", 30, 100), 35)
    end)

    T.it("right aligns against the far edge", function()
        T.eq(core.alignOffset("right", 30, 100), 70)
    end)

    T.it("treats an unknown align as left", function()
        T.eq(core.alignOffset(nil, 30, 100), 0)
    end)
end)

T.describe("core.fontMeasure", function()
    T.it("uses the font's own getWidth when present", function()
        local fnt = { getWidth = function(self, s) return #s * 3 end }
        T.eq(core.fontMeasure(fnt)("abcd"), 12)
    end)

    T.it("falls back to a glyph-count estimate without a font", function()
        T.eq(core.fontMeasure(nil, 5)("abc"), 15)
    end)
end)

io.write("\n=== core (shared, backend-agnostic) ===\n")
return T.summary()
