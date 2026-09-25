-- PSP texture-constraint validation (FIX_PLAN T8.1).
--
-- The PSP GPU needs power-of-two, <=512x512 textures. newImage / newQuad must
-- warn (never silently corrupt) when a sheet violates that, and stay quiet for a
-- valid one. lpp-vita (1024 limit, NPOT allowed) is checked as the contrast.

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
}

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
end

-- Forces the next image.load to report the given dimensions.
local function fakeSheet(w, h)
    image.load = function(f) return { _w = w, _h = h, _path = f } end
end

local function warned()
    return #lv1lua.util.warnings > 0
end

-- ── PSP: power-of-two, <=512 ──────────────────────────────────────
load_backend("PSP")

T.describe("PSP texture limits [newImage]", function()
    T.it("a 1024-wide sheet warns (over the 512 limit)", function()
        lv1lua.util.resetWarnings()
        fakeSheet(1024, 64)
        love.graphics.newImage("big.png")
        T.ok(warned(), "oversize sheet should warn")
    end)

    T.it("a 300x300 sheet warns (not power-of-two)", function()
        lv1lua.util.resetWarnings()
        fakeSheet(300, 300)
        love.graphics.newImage("npot.png")
        T.ok(warned(), "non-power-of-two sheet should warn")
    end)

    T.it("a 512x512 power-of-two sheet is silent", function()
        lv1lua.util.resetWarnings()
        fakeSheet(512, 512)
        love.graphics.newImage("ok.png")
        T.nok(warned(), "valid POT <=512 sheet should not warn")
    end)

    T.it("a 256x128 power-of-two sheet is silent", function()
        lv1lua.util.resetWarnings()
        fakeSheet(256, 128)
        love.graphics.newImage("ok2.png")
        T.nok(warned())
    end)
end)

T.describe("PSP texture limits [newQuad]", function()
    T.it("a quad over a 1024 sheet warns", function()
        lv1lua.util.resetWarnings()
        love.graphics.newQuad(0, 0, 16, 16, 1024, 64)
        T.ok(warned(), "oversize sheet dims should warn via newQuad")
    end)

    T.it("a quad over a 256x256 POT sheet is silent", function()
        lv1lua.util.resetWarnings()
        love.graphics.newQuad(0, 0, 16, 16, 256, 256)
        T.nok(warned())
    end)
end)

-- ── OneLua/Vita: 512 limit, NPOT allowed ──────────────────────────
load_backend("OneLua")

T.describe("OneLua texture limits", function()
    T.it("a 1024 sheet warns (over the 512 limit)", function()
        lv1lua.util.resetWarnings()
        fakeSheet(1024, 64)
        love.graphics.newImage("big.png")
        T.ok(warned())
    end)

    T.it("a 300x300 NPOT sheet is silent (only PSP requires POT)", function()
        lv1lua.util.resetWarnings()
        fakeSheet(300, 300)
        love.graphics.newImage("npot.png")
        T.nok(warned())
    end)
end)

-- ── lpp-vita: 1024 limit, NPOT allowed ────────────────────────────
load_backend("lpp-vita")

T.describe("lpp-vita texture limits", function()
    T.it("a 1024x1024 sheet is silent (within the 1024 limit)", function()
        lv1lua.util.resetWarnings()
        love.graphics.newQuad(0, 0, 16, 16, 1024, 1024)
        T.nok(warned())
    end)

    T.it("a 2048 sheet warns (over the 1024 limit)", function()
        lv1lua.util.resetWarnings()
        love.graphics.newQuad(0, 0, 16, 16, 2048, 64)
        T.ok(warned())
    end)
end)

io.write("\n=== texture limits (T8.1) ===\n")
return T.summary()
