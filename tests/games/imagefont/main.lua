-- ImageFont on the native PSP backend: plain print, scaled, rotated, printf alignment, extra spacing, coloured Text.
local font, wide, text

function love.load()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)
    font = love.graphics.newImageFont("font.png", "ABC123")
    wide = love.graphics.newImageFont("font.png", "ABC123", 3)
    text = love.graphics.newText(font, { { 1, 0.3, 0.3, 1 }, "AB", { 0.3, 1, 0.3, 1 }, "C1", { 0.4, 0.5, 1, 1 }, "23" })
end

function love.draw()
    love.graphics.setFont(font)
    love.graphics.print("ABC123", 20, 20)
    love.graphics.print("A1B2\nC3", 20, 40, 0, 3, 3)
    love.graphics.setFont(wide)
    love.graphics.print("ABC123", 20, 110)
    love.graphics.setFont(font)
    love.graphics.printf("ABC123", 240, 20, 200, "center", 0, 2, 2)
    love.graphics.print("123ABC", 320, 150, math.pi / 6, 2, 2)
    love.graphics.draw(text, 20, 160, 0, 3, 3)
    love.graphics.setColor(1, 1, 0.4, 1)
    love.graphics.print("C2B1", 20, 220, 0, 2, 2)
    love.graphics.setColor(1, 1, 1, 1)
end
