-- love.event.quit on every backend.
--
-- In LOVE, love.quit returning true cancels the quit (the usual "are you
-- sure?" prompt). Every backend called love.quit and then exited anyway.

local T = dofile("tests/runner.lua")

local EVENT = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/event.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/event.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/event.lua",
    ["3DS"]      = "LOVE-WrapLua/3DS/event.lua",
}

-- Records every way a backend can leave instead of really leaving.
local function stubExits()
    local exited = {}
    os.exit = function() exited[#exited + 1] = "os.exit" end
    if type(System) == "table" then
        System.exit = function() exited[#exited + 1] = "System.exit" end
        System.launchEboot = function() exited[#exited + 1] = "launchEboot" end
    end
    return exited
end

local realExit = os.exit

for _, mode in ipairs({ "OneLua", "lpp-vita", "PS3", "3DS" }) do
    T.describe("love.event.quit [" .. mode .. "]", function()
        T.it("love.quit returning true cancels the quit", function()
            __MODE = mode
            dofile("tests/setup.lua")
            local exited = stubExits()
            dofile(EVENT[mode])
            lv1lua.running = true
            local asked = false
            love.quit = function() asked = true; return true end
            love.event.quit()
            os.exit = realExit
            T.ok(asked, "love.quit should be asked")
            T.ok(lv1lua.running, "the loop must keep running")
            T.eq(#exited, 0)
        end)

        T.it("love.quit returning nothing lets the quit go ahead", function()
            __MODE = mode
            dofile("tests/setup.lua")
            local exited = stubExits()
            dofile(EVENT[mode])
            lv1lua.running = true
            love.quit = function() end
            love.event.quit()
            os.exit = realExit
            T.nok(lv1lua.running)
        end)
    end)
end

io.write("\n=== love.event ===\n")
return T.summary()
