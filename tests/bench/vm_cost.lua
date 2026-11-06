-- VM instructions per love.graphics call, per backend, measured on the test mocks.
-- Run from the repo root with Lua 5.1: lua5.1 tests/bench/vm_cost.lua
-- The count hook (every instruction) makes this independent of the host's speed, so it is a fair
-- way to compare wrapper changes; real consoles run roughly 3M VM instructions per second.
local GFX = {
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
    ["3DS"]      = "LOVE-WrapLua/3DS/graphics.lua",
}
local N = 300
local only = arg[1]

local function count(fn)
    local n = 0
    debug.sethook(function() n = n + 1 end, "", 1)
    fn()
    debug.sethook()
    return n
end

for _, mode in ipairs({ "PSP", "OneLua", "lpp-vita", "PS3", "3DS" }) do
    if not only or only == mode then
        __MODE = mode
        dofile("tests/setup.lua")
        if mode == "PSP" then image.copyscale = nil end        -- the real PSP EBOOT has none
        dofile(GFX[mode])
        __rec.log = function() end                              -- do not charge the mock's recorder
        local img = love.graphics.newImage("sheet.png")
        local quad = love.graphics.newQuad(0, 0, 16, 16, img)
        love.graphics.origin()
        local ops = {
            { "setColor",              function() love.graphics.setColor(1, 0.5, 0.2, 1) end },
            { "push/translate/pop",    function() love.graphics.push(); love.graphics.translate(3, 4); love.graphics.pop() end },
            { "draw image",            function() love.graphics.draw(img, 10, 20) end },
            { "draw quad",             function() love.graphics.draw(img, quad, 10, 20) end },
            { "draw quad scaled",      function() love.graphics.draw(img, quad, 10, 20, 0, 2, 2) end },
            { "draw quad scale+rot",   function() love.graphics.draw(img, quad, 10, 20, 0.5, 2, 2, 8, 8) end },
            { "rectangle fill",        function() love.graphics.rectangle("fill", 10, 20, 30, 40) end },
            { "circle fill",           function() love.graphics.circle("fill", 10, 20, 8) end },
            { "line",                  function() love.graphics.line(1, 2, 30, 40) end },
            { "print",                 function() love.graphics.print("Hello", 10, 20) end },
        }
        local out = {}
        for _, op in ipairs(ops) do
            local fn = op[2]
            fn()                                                -- warm caches (first draw may build a copy)
            local total = count(function() for _ = 1, N do fn() end end)
            out[#out + 1] = string.format("%-20s %6.0f", op[1], total / N)
        end
        print("== " .. mode)
        for _, l in ipairs(out) do print("  " .. l) end
    end
end
