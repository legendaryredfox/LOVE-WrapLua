-- Fixes from the whole-repository review that have no other home
-- (CODE_REVIEW R11, R12, R13, R17, R19).

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
}

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
end

-- ── The transform API exists on every backend (R13) ──────────────
for _, mode in ipairs({"OneLua", "PSP", "lpp-vita", "PS3"}) do
    load_backend(mode)
    T.describe("transform API surface [" .. mode .. "]", function()
        T.it("every transform entry point is callable", function()
            for _, name in ipairs({"push","pop","translate","scale","rotate","shear",
                                   "origin","reset","applyTransform","replaceTransform",
                                   "transformPoint","inverseTransformPoint",
                                   "setScissor","getScissor","intersectScissor"}) do
                T.istype(love.graphics[name], "function")
            end
        end)

        T.it("transformPoint round-trips through its inverse", function()
            love.graphics.origin()
            local x, y = love.graphics.transformPoint(10, 20)
            local bx, by = love.graphics.inverseTransformPoint(x, y)
            T.near(bx, 10)
            T.near(by, 20)
        end)

        T.it("getStats has the LOVE shape", function()
            local s = love.graphics.getStats()
            T.istype(s, "table")
            T.istype(s.drawcalls, "number")
            T.istype(s.texturememory, "number")
            T.istype(s.fonts, "number")
        end)

        T.it("isGammaCorrect answers", function()
            T.istype(love.graphics.isGammaCorrect(), "boolean")
        end)
    end)
end

-- ── OneLua clears before drawing (R17) ───────────────────────────
load_backend("OneLua")
T.describe("OneLua frame", function()
    T.it("the frame is cleared before love.draw runs", function()
        dofile("LOVE-WrapLua/core/input.lua")
        dofile("LOVE-WrapLua/OneLua/timer.lua")
        dofile("LOVE-WrapLua/OneLua/whileloop.lua")
        local order = {}
        love.draw = function() order[#order + 1] = "draw" end
        __rec.reset()
        lv1lua.draw()
        local cleared = __rec.all("screen.clear")
        T.ok(#cleared >= 1, "a frame must start from a cleared screen")
        T.eq(order[1], "draw")
    end)
end)

-- ── lpp-vita IME is collected on a later frame (R12) ─────────────
load_backend("lpp-vita")
T.describe("lpp-vita text input", function()
    local function loadKeyboard()
        load_backend("lpp-vita")
        dofile("LOVE-WrapLua/lpp-vita/keyboard.lua")
    end

    T.it("no text is delivered while the keyboard is still open", function()
        loadKeyboard()
        local got
        love.textinput = function(t) got = t end
        love.keyboard.showTextInput({ header = "Name" })
        love.keyboard.pollTextInput()
        T.eq(got, nil)
        T.ok(love.keyboard.isTextInputActive())
    end)

    T.it("text arrives on the frame the keyboard closes", function()
        loadKeyboard()
        local got
        love.textinput = function(t) got = t end
        love.keyboard.showTextInput({ header = "Name" })
        love.keyboard.pollTextInput()

        Keyboard._text  = "player one"
        Keyboard._state = FINISHED
        love.keyboard.pollTextInput()

        T.eq(got, "player one")
        T.nok(love.keyboard.isTextInputActive())
    end)

    T.it("polling with no keyboard open does nothing", function()
        loadKeyboard()
        local calls = 0
        love.textinput = function() calls = calls + 1 end
        love.keyboard.pollTextInput()
        T.eq(calls, 0)
    end)
end)

-- ── PS3 quit survives a missing shutdown entry point (R11) ───────
T.describe("PS3 quit", function()
    T.it("quitting works when the player exports no EndGFX", function()
        __MODE = "PS3"
        dofile("tests/setup.lua")
        EndGFX = nil
        dofile("LOVE-WrapLua/PS3/event.lua")
        love.event.quit()
        T.nok(lv1lua.running, "quit must still stop the loop")
    end)

    T.it("the native shutdown calls are used when they exist", function()
        __MODE = "PS3"
        dofile("tests/setup.lua")
        local ended = false
        EndGFX = function() ended = true end
        snd.Finalize = function() end
        dofile("LOVE-WrapLua/PS3/event.lua")
        love.event.quit()
        T.ok(ended, "EndGFX should be called when the build has it")
        EndGFX = nil
    end)
end)

-- ── love.data rejects a format it cannot do (R19) ────────────────
T.describe("love.data", function()
    T.it("an unknown encode format errors instead of passing data through", function()
        __MODE = "OneLua"
        dofile("tests/setup.lua")
        dofile("LOVE-WrapLua/data.lua")
        T.nok(pcall(love.data.encode, "string", "base65", "hello"))
        T.nok(pcall(love.data.decode, "string", "base65", "hello"))
        T.eq(love.data.encode("string", "hex", "A"), "41")
    end)
end)

io.write("\n=== review fixes (transform surface, frame clear, IME, quit, data) ===\n")
return T.summary()
