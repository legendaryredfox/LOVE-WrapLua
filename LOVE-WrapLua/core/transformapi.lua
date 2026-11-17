-- love.graphics transform and scissor surface, shared by every backend.
--
-- No console SDK exposes a matrix stack, so the stack is the software one in
-- core/transform.lua and each backend folds the flattened result into its own
-- draw calls. A backend with a hardware scissor (the 3DS) supplies the
-- optional hook `lv1lua.gfx.applyScissor()`, called whenever the active
-- scissor can change.

local gfx = lv1lua.gfx
gfx.transform = lv1lua.core.newTransformStack()
local stack = gfx.transform

-- Lua 5.3 folded atan2 into math.atan(y, x).
local atan2 = math.atan2 or math.atan

local function applyScissor()
    if gfx.applyScissor then gfx.applyScissor() end
end

function love.graphics.push(kind)
    stack:push()
end
love.graphics.push()  -- LOVE always has one active level

function love.graphics.pop()
    local levels = stack.stack
    local top = levels[#levels]
    local scissored = top and top._usingScissor
    stack:pop()
    if scissored then applyScissor() end
end

function love.graphics.translate(offsetX, offsetY)
    local top = stack:top()
    if top then
        -- Compose in local (already-scaled) space, so repeated translates
        -- inside one push accumulate.
        top._offsetX = top._offsetX + top._scaleX * offsetX + top._shearB * offsetY
        top._offsetY = top._offsetY + top._shearC * offsetX + top._scaleY * offsetY
        stack:invalidate()
    end
end

function love.graphics.scale(sx, sy)
    if not sy then sy = sx end
    local top = stack:top()
    if top then
        top._scaleX = top._scaleX * sx
        top._scaleY = top._scaleY * sy
        top._shearB = top._shearB * sy
        top._shearC = top._shearC * sx
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

-- Shapes and lines shear exactly. No SDK here can shear an image or a string, so those only move to
-- the sheared position of their origin.
function love.graphics.shear(kx, ky)
    local top = stack:top()
    if top then
        kx, ky = kx or 0, ky or 0
        local sx, sy, b, c = top._scaleX, top._scaleY, top._shearB, top._shearC
        top._scaleX, top._shearB = sx + b * ky, sx * kx + b
        top._shearC, top._scaleY = c + sy * ky, c * kx + sy
        stack:invalidate()
    end
end

function love.graphics.origin()
    local top = stack:top()
    if top then
        top._offsetX, top._offsetY = 0, 0
        top._scaleX,  top._scaleY  = 1, 1
        top._shearB,  top._shearC  = 0, 0
        top._rotation = 0
        stack:invalidate()
    end
end

function love.graphics.reset()
    stack:clear()
    love.graphics.push()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBackgroundColor(0, 0, 0)
    gfx.lineWidth = 1
    applyScissor()
end

-- A love.math Transform is decomposed into translate, rotate, scale and shear along x.
function love.graphics.applyTransform(transform)
    if not (transform and transform._m) then return end
    local m = transform._m
    local sx = math.sqrt(m[1] * m[1] + m[2] * m[2])
    local angle = (sx ~= 0) and atan2(m[2], m[1]) or 0
    local sy = (sx ~= 0) and (m[1] * m[5] - m[2] * m[4]) / sx or m[5]
    love.graphics.translate(m[7], m[8])
    if angle ~= 0 then love.graphics.rotate(angle) end
    love.graphics.scale(sx, sy)
    local kx = (sx ~= 0) and (m[1] * m[4] + m[2] * m[5]) / (sx * sx) or 0
    if kx ~= 0 then love.graphics.shear(kx, 0) end
end

function love.graphics.replaceTransform(transform)
    love.graphics.origin()
    love.graphics.applyTransform(transform)
end

function love.graphics.transformPoint(x, y)
    return stack:mapPoint(x, y)
end

function love.graphics.inverseTransformPoint(x, y)
    stack:updateTransform()
    local t = stack.transform
    local a, b, c, d = t._scaleX, t._shearB, t._shearC, t._scaleY
    local det = a * d - b * c
    if det == 0 then return x, y end
    x, y = x - t._offsetX, y - t._offsetY
    return (d * x - b * y) / det, (a * y - c * x) / det
end

function love.graphics.setScissor(x, y, w, h)
    local top = stack:top()
    if top then
        top._usingScissor = (x ~= nil)
        top._scissorX, top._scissorY = x, y
        top._scissorWidth, top._scissorHeight = w, h
        stack:invalidate()
    end
    applyScissor()
end

function love.graphics.getScissor()
    stack:updateTransform()
    local t = stack.transform
    if not t._usingScissor then return nil end
    return t._scissorX, t._scissorY, t._scissorWidth, t._scissorHeight
end

-- Shrinks the active scissor to its overlap with the given rectangle; with
-- none active this is setScissor. Disjoint rectangles leave an empty one.
function love.graphics.intersectScissor(x, y, w, h)
    local cx, cy, cw, ch = love.graphics.getScissor()
    if not cx then return love.graphics.setScissor(x, y, w, h) end
    local x1, y1 = math.max(x, cx), math.max(y, cy)
    local x2 = math.min(x + w, cx + cw)
    local y2 = math.min(y + h, cy + ch)
    love.graphics.setScissor(x1, y1, math.max(0, x2 - x1), math.max(0, y2 - y1))
end

-- True when the [x,y,w,h] screen-space box lies entirely outside the active
-- scissor and the draw can be skipped. No scissor set means never reject.
function gfx.scissorRejects(x, y, w, h)
    stack:updateTransform()
    local t = stack.transform
    if not t._usingScissor then return false end
    local sx, sy = t._scissorX, t._scissorY
    local sw, sh = t._scissorWidth, t._scissorHeight
    return (x + w) <= sx or x >= (sx + sw)
        or (y + h) <= sy or y >= (sy + sh)
end
