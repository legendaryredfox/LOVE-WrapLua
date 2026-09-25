-- Blend modes (FIX_PLAN T6.5).
--
-- setBlendMode used to store a string and nothing else. What each SDK really
-- exposes to Lua differs (see the T6.5 table in FIX_PLAN): PSP has additive and
-- subtractive image blits, the PS3 player binds tiny3d's full blend function,
-- and neither Vita backend exposes blend state at all. This suite checks the
-- shared validation, the honest capability set, and that the two backends with
-- something native to call actually call it.

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

local MODES = { "OneLua", "PSP", "lpp-vita", "PS3" }

-- ── shared validation ────────────────────────────────────────────
T.describe("love.graphics.setBlendMode validation", function()
    T.it("stores and returns the mode and the alpha mode", function()
        fresh("OneLua")
        love.graphics.setBlendMode("add")
        local mode, alphamode = love.graphics.getBlendMode()
        T.eq(mode, "add")
        T.eq(alphamode, "alphamultiply")
    end)

    T.it("keeps the alpha mode the caller asked for", function()
        fresh("OneLua")
        love.graphics.setBlendMode("add", "premultiplied")
        local mode, alphamode = love.graphics.getBlendMode()
        T.eq(mode, "add")
        T.eq(alphamode, "premultiplied")
    end)

    T.it("defaults to alpha / alphamultiply", function()
        fresh("OneLua")
        love.graphics.setBlendMode()
        local mode, alphamode = love.graphics.getBlendMode()
        T.eq(mode, "alpha")
        T.eq(alphamode, "alphamultiply")
    end)

    T.it("errors on an unknown mode, as LOVE does", function()
        fresh("OneLua")
        local ok = pcall(love.graphics.setBlendMode, "addd")
        T.nok(ok, "a typo in the mode name must not pass silently")
    end)

    T.it("errors on an unknown alpha mode", function()
        fresh("OneLua")
        local ok = pcall(love.graphics.setBlendMode, "add", "premultipled")
        T.nok(ok)
    end)

    T.it("rejects multiply with alphamultiply, as LOVE does", function()
        fresh("OneLua")
        local ok = pcall(love.graphics.setBlendMode, "multiply", "alphamultiply")
        T.nok(ok, "LOVE requires premultiplied alpha for multiply")
        T.ok(pcall(love.graphics.setBlendMode, "multiply", "premultiplied"))
    end)

    T.it("a rejected mode leaves the previous one in place", function()
        fresh("OneLua")
        love.graphics.setBlendMode("add")
        pcall(love.graphics.setBlendMode, "nonsense")
        T.eq(love.graphics.getBlendMode(), "add")
    end)
end)

-- ── honest capabilities ──────────────────────────────────────────
T.describe("blend capabilities", function()
    for _, mode in ipairs(MODES) do
        T.it("[" .. mode .. "] reports a mode list that matches the backend", function()
            fresh(mode)
            local blend = love._backend.blend
            T.istype(blend, "table")
            T.ok(blend.modes.alpha, "alpha is always available")
            if mode == "PS3" then
                T.ok(blend.native)
                T.ok(blend.modes.add and blend.modes.subtract)
                T.ok(blend.modes.multiply and blend.modes.lighten)
            elseif mode == "PSP" then
                T.ok(blend.native)
                T.ok(blend.modes.add and blend.modes.subtract)
                T.nok(blend.modes.multiply, "OSLib exposes no multiply through ONElua")
            else
                T.nok(blend.native, mode .. " exposes no blend state to Lua")
                T.nok(blend.modes.add)
            end
            T.eq(love._backend.features.blendmode, blend.native)
        end)
    end

    T.it("getSupported reports lighten only where the GPU blend is reachable", function()
        fresh("PS3")
        T.ok(love.graphics.getSupported().lighten)
        fresh("PSP")
        T.nok(love.graphics.getSupported().lighten)
        fresh("lpp-vita")
        T.nok(love.graphics.getSupported().lighten)
    end)

    T.it("isBlendModeSupported answers per backend", function()
        fresh("PSP")
        T.ok(love.graphics.isBlendModeSupported("add"))
        T.nok(love.graphics.isBlendModeSupported("multiply"))
        fresh("lpp-vita")
        T.nok(love.graphics.isBlendModeSupported("add"))
        T.ok(love.graphics.isBlendModeSupported("alpha"))
    end)
end)

