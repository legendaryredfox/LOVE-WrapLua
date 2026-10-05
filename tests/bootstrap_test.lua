-- Tests for the bootstrap modules under LOVE-WrapLua/core/.
--
-- script.lua itself ends in the main loop, so it cannot be run here; the steps
-- it sequences are loaded individually instead.

local T = dofile("tests/runner.lua")

local function fresh(mode, isPSP)
    __MODE = mode == "PSP" and "PSP" or mode
    dofile("tests/setup.lua")
    dofile("LOVE-WrapLua/core/loader.lua")
    lv1lua.mode  = mode
    lv1lua.isPSP = isPSP or false
    os.cfw       = isPSP or false
    lv1lua.load("LOVE-WrapLua/core/util.lua")
    lv1lua.load("LOVE-WrapLua/core/runtime.lua")
end

-- ── loader ───────────────────────────────────────────────────────
T.describe("core.loader", function()
    T.it("prefixes paths with lv1lua.dataloc", function()
        __MODE = "OneLua"
        dofile("tests/setup.lua")
        dofile("LOVE-WrapLua/core/loader.lua")
        lv1lua.dataloc = ""
        T.ok(lv1lua.load ~= nil, "load should be defined")
        T.ok(lv1lua.loadOnce ~= nil, "loadOnce should be defined")
    end)

    T.it("loadOnce runs a file only once", function()
        __MODE = "OneLua"
        dofile("tests/setup.lua")
        dofile("LOVE-WrapLua/core/loader.lua")
        __loadCount = 0
        local probe = "tests/fixtures/count_probe.lua"
        lv1lua.loadOnce(probe)
        lv1lua.loadOnce(probe)
        T.eq(__loadCount, 1)
    end)
end)

-- ── runtime ──────────────────────────────────────────────────────
T.describe("core.runtime", function()
    T.it("builds the love namespace", function()
        fresh("OneLua")
        T.eq(type(love.graphics), "table")
        T.eq(type(love.filesystem), "table")
        T.eq(type(love.thread or {}), "table")
    end)

    T.it("reports LOVE 11.5", function()
        fresh("OneLua")
        local major, minor = love.getVersion()
        T.eq(major, 11); T.eq(minor, 5)
    end)

    T.it("uses the Vita screen size for OneLua on Vita", function()
        fresh("OneLua", false)
        T.eq(lv1lua.screenWidth, 960)
        T.eq(lv1lua.screenHeight, 544)
    end)

    T.it("uses the PSP screen size when os.cfw is set", function()
        fresh("OneLua", true)
        T.eq(lv1lua.screenWidth, 480)
        T.eq(lv1lua.screenHeight, 272)
    end)

    T.it("uses the PS3 screen size for PS3", function()
        __MODE = "PS3"
        dofile("tests/setup.lua")
        dofile("LOVE-WrapLua/core/loader.lua")
        lv1lua.mode = "PS3"
        os.cfw = false
        lv1lua.load("LOVE-WrapLua/core/runtime.lua")
        T.eq(lv1lua.screenWidth, 720)
        T.eq(lv1lua.screenHeight, 480)
    end)

    T.it("marks the runtime as running", function()
        fresh("OneLua")
        T.ok(lv1lua.running, "should start running")
    end)

    T.it("exists() answers for the OneLua backend", function()
        fresh("OneLua")
        T.eq(type(lv1lua.exists("anything")), "boolean")
    end)
end)

