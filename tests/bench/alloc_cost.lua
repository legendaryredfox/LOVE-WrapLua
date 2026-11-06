-- Bytes allocated per love.graphics call (garbage the console's GC has to chase). Lua 5.1:
--   lua5.1 tests/bench/alloc_cost.lua [mode]
local GFX = {
    ["PSP"] = "LOVE-WrapLua/OneLua/graphics_psp.lua", ["OneLua"] = "LOVE-WrapLua/OneLua/graphics.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua", ["PS3"] = "LOVE-WrapLua/PS3/graphics.lua",
}
local N = 2000
for _, mode in ipairs({ "PSP", "OneLua", "lpp-vita", "PS3" }) do
    if not arg[1] or arg[1] == mode then
        __MODE = mode
        dofile("tests/setup.lua")
        if mode == "PSP" then image.copyscale = nil end
        dofile(GFX[mode])
        __rec.log = function() end
        local img = love.graphics.newImage("sheet.png")
        local quad = love.graphics.newQuad(0, 0, 16, 16, img)
        love.graphics.origin()
        local ops = {
            { "setColor", function() love.graphics.setColor(1, 0.5, 0.2, 1) end },
            { "setColor(table)", function() love.graphics.setColor({ 0.2, 0.4, 0.6, 1 }) end },
            { "push/translate/pop", function() love.graphics.push(); love.graphics.translate(3, 4); love.graphics.pop() end },
            { "draw quad", function() love.graphics.draw(img, quad, 10, 20) end },
            { "draw quad scale+rot", function() love.graphics.draw(img, quad, 10, 20, 0.5, 2, 2, 8, 8) end },
            { "rectangle fill", function() love.graphics.rectangle("fill", 10, 20, 30, 40) end },
            { "print", function() love.graphics.print("Hello", 10, 20) end },
        }
        print("== " .. mode .. " (bytes/call; mock natives allocate too: color.new etc.)")
        for _, op in ipairs(ops) do
            op[2](); collectgarbage(); collectgarbage("stop")
            local before = collectgarbage("count")
            for _ = 1, N do op[2]() end
            local after = collectgarbage("count")
            collectgarbage("restart")
            print(string.format("  %-22s %7.1f", op[1], (after - before) * 1024 / N))
        end
    end
end