-- ── PSP: native additive / subtractive blits ─────────────────────
T.describe("PSP blend", function()
    local function drawImage()
        local img = love.graphics.newImage("sheet.png")
        love.graphics.draw(img, 10, 20)
        return img
    end

    T.it("alpha draws through image.blit", function()
        fresh("PSP")
        love.graphics.setBlendMode("alpha")
        drawImage()
        T.eq(__rec.count("image.blit"), 1)
        T.eq(__rec.count("image.blitadd"), 0)
    end)

    T.it("add draws through image.blitadd", function()
        fresh("PSP")
        love.graphics.setBlendMode("add")
        drawImage()
        T.eq(__rec.count("image.blitadd"), 1)
        T.eq(__rec.count("image.blit"), 0)
    end)

    T.it("subtract draws through image.blitsub", function()
        fresh("PSP")
        love.graphics.setBlendMode("subtract")
        drawImage()
        T.eq(__rec.count("image.blitsub"), 1)
    end)

    T.it("passes the current alpha as the effect coefficient", function()
        fresh("PSP")
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.setBlendMode("add")
        drawImage()
        local call = __rec.last("image.blitadd").args
        T.near(call[4], 128, 1)
    end)

    T.it("going back to alpha stops using the additive blit", function()
        fresh("PSP")
        love.graphics.setBlendMode("add")
        drawImage()
        love.graphics.setBlendMode("alpha")
        drawImage()
        T.eq(__rec.count("image.blitadd"), 1)
        T.eq(__rec.count("image.blit"), 1)
    end)

    T.it("a quad draw stays on image.blit: the native add takes no source rect", function()
        fresh("PSP")
        local img  = love.graphics.newImage("sheet.png")
        local quad = love.graphics.newQuad(0, 0, 8, 8, 32, 32)
        love.graphics.setBlendMode("add")
        love.graphics.draw(img, quad, 1, 2)
        T.eq(__rec.count("image.blitadd"), 0)
        T.eq(__rec.count("image.blit"), 1)
    end)
end)

-- ── Vita (OneLua): no native blend, so nothing changes ───────────
T.describe("OneLua Vita blend", function()
    T.it("add still draws through image.blit (the Vita port has no blitadd)", function()
        fresh("OneLua")
        local img = love.graphics.newImage("sheet.png")
        love.graphics.setBlendMode("add")
        love.graphics.draw(img, 10, 20)
        T.eq(__rec.count("image.blit"), 1)
        T.eq(__rec.count("image.blitadd"), 0)
    end)

    T.it("the mock does not offer blitadd on Vita, matching the real SDK", function()
        fresh("OneLua")
        T.eq(image.blitadd, nil)
        fresh("PSP")
        T.istype(image.blitadd, "function")
    end)
end)

