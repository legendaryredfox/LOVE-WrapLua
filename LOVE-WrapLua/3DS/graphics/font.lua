lv1lua.gfx.fontHooks = {
    defaultSize = 12,

    load = function(path)
        if not path then return lv1lua.gfx.defaultFont end
        return Font.load(lv1lua.dataloc .. "game/" .. path)
    end,

    applySize = function(f)
        if f._font then Font.setPixelSizes(f._font, f.size) end
    end,

    measure = function(f, text)
        if not (f._font and Font.getTextWidth) then return nil end
        Font.setPixelSizes(f._font, f.size)
        local w = Font.getTextWidth(f._font, text)
        local cur = lv1lua.current.font
        if cur and cur ~= f and cur._font == f._font then
            Font.setPixelSizes(f._font, cur.size)
        end
        return w
    end,
}
