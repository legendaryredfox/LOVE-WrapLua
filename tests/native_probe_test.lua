-- OneLua native capability probe: which image.* / screen.* calls the running EBOOT has, probed once
-- and exposed in love._backend.native. A scaled draw on a build that can neither copyscale nor
-- resize and clip must not raise.

local T = dofile("tests/runner.lua")

local GFX = {
    PSP    = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    OneLua = "LOVE-WrapLua/OneLua/graphics.lua",
}

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
    love.graphics.origin()
end

for _, mode in ipairs({ "PSP", "OneLua" }) do
    load_backend(mode)
    T.describe("native probe [" .. mode .. "]", function()
        T.it("love._backend.native lists the calls as booleans", function()
            local n = love._backend.native
            T.istype(n, "table")
            for _, k in ipairs({ "copyscale", "resize", "center", "clip", "blittint", "blitadd", "blitsub" }) do
                T.istype(n[k], "boolean")
            end
        end)

        T.it("reports what the mock SDK has", function()
            local n = love._backend.native
            T.eq(n.copyscale, image.copyscale ~= nil)
            T.eq(n.blitadd, image.blitadd ~= nil)
            T.eq(n.resize, true)
            T.eq(n.clip, true)
        end)

        T.it("probeNative follows a call that appears or disappears", function()
            local saved = image.copyscale
            image.copyscale = nil
            lv1lua.core.probeNative()
            T.eq(love._backend.native.copyscale, false)
            image.copyscale = saved
            lv1lua.core.probeNative()
            T.eq(love._backend.native.copyscale, saved ~= nil)
        end)

        T.it("a scaled draw without copyscale, resize or clip draws at natural size and warns once", function()
            local saved = { image.copyscale, image.resize, screen.clip }
            image.copyscale, image.resize, screen.clip = nil, nil, nil
            lv1lua.core.probeNative()
            lv1lua.util.resetWarnings()
            local img = love.graphics.newImage("sheet.png")
            local q = love.graphics.newQuad(0, 0, 8, 8, img)
            __rec.reset()
            local ok = pcall(function()
                love.graphics.draw(img, q, 10, 10, 0, 2, 2)
                love.graphics.draw(img, 20, 20, 0, 2, 2)
            end)
            T.ok(ok, "no error")
            T.eq(__rec.count("image.blit"), 2)
            T.eq(__rec.all("image.blit")[1].args[2], 10)
            T.eq(#lv1lua.util.warnings, 1)
            image.copyscale, image.resize, screen.clip = saved[1], saved[2], saved[3]
            lv1lua.core.probeNative()
        end)

        T.it("a tinted draw without blittint falls back to the plain blit", function()
            local saved = image.blittint
            image.blittint = nil
            lv1lua.core.probeNative()
            love.graphics.setColor(1, 0.5, 0.5, 1)
            local img = love.graphics.newImage("sheet.png")
            __rec.reset()
            local ok = pcall(love.graphics.draw, img, 0, 0)
            T.ok(ok)
            T.eq(__rec.count("image.blit"), 1)
            love.graphics.setColor(1, 1, 1, 1)
            image.blittint = saved
            lv1lua.core.probeNative()
        end)
    end)
end

for _, mode in ipairs({ "lpp-vita", "PS3", "3DS" }) do
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(({ ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua", PS3 = "LOVE-WrapLua/PS3/graphics.lua",
              ["3DS"] = "LOVE-WrapLua/3DS/graphics.lua" })[mode])
    T.describe("native probe [" .. mode .. "]", function()
        T.it("has nothing to probe", function()
            T.eq(love._backend.native, nil)
        end)
    end)
end

io.write("\n=== native probe ===\n")
return T.summary()
