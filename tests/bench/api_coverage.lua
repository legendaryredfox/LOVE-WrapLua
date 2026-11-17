-- Which love.* functions a game uses that a backend does not define. Lua 5.1:
--   lua5.1 tests/bench/api_coverage.lua <mode> <usage_file>      usage_file lines: "<count> love.module.function"
local mode, file = arg[1] or "PSP", arg[2]
if not file then io.stderr:write("usage: lua5.1 tests/bench/api_coverage.lua <mode> <usage_file> [limit]\n"); os.exit(1) end
__MODE = mode
dofile("tests/setup.lua")
-- boot the way script.lua does, so the list is what a game sees at love.load
dofile("LOVE-WrapLua/core/loader.lua")
for _, f in ipairs({ "util", "transform", "textwrap", "runtime", "input" }) do
    lv1lua.loadOnce("LOVE-WrapLua/core/" .. f .. ".lua")
end
lv1lua.load("LOVE-WrapLua/love-functions/thread.lua")
for _, f in ipairs({ "config", "timestep", "modules", "require", "callbacks" }) do
    lv1lua.loadOnce("LOVE-WrapLua/core/" .. f .. ".lua")
end
local missing, have, total = {}, 0, 0
for line in io.lines(file) do
    local n, mod, fn = line:match("^%s*(%d+)%s+love%.(%a+)%.(%a+)")
    if n then
        total = total + 1
        local m = love[mod]
        if m and m[fn] ~= nil then have = have + 1 else missing[#missing + 1] = { tonumber(n), mod .. "." .. fn } end
    end
end
table.sort(missing, function(a, b) return a[1] > b[1] end)
print(string.format("%s: %d/%d love.* functions used are defined", mode, have, total))
for i = 1, math.min(#missing, tonumber(arg[3] or 40)) do print(string.format("  %5d  love.%s", missing[i][1], missing[i][2])) end
