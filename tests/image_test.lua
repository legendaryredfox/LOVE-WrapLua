-- love.graphics Image objects across every backend (FIX_PLAN T7.6).
--
-- The SDKs hand back bare texture handles: an integer on lpp-vita and lpp-3ds,
-- userdata on OneLua, a tiny3D table on the PS3. Games call Image methods on
-- what newImage returns (anim8 asks for getWidth), so on a console a bare
-- handle crashes the first such call. Every backend has to return the same
-- object, and every draw path has to reach the native call with the handle.

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
    ["3DS"]      = "LOVE-WrapLua/3DS/graphics.lua",
}

-- The native call an unscaled, unrotated draw ends in, and which of its
-- arguments carries the texture.
local BLIT = {
    ["OneLua"]   = { name = "image.blit",              arg = 1 },
    ["PSP"]      = { name = "image.blit",              arg = 1 },
    ["lpp-vita"] = { name = "Graphics.drawScaleImage", arg = 3 },
    ["PS3"]      = { name = "gfx.SetTexture",          arg = 1 },
    ["3DS"]      = { name = "Graphics.drawScaleImage", arg = 3 },
}

local MODES = { "OneLua", "PSP", "lpp-vita", "PS3", "3DS" }

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
end

-- Draws the way love.draw does: inside the GPU frame where there is one.
local function in_frame(fn)
    local gfx = lv1lua.gfx
    if gfx.beginFrame then gfx.beginFrame() end
    local ok, err = pcall(fn)
    if gfx.endFrame then gfx.endFrame() end
    if not ok then error(err, 0) end
end

for _, mode in ipairs(MODES) do
    load_backend(mode)

    T.describe("Image [" .. mode .. "]", function()
        T.it("newImage returns a LOVE Image, not a bare handle", function()
            local img = love.graphics.newImage("sheet.png")
            T.istype(img, "table")
            T.eq(img:type(), "Image")
            T.ok(img:typeOf("Image") and img:typeOf("Texture")
                 and img:typeOf("Drawable") and img:typeOf("Object"))
            T.nok(img:typeOf("Canvas"))
        end)

        T.it("reports its size every way LOVE asks", function()
            local img = love.graphics.newImage("sheet.png")
            T.eq(img:getWidth(), 64)
            T.eq(img:getHeight(), 64)
            local w, h = img:getDimensions()
            T.eq(w, 64); T.eq(h, 64)
            local pw, ph = img:getPixelDimensions()
            T.eq(pw, 64); T.eq(ph, 64)
            T.eq(img:getDPIScale(), 1)
        end)

        T.it("answers the Texture queries", function()
            local img = love.graphics.newImage("sheet.png")
            T.eq(img:getTextureType(), "2d")
            T.eq(img:getMipmapCount(), 1)
            T.istype(img:getFormat(), "string")
            T.nok(img:isCompressed())
        end)

        T.it("takes the default filter and round-trips setFilter", function()
            love.graphics.setDefaultFilter("nearest", "nearest")
            local img = love.graphics.newImage("sheet.png")
            local min, mag = img:getFilter()
            T.eq(min, "nearest"); T.eq(mag, "nearest")
            img:setFilter("linear", "nearest")
            min, mag = img:getFilter()
            T.eq(min, "linear"); T.eq(mag, "nearest")
            love.graphics.setDefaultFilter("linear", "linear")
        end)

        T.it("round-trips setWrap", function()
            local img = love.graphics.newImage("sheet.png")
            T.eq(img:getWrap(), "clamp")
            img:setWrap("repeat", "mirroredrepeat")
            local h, v = img:getWrap()
            T.eq(h, "repeat"); T.eq(v, "mirroredrepeat")
        end)

        T.it("newQuad(x,y,w,h, image) measures the image", function()
            local img = love.graphics.newImage("sheet.png")
            local sw, sh = love.graphics.newQuad(0, 0, 16, 16, img):getTextureDimensions()
            T.eq(sw, 64); T.eq(sh, 64)
        end)

        T.it("a draw reaches the native call with the native texture", function()
            local img = love.graphics.newImage("sheet.png")
            __rec.reset()
            in_frame(function() love.graphics.draw(img, 10, 20) end)
            local c = __rec.last(BLIT[mode].name)
            T.ok(c, BLIT[mode].name .. " was called")
            T.ok(c.args[BLIT[mode].arg] == img._tex,
                 "the native handle, not the Image object, reaches the SDK")
        end)

        T.it("a quad draw reaches the SDK too", function()
            local img = love.graphics.newImage("sheet.png")
            local q = love.graphics.newQuad(0, 0, 16, 16, img)
            local ok, err = pcall(in_frame, function() love.graphics.draw(img, q, 10, 20) end)
            T.ok(ok, tostring(err))
        end)

        T.it("a SpriteBatch keeps the Image it was given", function()
            local img = love.graphics.newImage("sheet.png")
            T.ok(love.graphics.newSpriteBatch(img, 4):getImage() == img)
        end)

        T.it("release drops the texture once", function()
            local img = love.graphics.newImage("sheet.png")
            T.ok(img:release())
            T.nok(img:release())
        end)

        T.it("anim8-style probing works (image.getWidth and image:getWidth())", function()
            local img = love.graphics.newImage("sheet.png")
            local w = img.getWidth and img:getWidth()
            T.eq(w, 64)
        end)
    end)
end

-- ── Native filters where the SDK has them ────────────────────────
load_backend("lpp-vita")
T.describe("Image filters [lpp-vita native]", function()
    T.it("setFilter reaches Graphics.setImageFilters with the vita2d constants", function()
        local img = love.graphics.newImage("sheet.png")
        __rec.reset()
        img:setFilter("nearest", "linear")
        local c = __rec.last("Graphics.setImageFilters")
        T.ok(c, "setImageFilters was called")
        T.ok(c.args[1] == img._tex)
        T.eq(c.args[2], FILTER_POINT)
        T.eq(c.args[3], FILTER_LINEAR)
    end)

    T.it("a new image gets the default filter natively", function()
        love.graphics.setDefaultFilter("nearest", "nearest")
        __rec.reset()
        local img = love.graphics.newImage("sheet.png")
        local c = __rec.last("Graphics.setImageFilters")
        T.ok(c and c.args[1] == img._tex, "the default filter reached the texture")
        T.eq(c.args[2], FILTER_POINT)
        love.graphics.setDefaultFilter("linear", "linear")
    end)

    T.it("release frees the native texture", function()
        local img = love.graphics.newImage("sheet.png")
        local tex = img._tex
        __rec.reset()
        img:release()
        local c = __rec.last("Graphics.freeImage")
        T.ok(c and c.args[1] == tex)
    end)
end)

io.write("\n=== Image objects (T7.6) ===\n")
return T.summary()
