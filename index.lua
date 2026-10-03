lv1lua = {}
-- lpp-vita and lpp-3ds both boot index.lua; only lpp-3ds registers the
-- TOP_SCREEN / BOTTOM_SCREEN constants.
if TOP_SCREEN ~= nil and BOTTOM_SCREEN ~= nil then
    lv1lua.mode = "3DS"
    -- A CIA carries the game in romfs; a .3dsx runs from its own SD folder,
    -- which currentDirectory returns with the trailing slash.
    if System.doesFileExist("romfs:/script.lua") then
        lv1lua.dataloc = "romfs:/"
    else
        lv1lua.dataloc = System.currentDirectory()
    end
else
    lv1lua.mode = "lpp-vita"
    lv1lua.dataloc = "app0:/"
end
dofile(lv1lua.dataloc.."script.lua")
