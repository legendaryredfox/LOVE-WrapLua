-- Identity transform API for the backends without a matrix stack (PSP, PS3).
--
-- These used to be two hand-written copies that each defined push/pop/translate
-- and stopped there, so a game calling transformPoint or applyTransform on
-- those backends hit a nil instead of a documented no-op. One copy, and the
-- same function set the stacked backends expose (CODE_REVIEW R13).

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

function love.graphics.applyTransform()   end
function love.graphics.replaceTransform() end

-- With no stack, a point maps to itself both ways.
function love.graphics.transformPoint(x, y)        return x, y end
function love.graphics.inverseTransformPoint(x, y) return x, y end

function love.graphics.setScissor()       end
function love.graphics.getScissor()       return nil end
function love.graphics.intersectScissor() end
