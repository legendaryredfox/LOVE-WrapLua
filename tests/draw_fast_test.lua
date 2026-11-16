-- OneLua draw fast paths: the inset quad rectangle is kept on the quad, and a rotation the sheet already
-- has is not sent to the SDK again. Both must follow a change.

local T = dofile("tests/runner.lua")

local GFX = {
    PSP      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    OneLua   = "LOVE-WrapLua/OneLua/graphics.lua",
}

for _, mode in ipairs({ "PSP", "OneLua" }) do
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    local function fresh()
        __rec.reset()
        love.graphics.origin()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setTextureInset(0)
    end

    T.describe("draw fast paths [" .. mode .. "]", function()
        T.it("a quad draw blits its viewport", function()
            fresh()
            local img = love.graphics.newImage("sheet.png")
            local q = love.graphics.newQuad(8, 16, 12, 10, img)
            love.graphics.draw(img, q, 30, 40)
            local b = __rec.last("image.blit").args
            T.eq(b[2], 30); T.eq(b[3], 40)
            T.eq(b[4], 8); T.eq(b[5], 16); T.eq(b[6], 12); T.eq(b[7], 10)
        end)

        T.it("setViewport takes effect on the next draw", function()
            fresh()
            local img = love.graphics.newImage("sheet.png")
            local q = love.graphics.newQuad(0, 0, 8, 8, img)
            love.graphics.draw(img, q, 0, 0)
            q:setViewport(16, 24, 4, 6)
            love.graphics.draw(img, q, 0, 0)
            local b = __rec.last("image.blit").args
            T.eq(b[4], 16); T.eq(b[5], 24); T.eq(b[6], 4); T.eq(b[7], 6)
        end)

        T.it("setTextureInset takes effect on a quad already drawn", function()
            fresh()
            local img = love.graphics.newImage("sheet.png")
            local q = love.graphics.newQuad(8, 8, 16, 16, img)
            love.graphics.draw(img, q, 0, 0)
            T.eq(__rec.last("image.blit").args[4], 8)
            love.graphics.setTextureInset(0.5)
            love.graphics.draw(img, q, 0, 0)
            local b = __rec.last("image.blit").args
            T.eq(b[4], 8.5); T.eq(b[6], 15)
            love.graphics.setTextureInset(0)
            love.graphics.draw(img, q, 0, 0)
            T.eq(__rec.last("image.blit").args[4], 8)
        end)

        T.it("an upright sheet is not told to rotate again", function()
            fresh()
            local img = love.graphics.newImage("sheet.png")
            local q = love.graphics.newQuad(0, 0, 8, 8, img)
            love.graphics.draw(img, q, 0, 0)
            local n = __rec.count("image.rotate")
            love.graphics.draw(img, q, 5, 5)
            love.graphics.draw(img, 9, 9)
            T.eq(__rec.count("image.rotate"), n)
        end)

        T.it("a turn is applied, and the next upright draw turns it back", function()
            fresh()
            local img = love.graphics.newImage("sheet.png")
            local q = love.graphics.newQuad(0, 0, 8, 8, img)
            love.graphics.draw(img, q, 0, 0)
            love.graphics.draw(img, q, 0, 0, math.pi / 2)
            T.near(__rec.last("image.rotate").args[2], 90, 1e-6)
            love.graphics.draw(img, q, 0, 0)
            T.eq(__rec.last("image.rotate").args[2], 0)
        end)

        T.it("the same turn twice is sent once", function()
            fresh()
            local img = love.graphics.newImage("sheet.png")
            love.graphics.draw(img, 0, 0, 1)
            local n = __rec.count("image.rotate")
            love.graphics.draw(img, 4, 4, 1)
            T.eq(__rec.count("image.rotate"), n)
        end)

        T.it("a quad with an origin and no scale still shifts by the origin", function()
            fresh()
            local img = love.graphics.newImage("sheet.png")
            local q = love.graphics.newQuad(0, 0, 8, 8, img)
            love.graphics.draw(img, q, 50, 60, 0, 1, 1, 4, 2)
            local b = __rec.last("image.blit").args
            T.eq(b[2], 46); T.eq(b[3], 58)
        end)

        T.it("a sprite batch still replays through draw", function()
            fresh()
            local img = love.graphics.newImage("sheet.png")
            local q = love.graphics.newQuad(0, 0, 8, 8, img)
            local sb = love.graphics.newSpriteBatch(img, 4)
            sb:add(q, 3, 4)
            love.graphics.draw(sb, 10, 10)
            T.eq(__rec.last("image.blit").args[2], 13)
        end)
    end)
end

io.write("\n=== draw fast paths ===\n")
return T.summary()
