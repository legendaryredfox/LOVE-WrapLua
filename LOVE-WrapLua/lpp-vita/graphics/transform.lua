-- lpp-vita graphics: transform stack + scissor.
--
-- lpp-vita exposes no matrix stack, so push/pop/translate/scale/rotate are
-- tracked in the shared software stack (core/transform.lua) and folded into the
-- native draw calls: the flattened offset/scale/rotation feed drawImageExtended
-- and the primitive coordinates. vita2d exposes no clip rectangle either, so
-- scissor is enforced by software-rejecting draws whose bounding box falls
-- entirely outside the region (documented in Implemented.md). (FIX_PLAN T2.2)

lv1lua.gfx.transform = lv1lua.core.newTransformStack()
local stack = lv1lua.gfx.transform

function love.graphics.push(kind)
    stack:push()
end
love.graphics.push()  -- LÖVE always has one active level

function love.graphics.pop()
    stack:pop()
end

function love.graphics.translate(offsetX, offsetY)
    local top = stack:top()
    if top then
        -- Compose in local (already-scaled) space so repeated translates inside
        -- one push accumulate.
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
    -- No native shear on lpp-vita; documented as unsupported in Implemented.md.
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

-- ── Scissor ──────────────────────────────────────────────────────
function love.graphics.setScissor(x, y, w, h)
    local top = stack:top()
    if top then
        top._usingScissor = (x ~= nil)
        top._scissorX, top._scissorY = x, y
        top._scissorWidth, top._scissorHeight = w, h
        stack:invalidate()
    end
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

-- True when the [x,y,w,h] screen-space box lies entirely outside the active
-- scissor and the draw can be skipped. No scissor set means never reject.
function lv1lua.gfx.scissorRejects(x, y, w, h)
    stack:updateTransform()
    local t = stack.transform
    if not t._usingScissor then return false end
    local sx, sy = t._scissorX, t._scissorY
    local sw, sh = t._scissorWidth, t._scissorHeight
    return (x + w) <= sx or x >= (sx + sw)
        or (y + h) <= sy or y >= (sy + sh)
end
