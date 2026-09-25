-- OneLua graphics: the native font hooks core/font.lua drives.

local defaultFontPath = lv1lua.gfx.defaultFontPath

-- OneLua's screen.textheight is broken (it ignores the font); report the
-- requested pixel size instead.
function screen.textheight(font, size) return size end

font.setdefault(font.load(defaultFontPath))

local function resolve(path)
    if not path then return defaultFontPath end
    return lv1lua.dataloc .. "game/" .. path
end

lv1lua.gfx.fontHooks = {
    defaultSize = 12,
    load        = function(path) return font.load(resolve(path)) end,
    -- A second handle used only for measuring, so measuring at one size never
    -- disturbs the handle we print with.
    loadMeasure = function(path) return font.load(resolve(path)) end,
    measure     = function(f, text)
        return screen.textwidth(f._measure, text, f.size / lv1lua.gfx.fontUnit)
    end,
}
