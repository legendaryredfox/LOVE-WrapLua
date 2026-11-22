-- Mesh on the native PSP backend: an untextured coloured triangle, a textured fan, a strip and a vertex-mapped quad.
local img, fan, tri, strip, quad

function love.load()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)
    img = love.graphics.newImage("checker.png")
    tri = love.graphics.newMesh({
        { 40, 200, 0, 0, 1, 0, 0, 1 }, { 120, 200, 0, 0, 0, 1, 0, 1 }, { 80, 120, 0, 0, 0, 0, 1, 1 },
    }, "triangles")
    fan = love.graphics.newMesh({
        { 240, 160, 0.5, 0.5, 1, 1, 1, 1 }, { 200, 120, 0, 0, 1, 1, 1, 1 }, { 280, 120, 1, 0, 1, 1, 1, 1 },
        { 280, 200, 1, 1, 1, 1, 1, 1 }, { 200, 200, 0, 1, 1, 1, 1, 1 }, { 200, 120, 0, 0, 1, 1, 1, 1 },
    }, "fan")
    fan:setTexture(img)
    strip = love.graphics.newMesh({
        { 320, 120, 0, 0, 1, 0.5, 0, 1 }, { 320, 200, 0, 1, 1, 0.5, 0, 1 }, { 360, 120, 0.5, 0, 0, 1, 0.5, 1 },
        { 360, 200, 0.5, 1, 0, 1, 0.5, 1 }, { 400, 120, 1, 0, 0.5, 0, 1, 1 }, { 400, 200, 1, 1, 0.5, 0, 1, 1 },
    }, "strip")
    quad = love.graphics.newMesh({
        { 0, 0, 0, 0, 1, 1, 1, 1 }, { 40, 0, 1, 0, 1, 1, 1, 1 }, { 40, 40, 1, 1, 1, 1, 1, 1 }, { 0, 40, 0, 1, 1, 1, 1, 1 },
    }, "triangles")
    quad:setTexture(img)
    quad:setVertexMap({ 1, 2, 3, 1, 3, 4 })
end

function love.draw()
    love.graphics.draw(tri)
    love.graphics.draw(fan)
    love.graphics.draw(strip)
    love.graphics.draw(quad, 60, 40)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.draw(quad, 140, 40, 0.3, 1.5, 1.5, 20, 20)
    love.graphics.setColor(1, 1, 1, 1)
end
