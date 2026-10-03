-- lpp-3ds exposes no matrix stack, so the software stack handles
-- push/pop/translate/scale/rotate. Scissor is real: Graphics.setViewport is
-- sf2d_set_scissor_test, which maps the rectangle onto the rotated 3DS
-- framebuffer itself. It only holds until the frame ends, so beginFrame
-- re-applies it; draws wholly outside it are also rejected before the call.

lv1lua.gfx.transform = lv1lua.core.newTransformStack()
local stack = lv1lua.gfx.transform

function love.graphics.push(kind)
    stack:push()
end
love.graphics.push()

function love.graphics.pop()
    stack:pop()
    lv1lua.gfx.applyScissor()
end

function love.graphics.translate(offsetX, offsetY)
    local top = stack:top()
    if top then
        top._offsetX = top._offsetX + top._scaleX * offsetX
        top._offsetY = top._offsetY + top._scaleY * offsetY
        stack:invalidate()
    end
end

function love.graphics.scale(sx, sy)
    if not sy then sy = sx end
    local top = stack:top()
    if top then
        top._scaleX = top._scaleX * sx
        top._scaleY = top._scaleY * sy
        stack:invalidate()
    end
end

function love.graphics.rotate(angle)
    local top = stack:top()
    if top then
        top._rotation = (top._rotation or 0) + angle
        stack:invalidate()
    end
end

function love.graphics.shear(kx, ky)
end

function love.graphics.origin()
    local top = stack:top()
    if top then
        top._offsetX, top._offsetY = 0, 0
        top._scaleX,  top._scaleY  = 1, 1
        top._rotation = 0
        stack:invalidate()
    end
end

function love.graphics.reset()
    stack:clear()
    love.graphics.push()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBackgroundColor(0, 0, 0)
    lv1lua.gfx.lineWidth = 1
    lv1lua.gfx.applyScissor()
end

function love.graphics.applyTransform(transform)
    if transform and transform._m then
        local m = transform._m
        love.graphics.translate(m[7], m[8])
        love.graphics.scale(m[1], m[5])
    end
end

function love.graphics.replaceTransform(transform)
    love.graphics.origin()
    love.graphics.applyTransform(transform)
end

function love.graphics.transformPoint(x, y)
    stack:updateTransform()
    local t = stack.transform
    return x * t._scaleX + t._offsetX, y * t._scaleY + t._offsetY
end

function love.graphics.inverseTransformPoint(x, y)
    stack:updateTransform()
    local t = stack.transform
    if t._scaleX == 0 or t._scaleY == 0 then return x, y end
    return (x - t._offsetX) / t._scaleX, (y - t._offsetY) / t._scaleY
end

-- GPU_SCISSORMODE from libctru's gpu/enums.h; lpp-3ds registers no constant.
local SCISSOR_DISABLE, SCISSOR_NORMAL = 0, 3

function lv1lua.gfx.applyScissor()
    if not lv1lua.gfx.inFrame then return end
    stack:updateTransform()
    local t = stack.transform
    if t._usingScissor then
        local x = math.max(0, math.floor(t._scissorX))
        local y = math.max(0, math.floor(t._scissorY))
        Graphics.setViewport(x, y,
            math.max(0, math.floor(t._scissorX + t._scissorWidth) - x),
            math.max(0, math.floor(t._scissorY + t._scissorHeight) - y),
            SCISSOR_NORMAL)
    else
        Graphics.setViewport(0, 0, lv1lua.screenWidth, lv1lua.screenHeight, SCISSOR_DISABLE)
    end
end

function love.graphics.setScissor(x, y, w, h)
    local top = stack:top()
    if top then
        top._usingScissor = (x ~= nil)
        top._scissorX, top._scissorY = x, y
        top._scissorWidth, top._scissorHeight = w, h
        stack:invalidate()
    end
    lv1lua.gfx.applyScissor()
end

function love.graphics.getScissor()
    stack:updateTransform()
    local t = stack.transform
    if not t._usingScissor then return nil end
    return t._scissorX, t._scissorY, t._scissorWidth, t._scissorHeight
end

function love.graphics.intersectScissor(x, y, w, h)
    love.graphics.setScissor(x, y, w, h)
end

function lv1lua.gfx.scissorRejects(x, y, w, h)
    stack:updateTransform()
    local t = stack.transform
    if not t._usingScissor then return false end
    local sx, sy = t._scissorX, t._scissorY
    local sw, sh = t._scissorWidth, t._scissorHeight
    return (x + w) <= sx or x >= (sx + sw)
        or (y + h) <= sy or y >= (sy + sh)
end