-- ── PS3: tiny3d blend function ───────────────────────────────────
T.describe("PS3 blend", function()
    T.it("alpha sets the source-alpha / one-minus-source-alpha pair", function()
        fresh("PS3")
        love.graphics.setBlendMode("alpha")
        local call = __rec.last("gfx.BlendFunction").args
        T.ok(call, "the backend must reach gfx.BlendFunction")
        T.eq(call[1], 1)
        T.eq(call[2], gfx.BLEND_FUNC_SRC_RGB_SRC_ALPHA + gfx.BLEND_FUNC_SRC_ALPHA_SRC_ALPHA)
        T.eq(call[3], gfx.BLEND_FUNC_DST_RGB_ONE_MINUS_SRC_ALPHA
                    + gfx.BLEND_FUNC_DST_ALPHA_ONE_MINUS_SRC_ALPHA)
        T.eq(call[4], gfx.BLEND_RGB_FUNC_ADD + gfx.BLEND_ALPHA_FUNC_ADD)
    end)

    T.it("add keeps the destination whole", function()
        fresh("PS3")
        love.graphics.setBlendMode("add")
        local call = __rec.last("gfx.BlendFunction").args
        T.eq(call[3], gfx.BLEND_FUNC_DST_RGB_ONE + gfx.BLEND_FUNC_DST_ALPHA_ONE)
        T.eq(call[4], gfx.BLEND_RGB_FUNC_ADD + gfx.BLEND_ALPHA_FUNC_ADD)
    end)

    T.it("subtract uses the reverse-subtract equation", function()
        fresh("PS3")
        love.graphics.setBlendMode("subtract")
        local call = __rec.last("gfx.BlendFunction").args
        T.eq(call[4], gfx.BLEND_RGB_FUNC_REVERSE_SUBTRACT
                    + gfx.BLEND_ALPHA_FUNC_REVERSE_SUBTRACT)
    end)

    T.it("multiply scales the source by the destination colour", function()
        fresh("PS3")
        love.graphics.setBlendMode("multiply", "premultiplied")
        local call = __rec.last("gfx.BlendFunction").args
        T.eq(call[2], gfx.BLEND_FUNC_SRC_RGB_DST_COLOR + gfx.BLEND_FUNC_SRC_ALPHA_DST_ALPHA)
        T.eq(call[3], gfx.BLEND_FUNC_DST_RGB_ZERO + gfx.BLEND_FUNC_DST_ALPHA_ZERO)
    end)

    T.it("replace writes the source untouched", function()
        fresh("PS3")
        love.graphics.setBlendMode("replace")
        local call = __rec.last("gfx.BlendFunction").args
        T.eq(call[2], gfx.BLEND_FUNC_SRC_RGB_ONE + gfx.BLEND_FUNC_SRC_ALPHA_ONE)
        T.eq(call[3], gfx.BLEND_FUNC_DST_RGB_ZERO + gfx.BLEND_FUNC_DST_ALPHA_ZERO)
    end)

    T.it("lighten and darken use the min/max equations", function()
        fresh("PS3")
        love.graphics.setBlendMode("lighten", "premultiplied")
        T.eq(__rec.last("gfx.BlendFunction").args[4], gfx.BLEND_RGB_MAX + gfx.BLEND_ALPHA_MAX)
        love.graphics.setBlendMode("darken", "premultiplied")
        T.eq(__rec.last("gfx.BlendFunction").args[4], gfx.BLEND_RGB_MIN + gfx.BLEND_ALPHA_MIN)
    end)

    T.it("add and alpha are not the same call", function()
        fresh("PS3")
        love.graphics.setBlendMode("alpha")
        local alpha = __rec.last("gfx.BlendFunction").args[3]
        love.graphics.setBlendMode("add")
        T.ok(__rec.last("gfx.BlendFunction").args[3] ~= alpha)
    end)

    T.it("survives a player build without the tiny3d gfx table", function()
        fresh("PS3")
        local saved = gfx
        gfx = nil
        local ok = pcall(love.graphics.setBlendMode, "add")
        gfx = saved
        T.ok(ok, "a missing native table must fall back, not raise")
    end)
end)

-- ── lpp-vita: tracked only ───────────────────────────────────────
T.describe("lpp-vita blend", function()
    T.it("installs no blend hook: the SDK has no blend entry point", function()
        fresh("lpp-vita")
        T.eq(lv1lua.gfx.blendHooks, nil)
        love.graphics.setBlendMode("add")
        T.eq(love.graphics.getBlendMode(), "add")
    end)
end)

io.write("\n=== blend modes (T6.5) ===\n")
return T.summary()
