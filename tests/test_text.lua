-- Multi-backend text-metrics suite (#9, #10).
--
-- Two things are asserted for every backend:
--   * a usable default Font object exists before the game calls setFont;
--   * text is measured per *glyph*, not per byte, so multibyte strings are not
--     over-measured (a 3-glyph UTF-8 string is wider than 3 bytes worth of
--     ASCII only by its real rendered width, never by its byte count).
--
-- The mocks measure per glyph (like intraFont on PSP / freetype on Vita), so a
-- wrapper that falls back to `#text * k` fails here instead of mis-wrapping on
-- device.

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
}

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
end

-- "áéí" — 3 glyphs, 6 bytes in UTF-8.
local MULTIBYTE = "\195\161\195\169\195\173"
local ASCII3    = "abc"

local function shared_suite(mode)
    T.describe("text metrics ["..mode.."]", function()
        T.it("a default Font object exists before setFont", function()
            local f = love.graphics.getFont()
            T.eq(type(f), "table")
            T.ok(f.getWidth,  "default font needs getWidth")
            T.ok(f.getHeight, "default font needs getHeight")
        end)

        T.it("getWidth of empty string is 0", function()
            T.eq(love.graphics.getFont():getWidth(""), 0)
        end)

        T.it("getWidth counts glyphs, not bytes", function()
            local f = love.graphics.getFont()
            -- 3 glyphs vs 3 glyphs → equal width.
            -- Byte-count measuring would make the 6-byte string twice as wide.
            T.near(f:getWidth(MULTIBYTE), f:getWidth(ASCII3))
        end)

        T.it("getWidth grows with the number of glyphs", function()
            local f = love.graphics.getFont()
            T.ok(f:getWidth("aa") > f:getWidth("a"), "2 glyphs must be wider than 1")
        end)

        T.it("printf does not error with a multibyte string", function()
            love.graphics.printf(MULTIBYTE.." "..MULTIBYTE, 0, 0, 40, "left")
        end)
    end)
end

-- ── OneLua ───────────────────────────────────────────────────────
load_backend("OneLua")
shared_suite("OneLua")
T.describe("OneLua text metrics (screen.textwidth)", function()
    T.it("getWidth delegates to native screen.textwidth", function()
        __rec.reset()
        local f = love.graphics.newFont(nil, 12)
        T.ok(f:getWidth("abc") > 0, "native width should be positive")
    end)

    T.it("printf measures whole glyphs (one call per glyph, not per byte)", function()
        __rec.reset()
        love.graphics.printf(MULTIBYTE, 0, 0, 200, "left")
        -- 3 glyphs → at most 3 printed words; a per-byte loop would emit more
        -- measuring work and split the string mid-codepoint.
        local printed = __rec.all("screen.print")
        T.ok(#printed >= 1, "should print something")
        T.eq(printed[1].args[4], MULTIBYTE)
    end)
end)

-- ── PSP (OneLua on 480x272) ──────────────────────────────────────
load_backend("PSP")
shared_suite("PSP")
T.describe("PSP text metrics (PGF system font)", function()
    T.it("newFont always returns the system face", function()
        local f = love.graphics.newFont(nil, 20)
        T.eq(f.font, lv1lua.gfx.defaultFont.font)
        T.eq(f.size, 20)
    end)

    T.it("setFont keeps the system face but takes the size", function()
        love.graphics.setFont(love.graphics.newFont(nil, 18), 18)
        T.eq(love.graphics.getFont().font, lv1lua.gfx.defaultFont.font)
        T.eq(love.graphics.getFont().size, 18)
    end)

    T.it("printf wraps on measured width", function()
        love.graphics.setFont(nil, 12)
        __rec.reset()
        -- Mock: 8px per glyph at scale 1; "abc" is 3 glyphs.
        love.graphics.printf("abc abc", 0, 0, 30, "left")
        T.ok(__rec.count("screen.print") >= 2, "should wrap onto two lines")
    end)
end)

-- ── lpp-vita ─────────────────────────────────────────────────────
load_backend("lpp-vita")
shared_suite("lpp-vita")
T.describe("lpp-vita text metrics (Font.getTextWidth)", function()
    T.it("getWidth uses the native Font.getTextWidth call", function()
        local f = love.graphics.newFont(nil, 20)
        love.graphics.setFont(f)
        -- Mock: glyphs * pixelSize * 0.5, with pixelSize pushed by setFont.
        T.near(f:getWidth("abcd"), 4 * 20 * 0.5)
    end)

    T.it("setFont(font, size) pushes the final size to the native font", function()
        local f = love.graphics.newFont(nil, 12)
        love.graphics.setFont(f, 30)
        T.eq(f._font._px, 30)
        T.near(f:getWidth("ab"), 2 * 30 * 0.5)
    end)

    T.it("printf wraps on real pixel width", function()
        local f = love.graphics.newFont(nil, 20)  -- 10px per glyph in the mock
        love.graphics.setFont(f)
        __rec.reset()
        -- 3 glyphs = 30px per word; a 45px wrap fits one word per line.
        love.graphics.printf("abc abc", 0, 0, 45, "left")
        T.eq(__rec.count("Font.print"), 2)
    end)
end)

-- ── PS3 ──────────────────────────────────────────────────────────
load_backend("PS3")
shared_suite("PS3")
T.describe("PS3 text metrics (estimate, no native measuring)", function()
    T.it("setFont / getFont roundtrip", function()
        local f = love.graphics.newFont(nil, 16)
        love.graphics.setFont(f)
        T.ok(love.graphics.getFont() == f)
    end)
end)

io.write("\n=== text metrics (multi-backend) ===\n")
return T.summary()