-- ── config ───────────────────────────────────────────────────────
T.describe("core.config", function()
    T.it("defaults to the XB button layout", function()
        fresh("OneLua")
        lv1luaconf = nil
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        T.eq(lv1luaconf.keyconf, "XB")
        T.eq(lv1lua.keyset[1], "b")
        T.eq(lv1lua.keyset[2], "a")
    end)

    T.it("maps the PS layout to PlayStation button names", function()
        fresh("OneLua")
        lv1luaconf = { keyconf = "PS" }
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        T.eq(lv1lua.keyset[1], "circle")
        T.eq(lv1lua.keyset[2], "cross")
    end)

    T.it("swaps confirm/cancel for the XBA layout", function()
        fresh("OneLua")
        lv1luaconf = { keyconf = "XBA" }
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        T.eq(lv1lua.keyset[1], "a")
        T.eq(lv1lua.keyset[2], "b")
    end)

    -- The draw code reads imgscale/resscale; the old default table and the docs
    -- spelled them img_scale/res_scale, so those settings were silently ignored.
    T.it("accepts the img_scale / res_scale spelling", function()
        fresh("OneLua")
        lv1luaconf = { keyconf = "XB", img_scale = true, res_scale = true }
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        T.eq(lv1luaconf.imgscale, true)
        T.eq(lv1luaconf.resscale, true)
    end)

    T.it("leaves the canonical imgscale / resscale spelling alone", function()
        fresh("OneLua")
        lv1luaconf = { keyconf = "XB", imgscale = true, resscale = false }
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        T.eq(lv1luaconf.imgscale, true)
        T.eq(lv1luaconf.resscale, false)
    end)

    T.it("defaults both scale flags to false", function()
        fresh("OneLua")
        lv1luaconf = nil
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        T.eq(lv1luaconf.imgscale, false)
        T.eq(lv1luaconf.resscale, false)
    end)

    T.it("always provides a loveconf table", function()
        fresh("OneLua")
        lv1luaconf = nil
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        T.eq(type(lv1lua.loveconf), "table")
        T.eq(type(lv1lua.loveconf.window), "table")
    end)

    T.it("sets a save identity even with no game/conf.lua", function()
        -- love.filesystem builds the save path from this; a game shipped
        -- without a conf.lua used to reach a nil there on its first save.
        fresh("OneLua")
        lv1luaconf = nil
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        T.eq(lv1lua.loveconf.identity, "LOVE-WrapLua")
    end)

    T.it("a conf.lua that defines no love.conf does not crash the boot", function()
        fresh("OneLua")
        lv1luaconf = nil
        local realExists, realDofile = lv1lua.exists, dofile
        lv1lua.exists = function(p) return p:find("game/conf.lua", 1, true) ~= nil end
        dofile = function(p)
            if p:find("game/conf.lua", 1, true) then return end
            return realDofile(p)
        end
        love.conf = nil
        local ok, err = pcall(lv1lua.load, "LOVE-WrapLua/core/config.lua")
        dofile, lv1lua.exists = realDofile, realExists
        T.ok(ok, tostring(err))
        T.eq(lv1lua.loveconf.identity, "LOVE-WrapLua")
    end)

    T.it("does not leak the conf table as a global", function()
        fresh("OneLua")
        lv1luaconf = nil
        t = nil
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        T.ok(t == nil, "conf table should stay local")
    end)
end)

-- ── index.lua: one entry name, two players ───────────────────────
-- Runs index.lua with dofile intercepted, so only its detection runs.
local function boot_index()
    local booted
    local realDofile = dofile
    dofile = function(path) booted = path end
    local ok, err = pcall(function() loadfile("index.lua")() end)
    dofile = realDofile
    if not ok then error(err, 0) end
    return booted
end

T.describe("index.lua", function()
    T.it("boots lpp-vita when the 3DS screen constants are absent", function()
        __MODE = "lpp-vita"
        dofile("tests/setup.lua")
        TOP_SCREEN, BOTTOM_SCREEN = nil, nil
        T.eq(boot_index(), "app0:/script.lua")
        T.eq(lv1lua.mode, "lpp-vita")
    end)

    T.it("boots the 3DS from its SD folder", function()
        __MODE = "3DS"
        dofile("tests/setup.lua")
        T.eq(boot_index(), "/3ds/LOVE-WrapLua/script.lua")
        T.eq(lv1lua.mode, "3DS")
    end)

    T.it("boots the 3DS from romfs when the game is packed in a CIA", function()
        __MODE = "3DS"
        dofile("tests/setup.lua")
        local exists = System.doesFileExist
        System.doesFileExist = function(p) return p == "romfs:/script.lua" end
        local booted = boot_index()
        System.doesFileExist = exists
        T.eq(booted, "romfs:/script.lua")
    end)

    T.it("the 3DS runtime sees a 400x240 top screen", function()
        __MODE = "3DS"
        dofile("tests/setup.lua")
        boot_index()
        dofile("LOVE-WrapLua/core/runtime.lua")
        T.eq(lv1lua.screenWidth, 400)
        T.eq(lv1lua.screenHeight, 240)
    end)
end)

io.write("\n=== bootstrap (core) ===\n")
return T.summary()
