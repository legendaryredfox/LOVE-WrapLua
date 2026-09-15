-- PS3 graphics: transform stack.
--
-- Not implemented: the PS3 Lua Player blits surfaces at fixed positions with no
-- matrix state. These are honest no-ops, documented as unsupported.

function love.graphics.push()      end
function love.graphics.pop()       end
function love.graphics.translate() end
function love.graphics.scale()     end
function love.graphics.rotate()    end
function love.graphics.shear()     end
function love.graphics.origin()    end

function love.graphics.reset()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBackgroundColor(0, 0, 0)
    lv1lua.gfx.lineWidth = 1
end

function love.graphics.setScissor()       end
function love.graphics.getScissor()       return nil end
function love.graphics.intersectScissor() end
