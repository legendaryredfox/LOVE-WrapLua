-- Runtime bootstrap: platform detection, screen size, the love namespace.
--
-- Runs before any backend module, so everything below can assume `lv1lua` and
-- the empty `love.*` tables exist.

lv1lua.isPSP   = os.cfw      -- OneLua sets os.cfw on PSP only
lv1lua.running = true

if not lv1lua.mode then
    lv1lua.dataloc = ""
    lv1lua.mode    = "OneLua"
end

if lv1lua.isPSP then
    lv1lua.screenWidth,  lv1lua.screenHeight = 480, 272
elseif lv1lua.mode == "PS3" then
    lv1lua.screenWidth,  lv1lua.screenHeight = 720, 480
else
    lv1lua.screenWidth,  lv1lua.screenHeight = 960, 544
end

love = {}
love.graphics   = {}
love.timer      = {}
love.audio      = {}
love.event      = {}
love.math       = {}
love.system     = {}
love.filesystem = {}
love.keyboard   = {}
love.window     = {}
love.joystick   = {}
love.data       = {}
love.touch      = {}
love.mouse      = {}

function love.getVersion()
    return 11, 5, 0, "Mysterious Mysteries"
end

-- File existence is the one filesystem call needed before the filesystem
-- module itself is loaded (to look for game/conf.lua).
function lv1lua.exists(file)
    if lv1lua.mode == "OneLua" then
        return files.exists(file)
    elseif lv1lua.mode == "lpp-vita" then
        return System.doesFileExist(file) or System.doesDirExist(file)
    else
        local f = io.open(file, "r")
        if f then f:close(); return true end
    end
end
