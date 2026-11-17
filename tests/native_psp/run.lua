-- Contract tests for backend/love_psp.lua with a mocked `native`. Run via tests/backend/run.sh
local pass, fail = 0, 0
local suite = "?"
function describe(n, f) suite = n; f() end
function it(d, f)
    local ok, e = pcall(f)
    if ok then pass = pass + 1 else fail = fail + 1; io.write("  FAIL  ", suite, ": ", d, "\n        ", tostring(e), "\n") end
end
function eq(g, w) if g ~= w then error(("want %s, got %s"):format(tostring(w), tostring(g)), 2) end end
function ok(v, m) if not v then error(m or "expected truthy", 2) end end

-- LuaBitOp stand-in (the real `bit` is registered by native/src/lbit.c)
bit = { band = function(a, b) local r, m = 0, 1; while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + m end; a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2 end return r end }
native = dofile(os.getenv("TESTDIR") .. "/mock_native.lua")
PSP_CONFIG = { identity = "t", title = "T", os = "TestOS", font = "default.ttf" }
dofile("love_psp.lua")
dofile("shared.lua")
dofile("extras.lua")
local N = native
for _, f in ipairs({ "cases.lua" }) do dofile(os.getenv("TESTDIR") .. "/" .. f) end
io.write(("backend tests: %d passed, %d failed\n"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
