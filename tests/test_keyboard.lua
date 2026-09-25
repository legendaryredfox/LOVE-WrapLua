local T = dofile("tests/runner.lua")
dofile("tests/mock_platform.lua")
-- keyboard.lua depends on lv1lua.keyset (set in mock_platform); key repeat
-- lives in core/input.lua, which every backend shares.
dofile("LOVE-WrapLua/core/loader.lua")
lv1lua.load("LOVE-WrapLua/core/input.lua")
dofile("LOVE-WrapLua/OneLua/keyboard.lua")

-- ── isDown ───────────────────────────────────────────────────────
T.describe("love.keyboard.isDown", function()
    T.it("returns false when no button is held", function()
        buttons.held = {}
        T.nok(love.keyboard.isDown("up"))
    end)

    T.it("returns true when a raw button is in held", function()
        buttons.held = { up = true }
        T.ok(love.keyboard.isDown("up"))
        buttons.held = {}
    end)

    T.it("maps keyset alias: lv1lua.keyset[1] ('b') → 'circle'", function()
        -- keyset[1] = "b"; keyboard maps "b" → "circle" in buttons.held
        buttons.held = { circle = true }
        T.ok(love.keyboard.isDown(lv1lua.keyset[1]))
        buttons.held = {}
    end)

    T.it("maps 'back' → 'select'", function()
        buttons.held = { select = true }
        T.ok(love.keyboard.isDown("back"))
        buttons.held = {}
    end)

    T.it("returns false for unmapped key not in held", function()
        buttons.held = {}
        T.nok(love.keyboard.isDown("z"))
    end)
end)

-- ── isScancodeDown ───────────────────────────────────────────────
T.describe("love.keyboard.isScancodeDown", function()
    T.it("delegates to isDown", function()
        buttons.held = { down = true }
        T.ok(love.keyboard.isScancodeDown("down"))
        buttons.held = {}
    end)
end)

-- ── hasKeyRepeat / setKeyRepeat ──────────────────────────────────
T.describe("love.keyboard hasKeyRepeat / setKeyRepeat", function()
    T.it("hasKeyRepeat is false by default, as in LOVE", function()
        T.nok(love.keyboard.hasKeyRepeat())
    end)

    T.it("setKeyRepeat toggles the reported state", function()
        love.keyboard.setKeyRepeat(true)
        T.ok(love.keyboard.hasKeyRepeat())
        love.keyboard.setKeyRepeat(false)
        T.nok(love.keyboard.hasKeyRepeat())
    end)

    T.it("treats a nil argument as off", function()
        love.keyboard.setKeyRepeat(true)
        love.keyboard.setKeyRepeat(nil)
        T.eq(love.keyboard.hasKeyRepeat(), false)
    end)
end)

-- ── hasTextInput ─────────────────────────────────────────────────
T.describe("love.keyboard.hasTextInput", function()
    T.it("returns false", function()
        T.nok(love.keyboard.hasTextInput())
    end)
end)

-- ── getKeyFromScancode / getScancodeFromKey ───────────────────────
T.describe("love.keyboard.getKeyFromScancode / getScancodeFromKey", function()
    T.it("getKeyFromScancode is identity", function()
        T.eq(love.keyboard.getKeyFromScancode("up"), "up")
        T.eq(love.keyboard.getKeyFromScancode("a"),  "a")
    end)

    T.it("getScancodeFromKey is identity", function()
        T.eq(love.keyboard.getScancodeFromKey("cross"), "cross")
    end)
end)

-- ── showTextInput / setTextInput ──────────────────────────────────
T.describe("love.keyboard.showTextInput / setTextInput", function()
    T.it("showTextInput does not crash with empty osk result", function()
        osk.init = function() return "" end
        love.keyboard.showTextInput({ header="Test", subheader="sub" })
    end)

    T.it("showTextInput fires love.textinput callback when text returned", function()
        local received = nil
        love.textinput = function(t) received = t end
        osk.init = function() return "typed" end
        love.keyboard.showTextInput({})
        T.eq(received, "typed")
        love.textinput = nil
        osk.init = function() return "" end
    end)

    T.it("setTextInput delegates to showTextInput", function()
        local called = false
        local orig = love.keyboard.showTextInput
        love.keyboard.showTextInput = function(t) called = true end
        love.keyboard.setTextInput({})
        T.ok(called)
        love.keyboard.showTextInput = orig
    end)
end)

io.write("\n=== love.keyboard (OneLua) ===\n")
return T.summary()
