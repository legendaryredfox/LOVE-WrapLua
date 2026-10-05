-- 3DS hardware scissor, the applyScissor hook core/transformapi.lua calls.
--
-- Graphics.setViewport is sf2d_set_scissor_test, which maps the rectangle onto
-- the rotated 3DS framebuffer itself. It only holds until the frame ends, so
-- beginFrame re-applies it; draws wholly outside it are also rejected before
-- the call (gfx.scissorRejects).

local stack = lv1lua.gfx.transform

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
