-- lpp-vita graphics: the native font hooks core/font.lua drives.

-- Font.setPixelSizes reads its size with luaL_checkinteger, which raises on a
-- fractional number under Lua 5.3 (a scaled size, or sizeAdjust's 0.825).
function lv1lua.gfx.pixelSize(size)
    return math.max(1, math.floor(size + 0.5))
end
local px = lv1lua.gfx.pixelSize

lv1lua.gfx.fontHooks = {
    defaultSize = 12,

    load = function(path)
        if not path then return lv1lua.gfx.defaultFont end
        return Font.load(lv1lua.dataloc .. "game/" .. path)
    end,

    sizeAdjust = function(size)
        if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
            return size * 0.825
        end
        return size
    end,

    applySize = function(f)
        if f._font then Font.setPixelSizes(f._font, px(f.size)) end
    end,

    measure = function(f, text)
        -- Native Font.getTextWidth(font, text) gives the real pixel width, so
        -- multibyte glyphs measure correctly. Without the binding, core/font.lua
        -- falls back to its glyph-count estimate.
        if not (f._font and Font.getTextWidth) then return nil end
        -- Every Font that asked for no specific file shares one native handle,
        -- and the handle carries the pixel size, so measure at this font's size
        -- and hand the handle back at the size the current font prints with.
        Font.setPixelSizes(f._font, px(f.size))
        local w = Font.getTextWidth(f._font, text)
        local cur = lv1lua.current.font
        if cur and cur ~= f and cur._font == f._font then
            Font.setPixelSizes(f._font, px(cur.size))
        end
        return w
    end,
}
