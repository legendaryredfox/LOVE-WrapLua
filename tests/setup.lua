-- Selects and loads the backend mock for the current `__MODE`
-- (default "OneLua"), on top of the shared common mock.  Re-dofile'ing this
-- resets all mock state, so a single process can exercise every backend.
--
--   __MODE = "lpp-vita"
--   dofile("tests/setup.lua")
--   dofile("LOVE-WrapLua/lpp-vita/graphics.lua")

local MODE = __MODE or "OneLua"
__MODE = MODE

dofile("tests/mock_common.lua")

-- "PSP" is the OneLua SDK again, just on PSP hardware: same native calls, a
-- 480x272 screen and lv1lua.isPSP set, which is what OneLua/graphics_psp.lua
-- keys off.
local backend_file = ({
    ["OneLua"]   = "tests/mock_onelua.lua",
    ["PSP"]      = "tests/mock_onelua.lua",
    ["lpp-vita"] = "tests/mock_lppvita.lua",
    ["PS3"]      = "tests/mock_ps3.lua",
})[MODE]

if not backend_file then
    error("setup.lua: unknown backend __MODE = " .. tostring(MODE))
end

dofile(backend_file)

if MODE == "PSP" then
    lv1lua.mode  = "OneLua"
    lv1lua.isPSP = true
    lv1lua.screenWidth, lv1lua.screenHeight = 480, 272
end
