-- PSP scissor: the applyScissor hook core/transformapi.lua calls.
--
-- The OneLua EBOOT's screen.clip(x, y, w, h) sets the GPU clip rectangle that
-- every later draw honours; screen.clip() with no arguments clears it.
--
-- The rectangle last sent is remembered so an unchanged scissor costs no native
-- call. imagedraw changes the clip behind this module's back and restores it
-- with applyScissor(true), which sends it unconditionally.

local stack = lv1lua.gfx.transform
local sentX, sentY, sentW, sentH, sentActive

function lv1lua.gfx.applyScissor(force)
    stack:updateTransform()
    local t = stack.transform
    if t._usingScissor then
        local x = math.max(0, math.floor(t._scissorX))
        local y = math.max(0, math.floor(t._scissorY))
        local w = math.max(0, math.floor(t._scissorX + t._scissorWidth) - x)
        local h = math.max(0, math.floor(t._scissorY + t._scissorHeight) - y)
        if not force and sentActive == true and x == sentX and y == sentY and w == sentW and h == sentH then return end
        sentActive, sentX, sentY, sentW, sentH = true, x, y, w, h
        screen.clip(x, y, w, h)
    else
        if not force and sentActive == false then return end
        sentActive = false
        screen.clip()
    end
end
