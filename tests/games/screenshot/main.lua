-- Needs PPSSPP's software renderer (ppsspp_software_rendering = enabled): the hardware renderer never writes new frames back to
-- emulated VRAM, so a CPU read returns frames 1 and 2 forever.
-- captureScreenshot on the native PSP backend: frame 12 saves the screen to a PNG and frame 20 reads it back and draws it
-- small in the corner; a callback copy taken at frame 5 (odd, then even, so both buffers are read) is tinted into a second corner.
local frame, shot, copy = 0, nil, nil

function love.load() love.graphics.setBackgroundColor(0.1, 0.1, 0.15) end

function love.update()
    frame = frame + 1
    if frame == 5 then
        love.graphics.captureScreenshot(function(d) d:mapPixel(function(x, y, r, g, b, a) return b, g, r, a end); copy = love.graphics.newImage(d) end)
    elseif frame == 12 then
        love.graphics.captureScreenshot("screen.png")
    elseif frame == 20 then
        shot = love.graphics.newImage("screen.png")
    end
end

function love.draw()
    love.graphics.setColor(1, 0.4, 0.2); love.graphics.rectangle("fill", 40, 40, 120, 80)
    love.graphics.setColor(0.2, 0.8, 1); love.graphics.circle("fill", 300, 90, 50)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("screenshot " .. frame, 20, 10)
    if shot then love.graphics.draw(shot, 20, 150, 0, 0.4, 0.4) end
    if copy then love.graphics.draw(copy, 250, 150, 0, 0.4, 0.4) end
end
