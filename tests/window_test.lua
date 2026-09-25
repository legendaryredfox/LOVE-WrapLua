local T = dofile("tests/runner.lua")
dofile("tests/mock_platform.lua")
dofile("LOVE-WrapLua/window.lua")

T.describe("love.window.getDimensions", function()
    T.it("returns screenWidth and screenHeight", function()
        lv1lua.screenWidth  = 960
        lv1lua.screenHeight = 544
        local w, h = love.window.getDimensions()
        T.eq(w, 960)
        T.eq(h, 544)
    end)

    T.it("reflects PSP dimensions (480×272)", function()
        lv1lua.screenWidth  = 480
        lv1lua.screenHeight = 272
        T.eq(love.window.getWidth(),  480)
        T.eq(love.window.getHeight(), 272)
    end)
end)

T.describe("love.window.getTitle / setTitle", function()
    T.it("getTitle returns the configured title", function()
        lv1lua.loveconf = { window = { title = "My Game" } }
        T.eq(love.window.getTitle(), "My Game")
    end)

    T.it("setTitle updates the title", function()
        lv1lua.loveconf = { window = { title = "Old" } }
        love.window.setTitle("New Title")
        T.eq(love.window.getTitle(), "New Title")
    end)

    T.it("getTitle falls back to 'LOVE-WrapLua' when window is absent", function()
        lv1lua.loveconf = {}
        T.eq(love.window.getTitle(), "LOVE-WrapLua")
    end)
end)

T.describe("love.window.getMode", function()
    T.it("returns width, height, and flags table", function()
        lv1lua.screenWidth = 960; lv1lua.screenHeight = 544
        local w, h, flags = love.window.getMode()
        T.eq(w, 960)
        T.eq(h, 544)
        T.istype(flags, "table")
    end)

    T.it("fullscreen flag is always true", function()
        local _, _, flags = love.window.getMode()
        T.ok(flags.fullscreen)
    end)

    T.it("setMode is a no-op (consoles are always fullscreen)", function()
        love.window.setMode(1920, 1080)  -- should not crash
        T.eq(love.window.getWidth(), lv1lua.screenWidth)  -- unchanged
    end)
end)

T.describe("love.window.getFullscreen", function()
    T.it("always returns true", function()
        local full, ftype = love.window.getFullscreen()
        T.ok(full)
        T.istype(ftype, "string")
    end)
end)

T.describe("love.window.hasFocus / isVisible / isOpen", function()
    T.it("hasFocus returns true", function()   T.ok(love.window.hasFocus())   end)
    T.it("isVisible returns true", function()  T.ok(love.window.isVisible())  end)
    T.it("isOpen returns true", function()     T.ok(love.window.isOpen())     end)
end)

T.describe("love.window.getDPIScale", function()
    T.it("returns 1", function()
        T.eq(love.window.getDPIScale(), 1)
    end)
end)

T.describe("love.window.fromPixels / toPixels", function()
    T.it("fromPixels is identity (DPI scale = 1)", function()
        T.eq(love.window.fromPixels(200), 200)
    end)

    T.it("toPixels is identity (DPI scale = 1)", function()
        T.eq(love.window.toPixels(200), 200)
    end)
end)

T.describe("love.window.getSafeArea", function()
    T.it("returns four numbers", function()
        local a, b, c, d = love.window.getSafeArea()
        T.istype(a, "number"); T.istype(b, "number")
        T.istype(c, "number"); T.istype(d, "number")
    end)
end)

io.write("\n=== love.window ===\n")
return T.summary()
