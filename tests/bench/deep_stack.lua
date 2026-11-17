-- VM instructions of a nested draw sequence, the shape of a UI tree: every node pushes, translates, scales and
-- draws a small rectangle, `depth` levels deep, `width` siblings per level pair. Lua 5.1:
--   lua5.1 tests/bench/deep_stack.lua [mode] [depth]
local mode, depth = arg[1] or "PSP", tonumber(arg[2]) or 8
local GFX = {
    ["PSP"] = "LOVE-WrapLua/OneLua/graphics_psp.lua", ["OneLua"] = "LOVE-WrapLua/OneLua/graphics.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua", ["PS3"] = "LOVE-WrapLua/PS3/graphics.lua", ["3DS"] = "LOVE-WrapLua/3DS/graphics.lua",
}
__MODE = mode
dofile("tests/setup.lua")
dofile(GFX[mode])
__rec.log = function() end
local g = love.graphics
g.origin()
local function node(level)
    g.push()
    g.translate(level, 1)
    g.scale(1.01, 1.01)
    g.rectangle("fill", 0, 0, 4, 4)
    if level < depth then
        node(level + 1)
        node(level + 1)
    end
    g.pop()
end
local function frame() for _ = 1, 3 do node(1) end end
frame()
local n = 0
debug.sethook(function() n = n + 1 end, "", 1)
frame()
debug.sethook()
print(string.format("%-9s depth %d: %d instr/frame", mode, depth, n))
