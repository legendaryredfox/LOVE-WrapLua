-- Blank ImageData on the native PSP backend: a generated gradient, a copy edited after upload, a file image recoloured.
local grad, edited, data

function love.load()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)
    data = love.image.newImageData(64, 64)
    for y = 0, 63 do
        for x = 0, 63 do data:setPixel(x, y, x / 63, y / 63, 0.5, 1) end
    end
    grad = love.graphics.newImage(data)
    data:mapPixel(function(x, y, r, g, b, a) return g, r, b, a end)
    edited = love.graphics.newImage(data)
end

function love.draw()
    love.graphics.draw(grad, 40, 60)
    love.graphics.draw(edited, 140, 60)
    love.graphics.draw(grad, 260, 60, 0, 2, 2)
end
