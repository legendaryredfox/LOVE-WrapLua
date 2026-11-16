-- VM instructions and bytes allocated by SpriteBatch, ParticleSystem and Text (Lua 5.1, count hook).
--   lua5.1 tests/bench/batch_cost.lua [mode ...]
local GFX = {
    ["PSP"] = "LOVE-WrapLua/OneLua/graphics_psp.lua", ["OneLua"] = "LOVE-WrapLua/OneLua/graphics.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua", ["PS3"] = "LOVE-WrapLua/PS3/graphics.lua",
}
local modes = #arg > 0 and arg or { "PSP", "lpp-vita" }

local function measure(fn)
    fn(); collectgarbage(); collectgarbage("stop")
    local n, mem0 = 0, collectgarbage("count")
    debug.sethook(function() n = n + 1 end, "", 1)
    fn()
    debug.sethook()
    local bytes = (collectgarbage("count") - mem0) * 1024
    collectgarbage("restart")
    return n, bytes
end

for _, mode in ipairs(modes) do
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.log = function() end
    local lg = love.graphics
    lg.origin()
    local img = lg.newImage("sheet.png")
    local quad = lg.newQuad(0, 0, 16, 16, img)

    local sb = lg.newSpriteBatch(img, 300)
    local function fill() sb:clear(); for i = 1, 200 do sb:add(quad, i % 50, i % 30) end end
    local fillN, fillB = measure(fill)
    fill()
    local drawN, drawB = measure(function() lg.draw(sb, 5, 5) end)

    local ps = lg.newParticleSystem(img, 300)
    ps:setPosition(100, 100); ps:setParticleLifetime(100, 200); ps:setSpeed(10, 50)
    ps:emit(200)
    local updN, updB = measure(function() ps:update(1 / 60) end)
    local pdrawN, pdrawB = measure(function() lg.draw(ps, 0, 0) end)

    local font = lg.newFont(12)
    local text = lg.newText(font, "")
    for i = 1, 10 do text:add("Line " .. i, 0, i * 12) end
    local tdrawN, tdrawB = measure(function() lg.draw(text, 5, 5) end)

    print(string.format("== %s", mode))
    print(string.format("  SpriteBatch add x200        %7d instr %7d B", fillN, fillB))
    print(string.format("  SpriteBatch draw (200)      %7d instr %7d B", drawN, drawB))
    print(string.format("  ParticleSystem update (200) %7d instr %7d B", updN, updB))
    print(string.format("  ParticleSystem draw (200)   %7d instr %7d B", pdrawN, pdrawB))
    print(string.format("  Text draw (10 strings)      %7d instr %7d B", tdrawN, tdrawB))
end
