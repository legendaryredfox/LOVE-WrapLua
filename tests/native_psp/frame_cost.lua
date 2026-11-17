-- Synthetic Balatro-sized frame on the native backend: Lua VM instructions and bytes allocated per frame.
-- Same mix as LOVE-WrapLua/tests/bench/frame_cost.lua (213 push/translate/scale/pop, 168 setColor,
-- 124 draw, 54 polygon fill, 45 print) so the numbers compare. Run via tests/backend/run.sh bench
bit = { band = function(a, b) return 0 end }
native = dofile(os.getenv("TESTDIR") .. "/mock_native.lua")
for k, v in pairs(native) do if type(v) == "function" then native[k] = function() end end end   -- C calls cost 1 instr, nothing recorded
native.image_load = function() return {}, 32, 16 end
native.font_load = function() return {}, 10, -2, 12 end
native.font_width = function() return 30 end
native.time = function() return 0 end
native.stat = function() return "file", 1, 1 end
PSP_CONFIG = { font = "default.ttf" }
dofile("love_psp.lua")
local g = love.graphics
local img = g.newImage("pic.png")
local quad = g.newQuad(0, 0, 16, 16, 32, 16)
local pts = { 0, 0, 10, 0, 12, 6, 6, 12, 0, 6 }
g.origin()
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
local function cnt(f) local k = 0; f(); debug.sethook(function() k = k + 1 end, "", 1); f(); debug.sethook(); return k end
print(string.format("%-34s %7d instr", "push/translate/scale/pop x213", cnt(function() for i = 1, 213 do g.push(); g.translate(i % 7, i % 5); g.scale(1.01, 1.01); g.pop() end end)))
print(string.format("%-34s %7d instr", "setColor x168", cnt(function() for i = 1, 168 do g.setColor((i % 5) / 4, (i % 3) / 2, 0.5, 1) end end)))
print(string.format("%-34s %7d instr", "draw x124", cnt(function() for i = 1, 124 do if i % 20 < 12 then g.draw(img, quad, i, 10) elseif i % 20 < 17 then g.draw(img, quad, i, 10, 0, 2, 2) else g.draw(img, quad, i, 10, 0.4, 1.5, 1.5, 8, 8) end end end)))
print(string.format("%-34s %7d instr", "polygon fill x54", cnt(function() for i = 1, 54 do g.polygon("fill", pts) end end)))
print(string.format("%-34s %7d instr", "print x45", cnt(function() for i = 1, 45 do g.print("Score", i, 20) end end)))
frame(); collectgarbage(); collectgarbage("stop")
local n, mem0 = 0, collectgarbage("count")
debug.sethook(function() n = n + 1 end, "", 1); frame(); debug.sethook()
local bytes = (collectgarbage("count") - mem0) * 1024
print(string.format("%-34s %7d instr/frame (~%.1f ms at 3M instr/s)  %.0f B/frame", "native backend", n, n / 3000, bytes))
