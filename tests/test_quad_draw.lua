-- Quad drawing details found in the whole-repo review (CODE_REVIEW R3, R8, R9,
-- R10).
--
-- The quad path is the one a spritesheet game leans on every frame, and it had
-- drifted away from the plain image path: a rebuilt scale buffer freed the
-- wrong handle, the destination formula differed between the two paths, and the
-- texture dimensions a Quad reports depended on which backend built it.

local T = dofile("tests/runner.lua")

local function load_backend(mode, gfx)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(gfx)
    __rec.reset()
end

-- ── OneLua ───────────────────────────────────────────────────────
load_backend("OneLua", "LOVE-WrapLua/OneLua/graphics.lua")

T.describe("OneLua quad buffer", function()
    T.it("rebuilding the scaled buffer does not free the source image", function()
        local img = love.graphics.newImage("sheet.png")
        local q   = love.graphics.newQuad(0, 0, 16, 16, img)
        local lost = {}
        local realLost = image.lost
        image.lost = function(h) lost[#lost + 1] = h end

        love.graphics.draw(img, q, 0, 0, 0, 1, 1)
        love.graphics.draw(img, q, 0, 0, 0, 2, 2)  -- scale change rebuilds it

        image.lost = realLost
        for _, h in ipairs(lost) do
            T.ok(h ~= img.imgData, "the source sheet must never be freed")
        end
    end)

    T.it("the freed handle is the stale buffer", function()
        local img = love.graphics.newImage("sheet.png")
        local q   = love.graphics.newQuad(0, 0, 16, 16, img)
        local lost = {}
        local realLost = image.lost
        image.lost = function(h) lost[#lost + 1] = h end

        love.graphics.draw(img, q, 0, 0, 0, 1, 1)
        local firstBuffer = q._bufferImage
        love.graphics.draw(img, q, 0, 0, 0, 3, 3)

        image.lost = realLost
        T.eq(#lost, 1)
        T.ok(lost[1] == firstBuffer, "expected the previous buffer to be freed")
    end)
end)

T.describe("OneLua quad destination", function()
    -- A quad covering the whole sheet must land exactly where the plain image
    -- draw lands: the two paths used different formulas once a scale was on.
    local function destOf(fn)
        __rec.reset()
        fn()
        local blit = __rec.last("image.blit")
        return blit.args[2], blit.args[3]
    end

    T.it("matches the plain draw at scale 1", function()
        love.graphics.origin()
        local img = love.graphics.newImage("sheet.png")
        local q   = love.graphics.newQuad(0, 0, 64, 64, img)
        local px, py = destOf(function() love.graphics.draw(img, 30, 40) end)
        local qx, qy = destOf(function() love.graphics.draw(img, q, 30, 40) end)
        T.eq(qx, px)
        T.eq(qy, py)
    end)

    T.it("matches the plain draw at scale 2", function()
        love.graphics.origin()
        local img = love.graphics.newImage("sheet.png")
        local q   = love.graphics.newQuad(0, 0, 64, 64, img)
        local px, py = destOf(function() love.graphics.draw(img, 30, 40, 0, 2, 2) end)
        local qx, qy = destOf(function() love.graphics.draw(img, q, 30, 40, 0, 2, 2) end)
        T.eq(qx, px)
        T.eq(qy, py)
    end)

    T.it("matches the plain draw under a translate", function()
        love.graphics.origin()
        local img = love.graphics.newImage("sheet.png")
        local q   = love.graphics.newQuad(0, 0, 64, 64, img)
        love.graphics.translate(25, 15)
        local px, py = destOf(function() love.graphics.draw(img, 10, 10) end)
        local qx, qy = destOf(function() love.graphics.draw(img, q, 10, 10) end)
        love.graphics.origin()
        T.eq(qx, px)
        T.eq(qy, py)
    end)
end)

-- ── Quad texture dimensions, every backend ───────────────────────
local BACKENDS = {
    { mode = "OneLua",   gfx = "LOVE-WrapLua/OneLua/graphics.lua" },
    { mode = "PSP",      gfx = "LOVE-WrapLua/OneLua/graphics_psp.lua" },
    { mode = "lpp-vita", gfx = "LOVE-WrapLua/lpp-vita/graphics.lua" },
    { mode = "PS3",      gfx = "LOVE-WrapLua/PS3/graphics.lua" },
}

for _, b in ipairs(BACKENDS) do
    load_backend(b.mode, b.gfx)
    T.describe("Quad texture dimensions [" .. b.mode .. "]", function()
        T.it("newQuad(x,y,w,h, image) reports the image size, not the quad size", function()
            local img = love.graphics.newImage("sheet.png")  -- the mocks are 64x64
            local q   = love.graphics.newQuad(0, 0, 16, 16, img)
            local sw, sh = q:getTextureDimensions()
            T.eq(sw, 64)
            T.eq(sh, 64)
        end)

        T.it("newQuad(x,y,w,h, sw,sh) keeps the explicit size", function()
            local q = love.graphics.newQuad(0, 0, 16, 16, 128, 96)
            local sw, sh = q:getTextureDimensions()
            T.eq(sw, 128)
            T.eq(sh, 96)
        end)

        T.it("the viewport round-trips", function()
            local q = love.graphics.newQuad(4, 8, 16, 32, 64, 64)
            local x, y, w, h = q:getViewport()
            T.eq(x, 4); T.eq(y, 8); T.eq(w, 16); T.eq(h, 32)
            q:setViewport(1, 2, 3, 4)
            x, y, w, h = q:getViewport()
            T.eq(x, 1); T.eq(y, 2); T.eq(w, 3); T.eq(h, 4)
        end)
    end)
end

-- ── validateTexture must not choke on a non-numeric size ─────────
load_backend("PSP", "LOVE-WrapLua/OneLua/graphics_psp.lua")
T.describe("core/capabilities.validateTexture", function()
    T.it("ignores a size it cannot read instead of erroring", function()
        local ok = pcall(lv1lua.core.validateTexture, {}, nil, "weird")
        T.ok(ok, "a non-numeric size must not raise")
    end)
end)

io.write("\n=== quad draw + quad dimensions ===\n")
return T.summary()
