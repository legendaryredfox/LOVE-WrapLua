-- lpp-3ds graphics: the native font hooks core/font.lua drives.
--
-- Font.load prefixes "sdmc:" to any path that is not "romfs:/", so the data
-- prefix has to be an absolute SD path or romfs:/ (index.lua sets it).
-- Font.setPixelSizes takes an integer; Font.measureText returns width, height.

local function px(size) return math.max(1, math.floor(size + 0.5)) end

lv1lua.gfx.fontHooks = {
    defaultSize = 12,

    load = function(path)
        if not path then return lv1lua.gfx.defaultFont end
        return Font.load(lv1lua.dataloc .. "game/" .. path)
    end,

    applySize = function(f)
        if f._font then Font.setPixelSizes(f._font, px(f.size)) end
    end,

    -- Every default-face Font shares one native handle, and the handle carries
    -- the pixel size, so measure at this font's size and hand the handle back
    -- at the size the current font prints with.
    measure = function(f, text)
        if not (f._font and Font.measureText) then return nil end
        Font.setPixelSizes(f._font, px(f.size))
        local w = Font.measureText(f._font, text)
        local cur = lv1lua.current.font
        if cur and cur ~= f and cur._font == f._font then
            Font.setPixelSizes(f._font, px(cur.size))
        end
        return w
    end,
}
