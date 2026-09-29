-- PS3 graphics: print (FIX_PLAN T6.6).
-- Uses gfx.FontDrawString / gfx.FontSetColors when tiny3D is available;
-- falls back to the legacy DrawText global for older player builds.
-- Wrapping, alignment, and line spacing are shared (core/text.lua).

function love.graphics.print(text, x, y)
    if not text or text == "" then return end
    local g    = rawget(_G, "gfx")
    local rgba = lv1lua.current.colorRGBA
    local sx   = (x or 0) * lv1lua.gfx.scale
    local sy   = (y or 0) * lv1lua.gfx.scale + lv1lua.gfx.yOffset

    -- Apply the transform stack offset so print follows translate/scale.
    local stack = lv1lua.gfx.transform
    stack:updateTransform()
    local t = stack.transform
    sx = ((x or 0) * t._scaleX + t._offsetX) * lv1lua.gfx.scale
    sy = ((y or 0) * t._scaleY + t._offsetY) * lv1lua.gfx.scale + lv1lua.gfx.yOffset

    if g and g.FontDrawString then
        if g.FontSetColors then
            g.FontSetColors(rgba[1], rgba[2], rgba[3], rgba[4])
        end
        local cur = lv1lua.current.font
        if g.FontSetSize and cur then g.FontSetSize(cur.size or 12) end
        g.FontDrawString(sx, sy, tostring(text))
    else
        DrawText(sx, sy, tostring(text))
    end
end
