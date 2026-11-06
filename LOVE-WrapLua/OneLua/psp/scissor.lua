-- PSP scissor: the applyScissor hook core/transformapi.lua calls.
--
-- The OneLua EBOOT's screen.clip(x, y, w, h) sets the GPU clip rectangle that
-- every later draw honours; screen.clip() with no arguments clears it.

local stack = lv1lua.gfx.transform

function lv1lua.gfx.applyScissor()
    stack:updateTransform()
    local t = stack.transform
    if t._usingScissor then
        local x = math.max(0, math.floor(t._scissorX))
        local y = math.max(0, math.floor(t._scissorY))
        screen.clip(x, y,
            math.max(0, math.floor(t._scissorX + t._scissorWidth) - x),
            math.max(0, math.floor(t._scissorY + t._scissorHeight) - y))
    else
        screen.clip()
    end
end
