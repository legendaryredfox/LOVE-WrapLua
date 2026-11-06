-- Where the VM instructions of one love.graphics call go (per source line). Lua 5.1:
--   lua5.1 tests/bench/vm_profile.lua <mode> <op>     op: setColor | image | quad | quadscaled | rect | print | pushpop
local GFX = {
    ["PSP"] = "LOVE-WrapLua/OneLua/graphics_psp.lua", ["OneLua"] = "LOVE-WrapLua/OneLua/graphics.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua", ["PS3"] = "LOVE-WrapLua/PS3/graphics.lua", ["3DS"] = "LOVE-WrapLua/3DS/graphics.lua",
}
local mode, opname = arg[1] or "PSP", arg[2] or "quad"
__MODE = mode
dofile("tests/setup.lua")
if mode == "PSP" then image.copyscale = nil end
dofile(GFX[mode])
__rec.log = function() end
local img = love.graphics.newImage("sheet.png")
local quad = love.graphics.newQuad(0, 0, 16, 16, img)
love.graphics.origin()
local ops = {
    setColor = function() love.graphics.setColor(1, 0.5, 0.2, 1) end,
    image = function() love.graphics.draw(img, 10, 20) end,
    quad = function() love.graphics.draw(img, quad, 10, 20) end,
    quadscaled = function() love.graphics.draw(img, quad, 10, 20, 0, 2, 2) end,
    rect = function() love.graphics.rectangle("fill", 10, 20, 30, 40) end,
    print = function() love.graphics.print("Hello", 10, 20) end,
    pushpop = function() love.graphics.push(); love.graphics.translate(3, 4); love.graphics.pop() end,
}
local fn = ops[opname]; fn(); fn()
local lines, total = {}, 0
debug.sethook(function()
    local i = debug.getinfo(2, "Sl")
    if i and i.short_src and not i.short_src:find("profile") then
        local k = i.short_src .. ":" .. (i.currentline or 0)
        lines[k] = (lines[k] or 0) + 1; total = total + 1
    end
end, "", 1)
fn()
debug.sethook()
local arr = {}
for k, v in pairs(lines) do arr[#arr + 1] = { k, v } end
table.sort(arr, function(a, b) return a[2] > b[2] end)
print(mode, opname, "instructions:", total)
local by = {}
for _, r in ipairs(arr) do
    local f = r[1]:match("^(.-):%d+$"); by[f] = (by[f] or 0) + r[2]
end
for f, n in pairs(by) do print(string.format("  %-55s %4d", f, n)) end
if arg[3] then for i = 1, math.min(tonumber(arg[3]), #arr) do print(string.format("    %-60s %3d", arr[i][1], arr[i][2])) end end
