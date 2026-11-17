-- love.graphics.captureScreenshot on lpp-vita: System.takeScreenshot writes the frame buffer, so the capture is
-- queued and made right after the frame that was asked for is presented.

local T = dofile("tests/runner.lua")
__MODE = "lpp-vita"
dofile("tests/setup.lua")
dofile("LOVE-WrapLua/lpp-vita/graphics.lua")
dofile("LOVE-WrapLua/core/loader.lua")
lv1lua.load("LOVE-WrapLua/core/input.lua")
lv1lua.load("LOVE-WrapLua/core/config.lua")
lv1lua.load("LOVE-WrapLua/core/timestep.lua")
dofile("LOVE-WrapLua/lpp-vita/whileloop.lua")
lv1lua.saveloc = "ux0:/data/game/"

local function frame() lv1lua.draw() end

T.describe("captureScreenshot [lpp-vita]", function()
    T.it("nothing is captured until a game asks", function()
        __rec.reset()
        frame()
        T.eq(__rec.count("System.takeScreenshot"), 0)
    end)

    T.it("a file name is captured after the next frame is presented, into the save directory", function()
        __rec.reset()
        love.graphics.captureScreenshot("shot.png")
        T.eq(__rec.count("System.takeScreenshot"), 0)
        frame()
        local c = __rec.last("System.takeScreenshot")
        T.eq(c.args[1], "ux0:/data/game/shot.png")
        T.eq(c.args[2], 1)
        frame()
        T.eq(__rec.count("System.takeScreenshot"), 1)
    end)

    T.it("the extension picks the format", function()
        local want = { ["a.png"] = 1, ["a.jpg"] = 2, ["a.JPEG"] = 2, ["a.bmp"] = 0, ["a"] = 1 }
        for name, fmt in pairs(want) do
            __rec.reset()
            love.graphics.captureScreenshot(name)
            frame()
            T.eq(__rec.last("System.takeScreenshot").args[2], fmt, name)
        end
    end)

    T.it("a callback cannot be served: no ImageData, so nothing is captured and the game is told once", function()
        __rec.reset()
        lv1lua.util.resetWarnings()
        love.graphics.captureScreenshot(function() end)
        frame()
        T.eq(__rec.count("System.takeScreenshot"), 0)
        T.eq(#lv1lua.util.warnings, 1)
    end)

    T.it("the latest request wins when two are made in one frame", function()
        __rec.reset()
        love.graphics.captureScreenshot("one.png")
        love.graphics.captureScreenshot("two.png")
        frame()
        T.eq(__rec.count("System.takeScreenshot"), 1)
        T.eq(__rec.last("System.takeScreenshot").args[1], "ux0:/data/game/two.png")
    end)
end)

io.write("\n=== screenshot ===\n")
return T.summary()
