-- Shared Font object + shared printf suite (FIX_PLAN T5.1, font/text slice).
--
-- Every backend used to carry its own newFont/setFont/printf copy, and they had
-- drifted: setLineHeight was a no-op everywhere, only OneLua cached faces, only
-- OneLua had getWrap-shaped metrics, and printf line spacing was a per-backend
-- constant (16 on PSP, 14 on PS3, size*1.2 on lpp-vita, getHeight on OneLua)
-- instead of LOVE's getHeight() * getLineHeight().
--
-- These cases are backend-agnostic on purpose: they assert ratios and identity,
-- never absolute pixel numbers, so they hold under each platform's own scale.

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
}

-- Native call that carries one printed line, and where its y sits in the args.
local PRINT_CALL = {
    ["OneLua"]   = { name = "screen.print", x = 2, y = 3 },
    ["PSP"]      = { name = "screen.print", x = 2, y = 3 },
    ["lpp-vita"] = { name = "Font.print",   x = 2, y = 3 },
    ["PS3"]      = { name = "DrawText",     x = 1, y = 2 },
}

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
end

-- Vertical gap between the first two printed lines, in native units.
local function lineGap(mode)
    local call = PRINT_CALL[mode]
    local printed = __rec.all(call.name)
    if #printed < 2 then error("printf emitted " .. #printed .. " line(s), need 2") end
    return printed[2].args[call.y] - printed[1].args[call.y]
end

local function firstX(mode)
    local call = PRINT_CALL[mode]
    return __rec.all(call.name)[1].args[call.x]
end

local function shared_suite(mode)
    T.describe("Font object [" .. mode .. "]", function()
        T.it("newFont caches a face+size and returns the same object", function()
            local a = love.graphics.newFont(nil, 22)
            local b = love.graphics.newFont(nil, 22)
            T.ok(a == b, "same face+size must not build a second Font")
        end)

        T.it("newFont(size) and newFont(nil, size) mean the same font", function()
            T.ok(love.graphics.newFont(24) == love.graphics.newFont(nil, 24))
        end)

        T.it("a different size is a different Font", function()
            T.ok(love.graphics.newFont(nil, 26) ~= love.graphics.newFont(nil, 28))
        end)

        T.it("setLineHeight is stored, not swallowed", function()
            local f = love.graphics.newFont(nil, 30)
            T.eq(f:getLineHeight(), 1.2)
            f:setLineHeight(2)
            T.eq(f:getLineHeight(), 2)
            f:setLineHeight(1.2)
        end)

        T.it("resizing through setFont does not poison the cache", function()
            local f = love.graphics.newFont(nil, 32)
            love.graphics.setFont(f, 33)
            local again = love.graphics.newFont(nil, 32)
            T.eq(again.size, 32)
        end)

        T.it("Font:type / typeOf answer like a LOVE object", function()
            local f = love.graphics.newFont(nil, 12)
            T.eq(f:type(), "Font")
            T.ok(f:typeOf("Font"))
            T.nok(f:typeOf("Image"))
        end)

        T.it("getWrap returns the widest line and the lines", function()
            local f = love.graphics.newFont(nil, 12)
            local w, lines = f:getWrap("aaa bbb ccc", f:getWidth("aaa") + 1)
            T.istype(lines, "table")
            T.eq(#lines, 3)
            T.ok(w > 0, "widest line must have a width")
            T.ok(w <= f:getWidth("aaa bbb ccc"), "a wrapped line cannot be wider than the whole string")
        end)

        T.it("every metric method exists", function()
            local f = love.graphics.newFont(nil, 12)
            for _, m in ipairs({"getWidth", "getHeight", "getBaseline", "getAscent",
                                "getDescent", "getLineHeight", "setLineHeight",
                                "hasGlyph", "getKerning", "setFallbacks",
                                "getDPIScale", "getFilter", "setFilter", "getWrap"}) do
                T.istype(f[m], "function")
            end
        end)
    end)

    T.describe("printf layout [" .. mode .. "]", function()
        T.it("line spacing follows getHeight() * getLineHeight()", function()
            local f = love.graphics.newFont(nil, 16)
            love.graphics.setFont(f)

            f:setLineHeight(1)
            __rec.reset()
            love.graphics.printf("one\ntwo", 0, 0, 400, "left")
            local single = lineGap(mode)

            f:setLineHeight(2)
            __rec.reset()
            love.graphics.printf("one\ntwo", 0, 0, 400, "left")
            local double = lineGap(mode)

            f:setLineHeight(1.2)
            T.ok(single > 0, "lines must advance downward")
            T.near(double, single * 2, 1e-6)
        end)

        T.it("explicit newlines break regardless of the wrap width", function()
            love.graphics.setFont(love.graphics.newFont(nil, 12))
            __rec.reset()
            love.graphics.printf("a\nb\nc", 0, 0, 10000, "left")
            T.eq(__rec.count(PRINT_CALL[mode].name), 3)
        end)

        T.it("right align pushes the line further right than left align", function()
            love.graphics.setFont(love.graphics.newFont(nil, 12))
            __rec.reset()
            love.graphics.printf("ab", 0, 0, 300, "left")
            local left = firstX(mode)
            __rec.reset()
            love.graphics.printf("ab", 0, 0, 300, "right")
            local right = firstX(mode)
            T.ok(right > left, "right-aligned x must exceed left-aligned x")
        end)

        T.it("centre sits between left and right", function()
            love.graphics.setFont(love.graphics.newFont(nil, 12))
            __rec.reset()
            love.graphics.printf("ab", 0, 0, 300, "left")
            local left = firstX(mode)
            __rec.reset()
            love.graphics.printf("ab", 0, 0, 300, "center")
            local centre = firstX(mode)
            __rec.reset()
            love.graphics.printf("ab", 0, 0, 300, "right")
            local right = firstX(mode)
            T.ok(centre > left and centre < right, "centre must fall between the two")
        end)

        T.it("an empty string prints nothing", function()
            __rec.reset()
            love.graphics.printf("", 0, 0, 100, "left")
            T.eq(__rec.count(PRINT_CALL[mode].name), 0)
        end)
    end)
end

for _, mode in ipairs({"OneLua", "PSP", "lpp-vita", "PS3"}) do
    load_backend(mode)
    shared_suite(mode)
end

-- ── Backend specifics the shared layer must keep ─────────────────
load_backend("lpp-vita")
T.describe("lpp-vita font sizing", function()
    T.it("measuring one font does not leave the other font's size on the handle", function()
        local small = love.graphics.newFont(nil, 10)
        local big   = love.graphics.newFont(nil, 40)
        love.graphics.setFont(small)
        big:getWidth("abc")
        -- Mock width is glyphs * pixelSize * 0.5, so a leaked pixel size shows up
        -- as the current font suddenly measuring at the other font's size.
        T.near(small:getWidth("abc"), 3 * 10 * 0.5)
    end)
end)

load_backend("OneLua")
T.describe("OneLua font handles", function()
    T.it("a Font keeps a separate handle for measuring", function()
        local f = love.graphics.newFont(nil, 18)
        T.ok(f.font ~= nil, "needs a print handle")
        T.ok(f.guineaPig ~= nil, "needs a measuring handle")
        T.ok(f.font ~= f.guineaPig, "measuring must not disturb the print handle")
    end)
end)

io.write("\n=== fonts + printf (multi-backend) ===\n")
return T.summary()
