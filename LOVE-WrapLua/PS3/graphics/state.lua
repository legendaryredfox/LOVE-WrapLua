-- PS3 graphics: native bring-up and the platform constants core/state.lua
-- drives.
--
-- The PS3 Lua Player exposes BlitToScreen/DrawText and little else, so most of
-- this backend is an honest stub. It is the least-supported tier; see
-- Implemented.md.

-- Bring up the native layer before anything draws.
InitGFX(720, 480)
InitFont("/dev_flash/data/font/SCE-PS3-RD-R-LATIN.TTF", 12)

lv1lua.gfx = {
    -- PS3 output is 720x480 while the game thinks in LÖVE's 1280x720-ish space.
    scale     = 0.5625,
    yOffset   = 37,
    lineWidth = 1,
    -- No native hooks: DrawText/BlitToScreen take no colour argument (so colour
    -- is only tracked), lv1lua.draw owns the frame clear, and there is no
    -- filter call.
}

lv1lua.current = {
    -- Font wrapper object, assigned in graphics/font.lua.
    font        = nil,
    color       = nil,
    colorRGBA   = {1, 1, 1, 1},
    bgcolor     = nil,
    bgColorRGBA = {0, 0, 0, 1},
    canvas      = nil,
}
