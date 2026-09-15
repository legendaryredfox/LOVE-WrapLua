-- lpp-vita graphics: transform stack.
--
-- Not implemented yet: lpp-vita has no matrix stack, and folding a software
-- transform into drawImageExtended / the primitive coordinates is planned as a
-- separate change (see FIX_PLAN T2.2). Until then these are honest no-ops
-- rather than half-applied transforms, and the region is documented as
-- unsupported in Implemented.md.

function love.graphics.push()       end
function love.graphics.pop()        end
function love.graphics.translate()  end
function love.graphics.scale()      end
function love.graphics.rotate()     end
function love.graphics.shear()      end
function love.graphics.origin()     end

function love.graphics.reset()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBackgroundColor(0, 0, 0)
    lv1lua.gfx.lineWidth = 1
end

-- No native clip rectangle is exposed by lpp-vita.
function love.graphics.setScissor()       end
function love.graphics.getScissor()       return nil end
function love.graphics.intersectScissor()  end
