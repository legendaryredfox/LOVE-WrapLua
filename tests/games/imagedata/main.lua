-- ImageData on the native PSP backend: a generated gradient, a copy edited after upload, a PNG written and read back, paste.
local grad, edited, data, saved, pasted

function love.load()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)
    data = love.image.newImageData(64, 64)
    for y = 0, 63 do
        for x = 0, 63 do data:setPixel(x, y, x / 63, y / 63, 0.5, 1) end
    end
    grad = love.graphics.newImage(data)
    data:mapPixel(function(x, y, r, g, b, a) return g, r, b, a end)
    edited = love.graphics.newImage(data)
    data:encode("png", "roundtrip.png")
    saved = love.graphics.newImage("roundtrip.png")
    local canvas = love.image.newImageData(96, 48)
    canvas:paste(data, 0, 0, 0, 0, 48, 48)
    canvas:paste(data, 48, 0, 16, 16, 48, 48)
    pasted = love.graphics.newImage(canvas:clone())
end

function love.draw()
    love.graphics.draw(grad, 40, 60)
    love.graphics.draw(edited, 140, 60)
    love.graphics.draw(grad, 260, 60, 0, 2, 2)
    love.graphics.draw(saved, 40, 160)
    love.graphics.draw(pasted, 140, 160)
end
