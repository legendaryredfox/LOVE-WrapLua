-- Half-texel inset for quad sub-rects (FIX_PLAN T8.2).
--
-- Under linear filtering the GPU samples halfway into neighbouring texels at a
-- frame boundary, so tightly-packed spritesheet frames bleed a row/column of the
-- next frame at their edges (PPSSPP #14977 is the same failure mode). Shrinking
-- the source rect by half a texel keeps every sample inside the intended frame.
--
-- Off by default: LÖVE does not inset, and pixel-art sheets usually want nearest
-- filtering instead. Games with linear-filtered, edge-to-edge sheets opt in with
-- love.graphics.setTextureInset(0.5). The value is in source texels and is
-- applied by each backend's quad draw path via lv1lua.core.insetQuad.

lv1lua.core = lv1lua.core or {}
lv1lua.gfx  = lv1lua.gfx or {}
lv1lua.gfx.texelInset = lv1lua.gfx.texelInset or 0

function love.graphics.setTextureInset(px)
    lv1lua.gfx.texelInset = px or 0
end

function love.graphics.getTextureInset()
    return lv1lua.gfx.texelInset or 0
end

-- Shrinks a source rect symmetrically by the active inset. Clamped so a tiny
-- frame never inverts (width/height stay >= 1).
function lv1lua.core.insetQuad(x, y, w, h)
    local px = lv1lua.gfx.texelInset or 0
    if px == 0 then return x, y, w, h end
    local ix = math.min(px, (w - 1) / 2)
    local iy = math.min(px, (h - 1) / 2)
    if ix < 0 then ix = 0 end
    if iy < 0 then iy = 0 end
    return x + ix, y + iy, w - 2 * ix, h - 2 * iy
end
