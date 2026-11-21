-- The C mixing loop of the native PSP backend (native/src/mix.c, no platform headers), compiled with the host C compiler
-- and checked against a one-frame-at-a-time reference. Skipped when there is no cc.

local T = dofile("tests/runner.lua")

local function ok(cmd)
    local r = os.execute(cmd)
    return r == 0 or r == true
end

io.write("\n=== native PSP mixer (C) ===\n")
if not ok("command -v cc >/dev/null 2>&1") then
    io.write("  skipped: no C compiler\n")
    return T.summary()
end

local exe = os.tmpname()
T.describe("mix_run", function()
    T.it("compiles", function()
        T.ok(ok("cc -O2 -Wall -Werror -o '" .. exe .. "' tests/native_c/mix_test.c native/src/mix.c 2>&1"), "cc failed")
    end)
    T.it("matches the reference over every case", function()
        local p = io.popen("'" .. exe .. "' 2>&1")
        local out = p:read("*a")
        p:close()
        T.ok(out:match("mix: %d+ cases ok"), out)
    end)
end)
os.remove(exe)
return T.summary()
