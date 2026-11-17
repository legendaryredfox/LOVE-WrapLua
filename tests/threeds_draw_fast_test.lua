-- lpp-3ds quad draw: the whole-texel inset rectangle is kept on the quad and must follow a viewport or
-- inset change.

local T = dofile("tests/runner.lua")
__MODE = "3DS"
dofile("tests/setup.lua")
dofile("LOVE-WrapLua/3DS/graphics.lua")

local function fresh()
    if lv1lua.gfx.inFrame then lv1lua.gfx.endFrame() end
    __rec.reset()
    lv1lua.gfx.beginFrame()
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setTextureInset(0)
end

T.describe("lpp-3ds quad draw", function()
    T.it("a quad draw passes its viewport to the native call", function()
        fresh()
        local img = love.graphics.newImage("sheet.png")
        local q = love.graphics.newQuad(8, 16, 12, 10, img)
        love.graphics.draw(img, q, 30, 40)
        local c = __rec.last("Graphics.drawImageExtended").args
        T.eq(c[3], 8); T.eq(c[4], 16); T.eq(c[5], 12); T.eq(c[6], 10)
        T.eq(c[1], 30 + 6); T.eq(c[2], 40 + 5)
    end)

    T.it("setViewport takes effect on the next draw", function()
        fresh()
        local img = love.graphics.newImage("sheet.png")
        local q = love.graphics.newQuad(0, 0, 8, 8, img)
        love.graphics.draw(img, q, 0, 0)
        q:setViewport(16, 24, 4, 6)
        love.graphics.draw(img, q, 0, 0)
        local c = __rec.last("Graphics.drawImageExtended").args
        T.eq(c[3], 16); T.eq(c[4], 24); T.eq(c[5], 4); T.eq(c[6], 6)
    end)

    T.it("setTextureInset takes effect on a quad already drawn", function()
        fresh()
        local img = love.graphics.newImage("sheet.png")
        local q = love.graphics.newQuad(8, 8, 16, 16, img)
        love.graphics.draw(img, q, 0, 0)
        T.eq(__rec.last("Graphics.drawImageExtended").args[3], 8)
        love.graphics.setTextureInset(1)
        love.graphics.draw(img, q, 0, 0)
        local c = __rec.last("Graphics.drawImageExtended").args
        T.eq(c[3], 9); T.eq(c[5], 14)
        love.graphics.setTextureInset(0)
        love.graphics.draw(img, q, 0, 0)
        T.eq(__rec.last("Graphics.drawImageExtended").args[3], 8)
    end)

    T.it("a quad draw reads the cached rectangle, not getViewport", function()
        fresh()
        local img = love.graphics.newImage("sheet.png")
        local q = love.graphics.newQuad(0, 0, 8, 8, img)
        love.graphics.draw(img, q, 0, 0)
        local calls = 0
        local real = q.getViewport
        q.getViewport = function(self) calls = calls + 1; return real(self) end
        love.graphics.draw(img, q, 0, 0)
        T.eq(calls, 0)
    end)
end)

io.write("\n=== lpp-3ds quad draw ===\n")
return T.summary()
