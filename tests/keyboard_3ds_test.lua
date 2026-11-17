-- lpp-3ds text input: Keyboard.show draws the bottom-screen keyboard and has to be called every frame
-- while it is up, so love.keyboard.showTextInput opens it and updatecontrols pumps it.

local T = dofile("tests/runner.lua")
__MODE = "3DS"
dofile("tests/setup.lua")
dofile("LOVE-WrapLua/core/loader.lua")
lv1lua.load("LOVE-WrapLua/core/util.lua")
lv1lua.load("LOVE-WrapLua/core/input.lua")
lv1lua.load("LOVE-WrapLua/core/config.lua")
lv1lua.load("LOVE-WrapLua/core/timestep.lua")
lv1lua.load("LOVE-WrapLua/3DS/graphics.lua")
lv1lua.load("LOVE-WrapLua/3DS/keyboard.lua")
lv1lua.load("LOVE-WrapLua/3DS/whileloop.lua")

local function reset()
    __3ds.down, __3ds.circle = {}, { 0, 0 }
    __3ds.keyboard.script, __3ds.keyboard.shows = {}, 0
    Keyboard.clear()
    love.textinput = nil
end

local function frames(n) for _ = 1, n do lv1lua.updatecontrols() end end

T.describe("3DS text input", function()
    T.it("the keyboard is not shown until a game asks for it", function()
        reset()
        frames(3)
        T.eq(__3ds.keyboard.shows, 0)
        T.nok(love.keyboard.hasTextInput())
    end)

    T.it("showTextInput opens it and show is called on every frame", function()
        reset()
        love.keyboard.showTextInput({})
        T.ok(love.keyboard.hasTextInput())
        frames(3)
        T.eq(__3ds.keyboard.shows, 3)
    end)

    T.it("Enter closes it and delivers the whole text to love.textinput", function()
        reset()
        local got = {}
        love.textinput = function(t) got[#got + 1] = t end
        love.keyboard.showTextInput({})
        __3ds.keyboard.script = { { PRESSED, "he" }, { PRESSED, "hello" }, { FINISHED, "hello" } }
        frames(5)
        T.eq(#got, 1)
        T.eq(got[1], "hello")
        T.nok(love.keyboard.hasTextInput())
        T.eq(__3ds.keyboard.shows, 3)
        T.eq(__3ds.keyboard.input, "")
    end)

    T.it("cancel closes it and sends no text", function()
        reset()
        local n = 0
        love.textinput = function() n = n + 1 end
        love.keyboard.showTextInput({})
        __3ds.keyboard.script = { { PRESSED, "abc" }, { CLEANED } }
        frames(4)
        T.eq(n, 0)
        T.nok(love.keyboard.hasTextInput())
        T.eq(__3ds.keyboard.input, "")
    end)

    T.it("Enter on an empty string sends nothing", function()
        reset()
        local n = 0
        love.textinput = function() n = n + 1 end
        love.keyboard.showTextInput({})
        __3ds.keyboard.script = { { FINISHED, "" } }
        frames(2)
        T.eq(n, 0)
        T.nok(love.keyboard.hasTextInput())
    end)

    T.it("a text given to showTextInput preloads the keyboard", function()
        reset()
        love.keyboard.showTextInput({ text = "name" })
        T.eq(__3ds.keyboard.input, "name")
    end)

    T.it("setTextInput(false) closes an open keyboard", function()
        reset()
        love.keyboard.showTextInput({})
        love.keyboard.setTextInput(false)
        T.nok(love.keyboard.hasTextInput())
        frames(2)
        T.eq(__3ds.keyboard.shows, 0)
    end)

    T.it("showTextInput(false) and showTextInput() leave it closed", function()
        reset()
        love.keyboard.showTextInput(false)
        love.keyboard.showTextInput()
        T.nok(love.keyboard.hasTextInput())
    end)

    T.it("the frame keeps working when the game defines no love.textinput", function()
        reset()
        love.keyboard.showTextInput({})
        __3ds.keyboard.script = { { FINISHED, "x" } }
        frames(2)
        T.nok(love.keyboard.hasTextInput())
    end)
end)

io.write("\n=== 3DS text input ===\n")
return T.summary()
