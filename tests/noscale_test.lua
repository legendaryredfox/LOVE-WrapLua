-- OneLua builds without image.copyscale (the PSP EBOOT.PBP in this repo).
--
-- There a sub-rect blit ignores any scale and draws 1:1, but a whole-image
-- blit follows image.resize on the GPU. So a scaled draw resizes the sheet to
-- its final size, blits it whole at an offset, and clips to the destination
-- rectangle with screen.clip. Measured on the real EBOOT in PPSSPP.

local T = dofile("tests/runner.lua")

__MODE = "PSP"
dofile("tests/setup.lua")
dofile("LOVE-WrapLua/OneLua/graphics_psp.lua")
image.copyscale = nil
__rec.reset()

local function sheet() return love.graphics.newImage("sheet.png") end  -- 64x64 in the mock

T.describe("PSP draw without copyscale", function()
    T.it("a scaled quad resizes the sheet, blits it whole, clips to the quad", function()
        love.graphics.origin()
        local img = sheet()
        local q = love.graphics.newQuad(16, 32, 16, 8, img)
        __rec.reset()
        love.graphics.draw(img, q, 100, 50, 0, 3, 2)
        local rs = __rec.all("image.resize")
        T.eq(rs[1].args[2], 192); T.eq(rs[1].args[3], 128)   -- 64*3, 64*2
        local blit = __rec.last("image.blit")
        T.eq(blit.args[2], 100 - 16 * 3)                      -- sheet offset
        T.eq(blit.args[3], 50 - 32 * 2)
        local clip = __rec.all("screen.clip")[1]
        T.eq(clip.args[1], 100); T.eq(clip.args[2], 50)
        T.eq(clip.args[3], 48);  T.eq(clip.args[4], 16)       -- 16*3 x 8*2
        T.eq(__rec.count("image.copyscale"), 0)
    end)

    T.it("restores the shared sheet size and the clip afterwards", function()
        love.graphics.origin()
        local img = sheet()
        local q = love.graphics.newQuad(0, 0, 16, 16, img)
        __rec.reset()
        love.graphics.draw(img, q, 0, 0, 0, 2, 2)
        local rs = __rec.all("image.resize")
        T.eq(#rs, 2)
        T.eq(rs[2].args[2], 64); T.eq(rs[2].args[3], 64)
        local clips = __rec.all("screen.clip")
        T.eq(#clips[#clips].args, 0)                          -- screen.clip()
    end)

    T.it("a whole image scales the same way", function()
        love.graphics.origin()
        local img = sheet()
        __rec.reset()
        love.graphics.draw(img, 10, 20, 0, 2, 2)
        local clip = __rec.all("screen.clip")[1]
        T.eq(clip.args[1], 10); T.eq(clip.args[2], 20)
        T.eq(clip.args[3], 128); T.eq(clip.args[4], 128)
        local blit = __rec.last("image.blit")
        T.eq(blit.args[2], 10); T.eq(blit.args[3], 20)
    end)

    T.it("a mirrored draw blits a flipped private copy, never the source", function()
        love.graphics.origin()
        local img = sheet()
        local q = love.graphics.newQuad(0, 0, 16, 16, img)
        __rec.reset()
        love.graphics.draw(img, q, 100, 0, 0, -2, 2)
        love.graphics.draw(img, q, 100, 0, 0, -2, 2)
        T.eq(__rec.count("image.copy"), 1)                    -- cached
        T.eq(__rec.count("image.fliph"), 1)
        for _, c in ipairs(__rec.all("image.fliph")) do
            T.ok(c.args[1] ~= img.imgData, "source flipped in place")
        end
        for _, c in ipairs(__rec.all("image.blit")) do
            T.ok(c.args[1] ~= img.imgData, "source blitted while mirrored")
        end
        -- grows left from the anchor by the scaled quad width (32)
        T.eq(__rec.all("screen.clip")[1].args[1], 100 - 32)
    end)

    T.it("an unscaled draw keeps the plain sub-rect blit", function()
        love.graphics.origin()
        local img = sheet()
        local q = love.graphics.newQuad(8, 8, 16, 16, img)
        __rec.reset()
        love.graphics.draw(img, q, 5, 5)
        T.eq(__rec.count("screen.clip"), 0)
        T.eq(__rec.count("image.resize"), 0)
        T.eq(__rec.last("image.blit").args[4], 8)
    end)

    T.it("a rotated draw clips to the turned bounds and recentres the sheet", function()
        love.graphics.origin()
        local img = sheet()
        local q = love.graphics.newQuad(0, 0, 16, 16, img)
        __rec.reset()
        love.graphics.draw(img, q, 100, 100, math.pi / 2, 2, 2)
        local clip = __rec.all("screen.clip")[1]
        -- 32x32 square turned a quarter about its centre keeps its bounds
        T.eq(clip.args[1], 100); T.eq(clip.args[2], 100)
        T.eq(clip.args[3], 32);  T.eq(clip.args[4], 32)
        T.eq(__rec.last("image.rotate").args[2], 90)
        -- pivot on the quad's centre, in unscaled sheet pixels, blit there
        local cs = __rec.all("image.center")
        T.eq(cs[1].args[2], 8); T.eq(cs[1].args[3], 8)
        T.eq(cs[#cs].args[2], 0); T.eq(cs[#cs].args[3], 0)   -- corner pivot restored
        T.eq(__rec.last("image.blit").args[2], 116)
        T.eq(__rec.last("image.blit").args[3], 116)
    end)

    T.it("stays inside a scissor the game set, then restores it", function()
        love.graphics.origin()
        local img = sheet()
        local q = love.graphics.newQuad(0, 0, 16, 16, img)
        love.graphics.setScissor(110, 0, 100, 100)
        __rec.reset()
        love.graphics.draw(img, q, 100, 50, 0, 2, 2)
        local c = __rec.all("screen.clip")
        T.eq(c[1].args[1], 110); T.eq(c[1].args[3], 22)       -- 100..132 cut at 110
        T.eq(c[#c].args[1], 110); T.eq(c[#c].args[3], 100)    -- scissor back
        love.graphics.setScissor()
    end)

    T.it("skips a draw wholly outside the scissor", function()
        love.graphics.origin()
        local img = sheet()
        local q = love.graphics.newQuad(0, 0, 16, 16, img)
        love.graphics.setScissor(0, 0, 10, 10)
        __rec.reset()
        love.graphics.draw(img, q, 200, 200, 0, 2, 2)
        T.eq(__rec.count("image.blit"), 0)
        love.graphics.setScissor()
    end)
end)

T.describe("PSP scissor hook", function()
    T.it("setScissor drives screen.clip and clearing it resets", function()
        __rec.reset()
        love.graphics.setScissor(5.7, 6.2, 40, 30)
        local c = __rec.last("screen.clip")
        T.eq(c.args[1], 5); T.eq(c.args[2], 6)
        love.graphics.setScissor()
        T.eq(#__rec.last("screen.clip").args, 0)
    end)
end)

io.write("\n=== draw without copyscale ===\n")
return T.summary()
