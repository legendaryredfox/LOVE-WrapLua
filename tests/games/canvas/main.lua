-- Canvas on the native PSP backend: render to two canvases, draw them whole, then blit sub-rects of a canvas through
-- Quads under a scissor, as an atlas cache does. Expected screen: grey background; "direct" text and a white square on
-- the left; a dark-blue canvas (green and yellow rectangles, "canvas 1") and a blue square canvas on top; below, two
-- halves of canvas 1 shown as separate quads, the second one clipped by the scissor to a 40 px wide column.
local c1, c2, left, right

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    c1 = love.graphics.newCanvas(200, 120)
    c2 = love.graphics.newCanvas(200, 120)
    left = love.graphics.newQuad(0, 0, 100, 120, 200, 120)
    right = love.graphics.newQuad(100, 0, 100, 120, 200, 120)
end

function love.draw()
    local lg = love.graphics
    lg.setCanvas(c1)
    lg.clear(0.1, 0.1, 0.4, 1)
    lg.setColor(0, 1, 0, 1); lg.rectangle("fill", 130, 10, 60, 40)
    lg.setColor(1, 1, 0, 1); lg.rectangle("fill", 100, 60, 30, 30)
    lg.setColor(1, 1, 1, 1); lg.print("canvas 1", 10, 90)
    lg.setCanvas(c2)
    lg.clear(0, 0, 0, 0)
    lg.setColor(0, 0, 1, 1); lg.rectangle("fill", 100, 60, 30, 30)
    lg.setCanvas()
    lg.clear(0.3, 0.3, 0.3, 1)
    lg.setColor(1, 1, 1, 1); lg.print("direct", 10, 10); lg.rectangle("fill", 10, 40, 30, 30)
    lg.draw(c1, 120, 8)
    lg.draw(c2, 340, 8)
    lg.draw(c1, left, 20, 140)
    lg.setScissor(160, 140, 40, 120)
    lg.draw(c1, right, 140, 140)
    lg.setScissor()
end
