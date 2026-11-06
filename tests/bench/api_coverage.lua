-- Which love.* functions a game uses that a backend does not define. Lua 5.1:
--   lua5.1 tests/bench/api_coverage.lua <mode> <usage_file>      usage_file lines: "<count> love.module.function"
local mode, file = arg[1] or "PSP", arg[2]
local GFX = {
    ["PSP"] = "LOVE-WrapLua/OneLua/graphics_psp.lua", ["OneLua"] = "LOVE-WrapLua/OneLua/graphics.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua", ["PS3"] = "LOVE-WrapLua/PS3/graphics.lua", ["3DS"] = "LOVE-WrapLua/3DS/graphics.lua",
}
__MODE = mode
dofile("tests/setup.lua")
-- load the backend and every shared module the way core/modules.lua does
dofile(GFX[mode])
local backend = "LOVE-WrapLua/" .. (mode == "PSP" and "OneLua" or mode) .. "/"
for _, f in ipairs({ "whileloop.lua", "timer.lua", "audio.lua", "event.lua", "keyboard.lua" }) do pcall(dofile, backend .. f) end
for _, f in ipairs({ "filesystem.lua", "math.lua", "system.lua", "window.lua", "joystick.lua", "data.lua", "thread.lua" }) do pcall(dofile, "LOVE-WrapLua/" .. f) end
pcall(dofile, "LOVE-WrapLua/core/thread.lua")
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
