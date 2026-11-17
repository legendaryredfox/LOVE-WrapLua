-- SpriteBatch, ParticleSystem, points, arc and File on the console build. Draws them (read the screenshot) and
-- logs EXTRAS lines. Package with a player.png next to this file.
local g = love.graphics
local img, quad, batch, ps
local function check(name, cond) PSP_LOG("EXTRAS " .. (cond and "ok   " or "FAIL ") .. name) end

function love.load()
    img = g.newImage("player.png")
    quad = g.newQuad(0, 0, 48, 48, img:getWidth(), img:getHeight())
    batch = g.newSpriteBatch(img, 50)
    for i = 0, 4 do batch:add(quad, 20 + i * 50, 20, 0, 1, 1) end
    batch:setColor(1, 0.3, 0.3, 1)
    batch:add(quad, 20, 80)
    check("spritebatch count", batch:getCount() == 6)

    ps = g.newParticleSystem(img, 40)
    ps:setPosition(360, 200); ps:setSpeed(10, 40); ps:setDirection(-math.pi / 2); ps:setSpread(1)
    ps:setParticleLifetime(1, 2); ps:setSizes(0.2, 0.6, 0.1); ps:setColors(1, 1, 1, 1, 1, 0, 0, 0)
    ps:emit(25)
    check("particles emitted", ps:getCount() == 25)

    local f = love.filesystem.newFile("e.txt", "w"); f:write("abc\ndef"); f:close()
    local r = love.filesystem.newFile("e.txt", "r")
    local n = 0; for _ in r:lines() do n = n + 1 end; r:close()
    check("file lines", n == 2 and love.filesystem.getInfo("e.txt").size == 7)
    PSP_LOG("EXTRAS done")
end

function love.update(dt) ps:update(dt) end

function love.draw()
    g.setColor(1, 1, 1, 1)
    g.draw(batch, 0, 0)
    g.setPointSize(3); g.setColor(0, 1, 0, 1)
    for i = 0, 20 do g.points(20 + i * 8, 150) end
    g.setColor(1, 1, 0, 1); g.arc("fill", 100, 220, 30, 0, 4.5, 16)
    g.setColor(0, 0.6, 1, 1); g.arc("line", "open", 200, 220, 30, 0, math.pi, 12)
    g.setColor(1, 1, 1, 1); g.draw(ps)
end
