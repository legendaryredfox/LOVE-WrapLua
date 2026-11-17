-- Scissor state on the shared transform surface (core/transformapi.lua).
--
-- intersectScissor used to replace the active scissor outright. LOVE shrinks
-- it to the overlap with the one already set, so a clipped panel inside a
-- clipped window could draw outside its parent.

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
    ["3DS"]      = "LOVE-WrapLua/3DS/graphics.lua",
}

for _, mode in ipairs({ "PSP", "PS3", "OneLua", "lpp-vita", "3DS" }) do
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])

    T.describe("scissor [" .. mode .. "]", function()
        T.it("intersectScissor with none set behaves like setScissor", function()
            love.graphics.setScissor()
            love.graphics.intersectScissor(10, 20, 30, 40)
            local x, y, w, h = love.graphics.getScissor()
            T.eq(x, 10); T.eq(y, 20); T.eq(w, 30); T.eq(h, 40)
        end)

        T.it("intersectScissor keeps only the overlap", function()
            love.graphics.setScissor(0, 0, 100, 100)
            love.graphics.intersectScissor(50, 60, 100, 100)
            local x, y, w, h = love.graphics.getScissor()
            T.eq(x, 50); T.eq(y, 60); T.eq(w, 50); T.eq(h, 40)
        end)

        T.it("disjoint rectangles leave an empty scissor, not a negative one", function()
            love.graphics.setScissor(0, 0, 10, 10)
            love.graphics.intersectScissor(50, 50, 10, 10)
            local _, _, w, h = love.graphics.getScissor()
            T.eq(w, 0); T.eq(h, 0)
        end)

        T.it("pop only reapplies the scissor when the popped level held one", function()
            love.graphics.setScissor()
            local real, calls = lv1lua.gfx.applyScissor, 0
            lv1lua.gfx.applyScissor = function() calls = calls + 1 end
            love.graphics.push()
            love.graphics.translate(5, 5)
            love.graphics.pop()
            T.eq(calls, 0)
            love.graphics.push()
            love.graphics.setScissor(1, 2, 3, 4)
            calls = 0
            love.graphics.pop()
            T.eq(calls, 1)
            T.eq(love.graphics.getScissor(), nil)
            lv1lua.gfx.applyScissor = real
        end)

        T.it("setScissor() with no arguments clears it", function()
            love.graphics.setScissor(1, 2, 3, 4)
            love.graphics.setScissor()
            T.eq(love.graphics.getScissor(), nil)
        end)
    end)
end

__MODE = "PSP"
dofile("tests/setup.lua")
dofile(GFX["PSP"])
T.describe("scissor [PSP] native clip", function()
    T.it("pop of a plain push makes no screen.clip call", function()
        love.graphics.setScissor()
        __rec.reset()
        love.graphics.push()
        love.graphics.pop()
        T.eq(__rec.count("screen.clip"), 0)
    end)

    T.it("an unchanged scissor is not sent to the GPU twice", function()
        love.graphics.setScissor(10, 10, 50, 50)
        __rec.reset()
        love.graphics.setScissor(10, 10, 50, 50)
        T.eq(__rec.count("screen.clip"), 0)
        love.graphics.setScissor(10, 10, 60, 50)
        T.eq(__rec.count("screen.clip"), 1)
        love.graphics.setScissor()
        T.eq(__rec.last("screen.clip").n, 0)
    end)
end)

-- No GPU scissor on the Vita OneLua build or on the PS3: a draw that lies wholly outside the scissor is skipped.
local REJECT = { ["OneLua"] = "image.blit", ["PS3"] = "gfx.End" }
for _, mode in ipairs({ "OneLua", "PS3" }) do
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    local native = REJECT[mode]
    local img = love.graphics.newImage("sheet.png")
    local quad = love.graphics.newQuad(0, 0, 16, 16, img)

    T.describe("scissor [" .. mode .. "] software reject", function()
        T.it("a draw wholly outside the scissor is skipped, one inside is drawn", function()
            love.graphics.origin()
            love.graphics.setScissor(0, 0, 50, 50)
            __rec.reset()
            love.graphics.draw(img, 200, 200)
            T.eq(__rec.count(native), 0)
            love.graphics.draw(img, 10, 10)
            T.eq(__rec.count(native), 1)
            love.graphics.setScissor()
        end)

        T.it("a quad draw straddling the edge is still drawn", function()
            love.graphics.origin()
            love.graphics.setScissor(0, 0, 50, 50)
            __rec.reset()
            love.graphics.draw(img, quad, 45, 45)
            T.eq(__rec.count(native), 1)
            love.graphics.draw(img, quad, 60, 10)
            T.eq(__rec.count(native), 1)
            love.graphics.setScissor()
        end)

        T.it("the scissor ignores the transform stack and a rotated sprite uses its turned box", function()
            love.graphics.origin()
            love.graphics.setScissor(0, 0, 50, 50)
            love.graphics.translate(100, 100)
            __rec.reset()
            love.graphics.draw(img, quad, 0, 0)
            T.eq(__rec.count(native), 0)
            love.graphics.origin()
            love.graphics.draw(img, quad, 8, 8, 1, 1, 1, 8, 8)
            T.eq(__rec.count(native), 1)
            love.graphics.setScissor()
        end)

        T.it("with no scissor everything is drawn", function()
            love.graphics.origin()
            love.graphics.setScissor()
            __rec.reset()
            love.graphics.draw(img, 900, 900)
            T.eq(__rec.count(native), 1)
        end)
    end)
end

io.write("\n=== scissor ===\n")
return T.summary()
