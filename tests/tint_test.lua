-- Image tint (FIX_PLAN T6.8).
--
-- setColor with non-white RGB must modulate drawn images. OneLua exposes
-- image.blittint(img, x, y, color) for whole-image tinting (no source rect),
-- so tint applies to plain draws but not to quad sub-rect draws on OL / PSP.
-- lpp-vita already passes the full color to drawImageExtended / drawScaleImage
-- and is checked here only as a regression guard.

local T = dofile("tests/runner.lua")

local function fresh(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile("LOVE-WrapLua/core/loader.lua")
    lv1lua.load("LOVE-WrapLua/core/util.lua")
    lv1lua.load("LOVE-WrapLua/core/transform.lua")
    lv1lua.load("LOVE-WrapLua/core/textwrap.lua")
    lv1lua.load("LOVE-WrapLua/core/capabilities.lua")
    lv1lua.load("LOVE-WrapLua/core/objects.lua")
    lv1lua.load("LOVE-WrapLua/core/texinset.lua")
    lv1lua.load("LOVE-WrapLua/core/polyfill.lua")
    if mode == "PSP" then
        lv1lua.load("LOVE-WrapLua/OneLua/graphics_psp.lua")
    elseif mode == "OneLua" then
        lv1lua.load("LOVE-WrapLua/OneLua/graphics.lua")
    elseif mode == "lpp-vita" then
        lv1lua.load("LOVE-WrapLua/lpp-vita/graphics.lua")
    else
        lv1lua.load("LOVE-WrapLua/PS3/graphics.lua")
    end
    __rec.reset()
end

-- ── PSP tint ─────────────────────────────────────────────────────
T.describe("PSP image tint", function()
    local function drawPlain()
        local img = love.graphics.newImage("sheet.png")
        love.graphics.draw(img, 10, 20)
        return img
    end

    T.it("white color draws through image.blit, not blittint", function()
        fresh("PSP")
        love.graphics.setColor(1, 1, 1, 1)
        drawPlain()
        T.eq(__rec.count("image.blit"), 1)
        T.eq(__rec.count("image.blittint"), 0)
    end)

    T.it("non-white RGB draws through image.blittint", function()
        fresh("PSP")
        love.graphics.setColor(1, 0, 0, 1)
        drawPlain()
        T.eq(__rec.count("image.blittint"), 1)
        T.eq(__rec.count("image.blit"), 0)
    end)

    T.it("the native color handle is passed to blittint", function()
        fresh("PSP")
        love.graphics.setColor(1, 0, 0, 1)
        drawPlain()
        local call = __rec.last("image.blittint").args
        T.eq(call[4], lv1lua.current.color)
    end)

    T.it("white with partial alpha still draws through image.blit", function()
        fresh("PSP")
        love.graphics.setColor(1, 1, 1, 0.5)
        drawPlain()
        T.eq(__rec.count("image.blit"), 1)
        T.eq(__rec.count("image.blittint"), 0)
    end)

    T.it("add blend with non-white uses blitadd, not blittint", function()
        fresh("PSP")
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.setBlendMode("add")
        drawPlain()
        T.eq(__rec.count("image.blitadd"), 1)
        T.eq(__rec.count("image.blittint"), 0)
        T.eq(__rec.count("image.blit"), 0)
    end)

    T.it("quad draw stays on image.blit: blittint has no source-rect form", function()
        fresh("PSP")
        local img  = love.graphics.newImage("sheet.png")
        local quad = love.graphics.newQuad(0, 0, 16, 16, 32, 32)
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.draw(img, quad, 0, 0)
        T.eq(__rec.count("image.blit"), 1)
        T.eq(__rec.count("image.blittint"), 0)
    end)
end)

-- ── OneLua Vita tint ─────────────────────────────────────────────
T.describe("OneLua Vita image tint", function()
    local function drawPlain()
        local img = love.graphics.newImage("sheet.png")
        love.graphics.draw(img, 10, 20)
        return img
    end

    T.it("white color draws through image.blit, not blittint", function()
        fresh("OneLua")
        love.graphics.setColor(1, 1, 1, 1)
        drawPlain()
        T.eq(__rec.count("image.blit"), 1)
        T.eq(__rec.count("image.blittint"), 0)
    end)

    T.it("non-white RGB draws through image.blittint", function()
        fresh("OneLua")
        love.graphics.setColor(0, 1, 0, 1)
        drawPlain()
        T.eq(__rec.count("image.blittint"), 1)
        T.eq(__rec.count("image.blit"), 0)
    end)

    T.it("the native color handle is passed to blittint", function()
        fresh("OneLua")
        love.graphics.setColor(0, 0, 1, 1)
        drawPlain()
        local call = __rec.last("image.blittint").args
        T.eq(call[4], lv1lua.current.color)
    end)

    T.it("quad draw stays on image.blit: no sub-rect tint on OneLua", function()
        fresh("OneLua")
        local img  = love.graphics.newImage("sheet.png")
        local quad = love.graphics.newQuad(0, 0, 16, 16, img)
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.draw(img, quad, 0, 0)
        T.eq(__rec.count("image.blit"), 1)
        T.eq(__rec.count("image.blittint"), 0)
    end)
end)

-- ── lpp-vita tint regression guard ───────────────────────────────
T.describe("lpp-vita image tint", function()
    T.it("plain draw passes the full color to drawScaleImage", function()
        fresh("lpp-vita")
        love.graphics.setColor(1, 0, 0, 1)
        local img = love.graphics.newImage("sheet.png")
        love.graphics.draw(img, 10, 20)
        local call = __rec.last("Graphics.drawScaleImage")
        T.ok(call, "drawScaleImage must be called")
        T.eq(call.args[6], lv1lua.current.color)
    end)

    T.it("quad draw passes the full color to drawImageExtended", function()
        fresh("lpp-vita")
        love.graphics.setColor(1, 0, 0, 1)
        local img  = love.graphics.newImage("sheet.png")
        local quad = love.graphics.newQuad(0, 0, 16, 16, img)
        love.graphics.draw(img, quad, 0, 0)
        local call = __rec.last("Graphics.drawImageExtended")
        T.ok(call, "drawImageExtended must be called")
        T.eq(call.args[11], lv1lua.current.color)
    end)
end)

io.write("\n=== image tint (T6.8) ===\n")
return T.summary()
