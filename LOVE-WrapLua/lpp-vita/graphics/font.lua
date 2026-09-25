-- lpp-vita graphics: the native font hooks core/font.lua drives.

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
        if f._font then Font.setPixelSizes(f._font, f.size) end
    end,

    measure = function(f, text)
        -- Native Font.getTextWidth(font, text) gives the real pixel width, so
        -- multibyte glyphs measure correctly. Without the binding, core/font.lua
        -- falls back to its glyph-count estimate.
        if not (f._font and Font.getTextWidth) then return nil end
        -- Every Font that asked for no specific file shares one native handle,
        -- and the handle carries the pixel size, so measure at this font's size
        -- and hand the handle back at the size the current font prints with.
        Font.setPixelSizes(f._font, f.size)
        local w = Font.getTextWidth(f._font, text)
        local cur = lv1lua.current.font
        if cur and cur ~= f and cur._font == f._font then
            Font.setPixelSizes(f._font, cur.size)
        end
        return w
    end,
}
