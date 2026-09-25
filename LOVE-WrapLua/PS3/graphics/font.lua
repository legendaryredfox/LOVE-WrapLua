-- PS3 graphics: the font hooks core/font.lua drives.
--
-- The PS3 Lua Player exposes neither a font object nor a text-measuring call,
-- so there is no load or measure hook: core/font.lua falls back to its
-- glyph-count estimate, which counts UTF-8 glyphs rather than bytes so
-- multibyte text is not over-measured by 2-4x. Documented in Implemented.md.

lv1lua.gfx.fontHooks = {
    defaultSize   = 12,
    estimateRatio = 0.6,
}
