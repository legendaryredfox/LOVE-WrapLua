-- OneLua (Vita): love.mouse mapped onto the front touchscreen.
--
-- A touch is the left button: a game written for a mouse keeps working, and
-- the position is the last place a finger was seen.

love.mouse._lastX = 0
love.mouse._lastY = 0

function love.mouse.getX() return love.mouse._lastX end
function love.mouse.getY() return love.mouse._lastY end

function love.mouse.getPosition()
    return love.mouse._lastX, love.mouse._lastY
end

function love.mouse.isDown(button)
    if button ~= nil and button ~= 1 then return false end
    return love.touch.getPressure(1) == 1
end

function love.mouse.isVisible()     return false end
function love.mouse.setVisible()    end
function love.mouse.setPosition()   end
function love.mouse.isGrabbed()     return false end
function love.mouse.setGrabbed()    end
function love.mouse.getRelativeMode() return false end
function love.mouse.setRelativeMode()  end

-- Called by the frame loop after the touch panel has been read.
function love.mouse.__updateMouse()
    if love.touch._count > 0 then
        love.mouse._lastX, love.mouse._lastY = love.touch.getPosition(1)
    end
end
