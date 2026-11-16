-- lpp-vita draw fast paths: the whole-texel inset rectangle is kept on the quad and must follow a viewport
-- or inset change; an unrotated draw skips the trigonometry but lands where the general formula puts it.

local T = dofile("tests/runner.lua")
__MODE = "lpp-vita"
dofile("tests/setup.lua")
dofile("LOVE-WrapLua/lpp-vita/graphics.lua")

local function fresh()
    __rec.reset()
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setTextureInset(0)
end

T.describe("lpp-vita draw fast paths", function()
    T.it("a quad draw passes its viewport to the native call", function()
        fresh()
        local img = love.graphics.newImage("sheet.png")
        local q = love.graphics.newQuad(8, 16, 12, 10, img)
        love.graphics.draw(img, q, 30, 40)
        local c = __rec.last("Graphics.drawImageExtended").args
        T.eq(c[4], 8); T.eq(c[5], 16); T.eq(c[6], 12); T.eq(c[7], 10)
        T.eq(c[1], 30 + 6); T.eq(c[2], 40 + 5)          -- centre of the 12x10 rect
    end)

    T.it("setViewport takes effect on the next draw", function()
        fresh()
        local img = love.graphics.newImage("sheet.png")
        local q = love.graphics.newQuad(0, 0, 8, 8, img)
        love.graphics.draw(img, q, 0, 0)
        q:setViewport(16, 24, 4, 6)
        love.graphics.draw(img, q, 0, 0)
        local c = __rec.last("Graphics.drawImageExtended").args
        T.eq(c[4], 16); T.eq(c[5], 24); T.eq(c[6], 4); T.eq(c[7], 6)
    end)

    T.it("setTextureInset takes effect on a quad already drawn", function()
        fresh()
        local img = love.graphics.newImage("sheet.png")
        local q = love.graphics.newQuad(8, 8, 16, 16, img)
        love.graphics.draw(img, q, 0, 0)
        T.eq(__rec.last("Graphics.drawImageExtended").args[4], 8)
        love.graphics.setTextureInset(1)
        love.graphics.draw(img, q, 0, 0)
        local c = __rec.last("Graphics.drawImageExtended").args
        T.eq(c[4], 9); T.eq(c[6], 14)
        love.graphics.setTextureInset(0)
        love.graphics.draw(img, q, 0, 0)
        T.eq(__rec.last("Graphics.drawImageExtended").args[4], 8)
    end)

    T.it("an unrotated origin and scale shift the centre as the general formula does", function()
        fresh()
        local img = love.graphics.newImage("sheet.png")
        local q = love.graphics.newQuad(0, 0, 16, 8, img)
        love.graphics.draw(img, q, 100, 50, 0, 2, 3, 4, 2)
        local c = __rec.last("Graphics.drawImageExtended").args
        T.eq(c[1], 100 + (8 - 4) * 2)
        T.eq(c[2], 50 + (4 - 2) * 3)
        T.eq(c[9], 2); T.eq(c[10], 3)
    end)

    T.it("an unrotated draw wholly outside the scissor is skipped", function()
        fresh()
        local img = love.graphics.newImage("sheet.png")
        local q = love.graphics.newQuad(0, 0, 8, 8, img)
        love.graphics.setScissor(0, 0, 10, 10)
        love.graphics.draw(img, q, 200, 200)
        T.eq(__rec.count("Graphics.drawImageExtended"), 0)
        love.graphics.draw(img, q, 2, 2)
        T.eq(__rec.count("Graphics.drawImageExtended"), 1)
        love.graphics.setScissor()
    end)

    T.it("a mirrored unrotated draw is rejected on the side it covers", function()
        fresh()
        local img = love.graphics.newImage("sheet.png")
        local q = love.graphics.newQuad(0, 0, 8, 8, img)
        love.graphics.setScissor(0, 0, 10, 10)
        love.graphics.draw(img, q, 12, 2, 0, -1, 1)      -- covers x 4..12
        T.eq(__rec.count("Graphics.drawImageExtended"), 1)
        love.graphics.setScissor()
    end)

    T.it("a sprite batch still replays through draw", function()
        fresh()
        local img = love.graphics.newImage("sheet.png")
        local q = love.graphics.newQuad(0, 0, 8, 8, img)
        local sb = love.graphics.newSpriteBatch(img, 4)
        sb:add(q, 3, 4)
        love.graphics.draw(sb, 10, 10)
        T.eq(__rec.count("Graphics.drawImageExtended"), 1)
    end)
end)

io.write("\n=== lpp-vita draw fast paths ===\n")
return T.summary()
