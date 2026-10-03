-- PS3 graphics: font hooks for core/font.lua.
-- Adds gfx.FontAddTTF for loading TTF faces and gfx.FontSetSize for resizing,
-- so setFont(font, size) actually changes the rendered size. The PS3 player
-- exposes no native text-measurement call, so getWidth still uses the
-- glyph-count estimate from the shared core.

lv1lua.gfx.fontHooks = {
    defaultSize   = 12,
    estimateRatio = 0.6,

    -- Load a TTF face. Returns a handle stored on the Font object.
    -- When path is nil, fall back to the system font that InitFont already
    -- loaded via the legacy path (the player keeps one global TTF handle).
    load = function(path)
        local g = rawget(_G, "gfx")
        if not (g and g.FontAddTTF) then return nil end
        local fullPath = path and (lv1lua.dataloc .. "game/" .. path)
                              or  "/dev_flash/data/font/SCE-PS3-RD-R-LATIN.TTF"
        return g.FontAddTTF(fullPath)
    end,

    -- Push the current size to the native layer before each print.
    applySize = function(font)
        local g = rawget(_G, "gfx")
        if g and g.FontSetSize then
            g.FontSetSize(font.size or 12)
        end
    end,
}
