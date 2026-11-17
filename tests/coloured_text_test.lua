-- Coloured text: {color, "string", color, "string"} is accepted wherever LÖVE accepts it
-- (print, printf, Font:getWidth, Font:getWrap, Text), on every backend.

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
    ["3DS"]      = "LOVE-WrapLua/3DS/graphics.lua",
}
local NATIVE_PRINT = { ["OneLua"] = "screen.print", ["PSP"] = "screen.print", ["lpp-vita"] = "Font.print" }

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
end

local RED, GREEN = { 1, 0, 0 }, { 0, 1, 0, 0.5 }

T.describe("plainText", function()
    load_backend("OneLua")
    T.it("joins the strings and drops the colours", function()
        T.eq(lv1lua.core.plainText({ RED, "ab", GREEN, "cd", "ef" }), "abcdef")
    end)
    T.it("passes a plain string through", function()
        T.eq(lv1lua.core.plainText("abc"), "abc")
    end)
end)

T.describe("printColoured", function()
    load_backend("OneLua")
    T.it("prints each segment in its colour, after the previous one", function()
        local calls = {}
        local font = love.graphics.getFont()
        love.graphics.setColor(0.5, 1, 1, 1)
        lv1lua.core.printColoured(function(s, x, y)
            local r, g, b, a = love.graphics.getColor()
            calls[#calls + 1] = { s = s, x = x, y = y, r = r, g = g, b = b, a = a }
        end, { RED, "ab", GREEN, "cd" }, 10, 20)
        T.eq(#calls, 2)
        T.eq(calls[1].s, "ab"); T.eq(calls[1].x, 10); T.eq(calls[1].y, 20)
        T.near(calls[1].r, 0.5); T.near(calls[1].g, 0); T.near(calls[1].a, 1)
        T.eq(calls[2].s, "cd"); T.near(calls[2].x, 10 + font:getWidth("ab"))
        T.near(calls[2].g, 1); T.near(calls[2].a, 0.5)
    end)
    T.it("leaves the current colour as it found it", function()
        love.graphics.setColor(0.2, 0.4, 0.6, 0.8)
        lv1lua.core.printColoured(function() end, { RED, "x" }, 0, 0)
        local r, g, b, a = love.graphics.getColor()
        T.near(r, 0.2); T.near(g, 0.4); T.near(b, 0.6); T.near(a, 0.8)
    end)
    T.it("a segment before any colour uses the current one", function()
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        local seen
        lv1lua.core.printColoured(function() seen = love.graphics.getColor() end, { "x" }, 0, 0)
        T.near(seen, 0.3)
    end)
end)

for _, mode in ipairs({ "OneLua", "PSP", "lpp-vita", "PS3", "3DS" }) do
    T.describe("coloured text [" .. mode .. "]", function()
        load_backend(mode)
        local font = love.graphics.getFont()

        T.it("Font:getWidth measures the joined strings", function()
            T.eq(font:getWidth({ RED, "ab", GREEN, "cd" }), font:getWidth("abcd"))
        end)

        T.it("Font:getWrap wraps the joined strings", function()
            local w1, l1 = font:getWrap({ RED, "abc ", GREEN, "abc" }, 30)
            local w2, l2 = font:getWrap("abc abc", 30)
            T.eq(w1, w2); T.eq(#l1, #l2)
        end)

        T.it("print and printf accept it", function()
            love.graphics.print({ RED, "ab", GREEN, "cd" }, 0, 0)
            love.graphics.printf({ RED, "ab ", GREEN, "cd" }, 0, 20, 300, "left")
        end)

        T.it("a Text built from it has the joined width and draws", function()
            local t = love.graphics.newText(font, { RED, "ab", GREEN, "cd" })
            T.eq(t:getWidth(), font:getWidth("abcd"))
            love.graphics.draw(t, 10, 10)
        end)

        local native = NATIVE_PRINT[mode]
        if native then
            T.it("print issues one native print per segment", function()
                __rec.reset()
                love.graphics.print({ RED, "ab", GREEN, "cd" }, 0, 0)
                T.eq(__rec.count(native), 2)
            end)
        end
    end)
end

io.write("\n=== coloured text ===\n")
return T.summary()
