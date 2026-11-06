-- One synthetic Balatro-sized frame per backend: VM instructions and bytes allocated.
-- Mix per frame: 213 push/translate/scale/pop, 168 setColor, 124 draw (60% quad, 25% quad scaled,
-- 15% rotated), 54 polygon fills, 45 prints. Lua 5.1:
--   lua5.1 tests/bench/frame_cost.lua [mode] [--check]
-- --check compares with tests/bench/frame_baseline.lua and exits 1 if a backend got > 10% worse.
local GFX = {
    ["PSP"] = "LOVE-WrapLua/OneLua/graphics_psp.lua", ["OneLua"] = "LOVE-WrapLua/OneLua/graphics.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua", ["PS3"] = "LOVE-WrapLua/PS3/graphics.lua",
}
local only, check = nil, false
for _, a in ipairs(arg) do if a == "--check" then check = true elseif a ~= "--sections" then only = a end end
local base = {}
if check then local ok, t = pcall(dofile, "tests/bench/frame_baseline.lua"); if ok then base = t end end

local results, bad = {}, false
for _, mode in ipairs({ "PSP", "OneLua", "lpp-vita", "PS3" }) do
    if not only or only == mode then
        __MODE = mode
        dofile("tests/setup.lua")
        if mode == "PSP" then image.copyscale = nil end
        dofile(GFX[mode])
        __rec.log = function() end
        local img = love.graphics.newImage("sheet.png")
        local quad = love.graphics.newQuad(0, 0, 16, 16, img)
        local pts = { 0, 0, 10, 0, 12, 6, 6, 12, 0, 6 }
        love.graphics.origin()
        local g = love.graphics
        local function frame()
            for i = 1, 213 do g.push(); g.translate(i % 7, i % 5); g.scale(1.01, 1.01); g.pop() end
            for i = 1, 168 do g.setColor((i % 5) / 4, (i % 3) / 2, 0.5, 1) end
            for i = 1, 124 do
                if i % 20 < 12 then g.draw(img, quad, i, 10)
                elseif i % 20 < 17 then g.draw(img, quad, i, 10, 0, 2, 2)
                else g.draw(img, quad, i, 10, 0.4, 1.5, 1.5, 8, 8) end
            end
            for i = 1, 54 do g.polygon("fill", pts) end
            for i = 1, 45 do g.print("Score", i, 20) end
        end
        if arg[#arg] == "--sections" then
            local function cnt(f) local k = 0; f(); debug.sethook(function() k = k + 1 end, "", 1); f(); debug.sethook(); return k end
            print(mode, "push/translate/scale/pop x213", cnt(function() for i = 1, 213 do g.push(); g.translate(i % 7, i % 5); g.scale(1.01, 1.01); g.pop() end end))
            print(mode, "setColor x168", cnt(function() for i = 1, 168 do g.setColor((i % 5) / 4, (i % 3) / 2, 0.5, 1) end end))
            print(mode, "draw x124", cnt(function() for i = 1, 124 do if i % 20 < 12 then g.draw(img, quad, i, 10) elseif i % 20 < 17 then g.draw(img, quad, i, 10, 0, 2, 2) else g.draw(img, quad, i, 10, 0.4, 1.5, 1.5, 8, 8) end end end))
            print(mode, "polygon fill x54", cnt(function() for i = 1, 54 do g.polygon("fill", pts) end end))
            print(mode, "print x45", cnt(function() for i = 1, 45 do g.print("Score", i, 20) end end))
        end
        frame()
        collectgarbage(); collectgarbage("stop")
        local n, mem0 = 0, collectgarbage("count")
        debug.sethook(function() n = n + 1 end, "", 1)
        frame()
        debug.sethook()
        local bytes = (collectgarbage("count") - mem0) * 1024
        collectgarbage("restart")
        results[mode] = { instr = n, bytes = bytes }
        local line = string.format("%-9s %8d instr/frame (~%.1f ms at 3M instr/s)  %8.0f B/frame", mode, n, n / 3000, bytes)
        local b = base[mode]
        if b then
            local d = (n - b.instr) / b.instr * 100
            line = line .. string.format("  vs baseline %+.1f%%", d)
            if d > 10 then bad = true; line = line .. "  REGRESSION" end
        end
        print(line)
    end
end
if check and bad then os.exit(1) end
