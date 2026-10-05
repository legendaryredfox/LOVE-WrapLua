-- Images and quads follow the transform stack the same way primitives do
-- (FIX_PLAN T7.7).
--
-- A point maps as p * S + O and a size as w * S, where S and O are the
-- flattened stack scale and offset. lpp-vita, PS3 and the 3DS already did this;
-- the PSP ignored the stack outright, and OneLua Vita folded it two different
-- wrong ways (plain image x + O * S, quad x + O), so with a scale active the
-- same sprite landed in three places. Both OneLua targets are checked here
-- against the rectangle in the same frame, which T5.2 already pins.

local T = dofile("tests/runner.lua")

local GFX = {
    ["PSP"]    = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["OneLua"] = "LOVE-WrapLua/OneLua/graphics.lua",
}

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    love.graphics.origin()
    __rec.reset()
end

local function blitAt()
    local a = __rec.last("image.blit").args
    return a[2], a[3]
end

for _, mode in ipairs({ "PSP", "OneLua" }) do
    load_backend(mode)
    local img = love.graphics.newImage("sheet.png")   -- 64x64 in the mock
    local full = love.graphics.newQuad(0, 0, 64, 64, img)

    T.describe("images follow the transform [" .. mode .. "]", function()
        T.it("translate moves an image", function()
            love.graphics.origin()
            love.graphics.translate(7, 3)
            __rec.reset()
            love.graphics.draw(img, 1, 1)
            local x, y = blitAt()
            T.eq(x, 8)
            T.eq(y, 4)
            love.graphics.origin()
        end)

        T.it("image, full-sheet quad and rectangle share one point", function()
            love.graphics.origin()
            love.graphics.scale(2, 2)
            love.graphics.translate(10, 0)
            __rec.reset()
            love.graphics.draw(img, 5, 0)
            T.eq((blitAt()), 30)
            __rec.reset()
            love.graphics.draw(img, full, 5, 0)
            T.eq((blitAt()), 30)
            __rec.reset()
            love.graphics.rectangle("fill", 5, 0, 1, 1)
            T.eq(__rec.last("draw.fillrect").args[1], 30)
            love.graphics.origin()
        end)

        T.it("the stack scale reaches the image size", function()
            -- A fresh image: the scaled copy of `img` is already cached.
            local fresh = love.graphics.newImage("other.png")
            love.graphics.origin()
            love.graphics.scale(2, 2)
            __rec.reset()
            love.graphics.draw(fresh, 0, 0)
            local a = __rec.last("image.copyscale").args
            T.eq(a[2], 128)
            T.eq(a[3], 128)
            love.graphics.origin()
        end)

        T.it("the origin offset is scaled by the whole scale", function()
            love.graphics.origin()
            love.graphics.scale(2, 2)
            love.graphics.translate(10, 0)
            __rec.reset()
            love.graphics.draw(img, 5, 0, 0, 1, 1, 2, 0)
            T.eq((blitAt()), 26)
            love.graphics.origin()
        end)

        T.it("stack rotation adds to the draw rotation", function()
            love.graphics.origin()
            love.graphics.rotate(math.pi / 2)
            __rec.reset()
            love.graphics.draw(img, 0, 0, math.pi / 2)
            T.near(__rec.last("image.rotate").args[2], 180, 1e-9)
            love.graphics.origin()
        end)

        T.it("pop restores the untransformed position", function()
            love.graphics.origin()
            love.graphics.push()
            love.graphics.translate(40, 40)
            love.graphics.pop()
            __rec.reset()
            love.graphics.draw(img, 3, 4)
            local x, y = blitAt()
            T.eq(x, 3)
            T.eq(y, 4)
        end)
    end)
end

load_backend("PSP")
local img = love.graphics.newImage("sheet.png")
T.describe("PSP transform surface", function()
    T.it("transformPoint maps through the stack", function()
        love.graphics.origin()
        love.graphics.scale(2, 2)
        love.graphics.translate(10, 0)
        local x, y = love.graphics.transformPoint(5, 1)
        T.eq(x, 30)
        T.eq(y, 2)
        love.graphics.origin()
    end)

    T.it("a stack mirror grows the image left from the anchor", function()
        love.graphics.origin()
        love.graphics.scale(-1, 1)
        __rec.reset()
        love.graphics.draw(img, 10, 0)
        T.eq((blitAt()), -74)
        T.eq(__rec.count("image.fliph"), 1)
        love.graphics.origin()
    end)
end)

io.write("\n=== images vs transform stack ===\n")
return T.summary()
