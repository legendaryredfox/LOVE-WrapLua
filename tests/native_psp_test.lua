-- Contract tests for the native PSP backend (LOVE-WrapLua/PSPNative/love_psp.lua) with a mocked `native`
-- module (tests/native_psp/mock_native.lua). The backend reads game/ and save/ relative to the working
-- directory, as it does next to the EBOOT, so the cases run in a child interpreter inside a scratch directory.

local T = dofile("tests/runner.lua")

-- The backend runs on the EBOOT's Lua 5.1 (it uses unpack and loadstring); LuaJIT reports the same version.
if _VERSION ~= "Lua 5.1" then
    io.write("\n=== native PSP backend: skipped on " .. _VERSION .. " ===\n")
    return T.summary()
end

local interpreter = (arg and arg[-1]) or "lua"
local root = io.popen("pwd"):read("*l")

local function sh(cmd) return os.execute(cmd) end

local scratch = os.tmpname()
os.remove(scratch)
local src = scratch .. ".game"
sh("mkdir -p '" .. src .. "/sub'")
local function put(path, data)
    local f = assert(io.open(src .. "/" .. path, "wb"))
    f:write(data)
    f:close()
end
put("hello.txt", "hi\n")
put("chunk.lua", "return 42\n")
put("pic.png", "x")
put("imgfont.png", "x")
put("two.png", "x")
put("tone.mp3", "x")
put("song.mp3", "x")
put("both.mp3", "x")
put("both.ogg", "x")
put("only.ogg", "x")
put("default.ttf", "x")
-- the same staging the packaging command does, minus the EBOOT
sh("cd '" .. root .. "' && " .. interpreter .. " tools/lovepsp.lua stage '" .. src .. "' '" .. scratch .. "'")

local function child(script)
    local p = io.popen("cd '" .. scratch .. "' && TESTDIR='" .. root .. "/tests/native_psp' "
        .. interpreter .. " '" .. root .. "/tests/native_psp/" .. script .. "' 2>&1")
    local out = p:read("*a")
    p:close()
    return out
end

T.describe("native PSP backend contract", function()
    local out = child("run.lua")
    local passed, failed = out:match("backend tests: (%d+) passed, (%d+) failed")
    T.ok(passed ~= nil, "the child run printed no summary:\n" .. out)
    T.it("every case passes", function()
        if tonumber(failed) ~= 0 then error(out, 0) end
    end)
    T.it("the suite is not empty", function()
        T.ok(tonumber(passed) >= 60, "only " .. tostring(passed) .. " cases ran")
    end)
end)

sh("rm -rf '" .. scratch .. "' '" .. src .. "'")
io.write("\n=== native PSP backend ===\n")
return T.summary()
