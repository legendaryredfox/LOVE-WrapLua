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

    T.it("does not leak the conf table as a global", function()
        fresh("OneLua")
        lv1luaconf = nil
        t = nil
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        T.ok(t == nil, "conf table should stay local")
    end)
end)

io.write("\n=== bootstrap (core) ===\n")
return T.summary()
