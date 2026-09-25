-- PSP graphics: the native font hooks core/font.lua drives.
--
-- Custom faces are not loadable on PSP (the PGF system font is the only one),
-- so every Font points at that one handle and only the size varies. The default
-- is 15px, the PGF face's natural size.

lv1lua.gfx.fontHooks = {
    defaultSize = 15,
    load        = function() return lv1lua.gfx.defaultFont.font end,
    measure     = function(f, text)
        return screen.textwidth(f.font, text, f.size / lv1lua.gfx.fontUnit)
    end,
}
