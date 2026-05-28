--setup
if not lv1lua then
    lv1lua = {}
end
lv1lua.isPSP = os.cfw
lv1lua.running = true

if not lv1lua.mode then
    lv1lua.dataloc = ""
    lv1lua.mode = "OneLua"
end

-- Screen dimensions per platform
if lv1lua.isPSP then
    lv1lua.screenWidth  = 480
    lv1lua.screenHeight = 272
elseif lv1lua.mode == "PS3" then
    lv1lua.screenWidth  = 720
    lv1lua.screenHeight = 480
else
    lv1lua.screenWidth  = 960
    lv1lua.screenHeight = 544
end

--set up love
love = {}
love.graphics  = {}
love.timer     = {}
love.audio     = {}
love.event     = {}
love.math      = {}
love.system    = {}
love.filesystem= {}
love.keyboard  = {}
love.window    = {}
love.joystick  = {}
love.data      = {}
love.touch     = {}
love.mouse     = {}

require("LOVE-WrapLua/love-functions/thread")

--for checking conf files
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

--love conf
t = { window = {}, modules = {} }
lv1lua.loveconf = t

if lv1lua.exists(lv1lua.dataloc.."game/conf.lua") then
    dofile(lv1lua.dataloc.."game/conf.lua")
    love.conf(t)
    lv1lua.loveconf = t
    if not lv1lua.loveconf.identity then
        lv1lua.loveconf.identity = "LOVE-WrapLua"
    end
end
t = nil

if not lv1luaconf then
    lv1luaconf = {
        keyconf   = "XB",
        img_scale = false,
        res_scale = false
    }
end

--set key config
if lv1luaconf.keyconf == "SE" then
    lv1lua.confirm = false

    if lv1lua.mode == "lpp-vita" then
        if Controls.getEnterButton() == SCE_CTRL_CIRCLE then lv1lua.confirm = true end
    elseif lv1lua.mode == "OneLua" then
        if buttons.assign() == 0 then lv1lua.confirm = true end
        if not lv1lua.isPSP then
            dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/touch.lua")
            dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/mouse.lua")
        end
    end
    if not lv1lua.confirm then
        lv1luaconf.keyconf = "XB"
    else
        lv1luaconf.keyconf = "XBA"
    end
end

if lv1luaconf.keyconf == "XB" then
    lv1lua.keyset = {"b","a","y","x","leftshoulder","rightshoulder"}
elseif lv1luaconf.keyconf == "XBA" then
    lv1lua.keyset = {"a","b","x","y","leftshoulder","rightshoulder"}
elseif lv1luaconf.keyconf == "PS" then
    lv1lua.keyset = {"circle","cross","triangle","square","l","r"}
end

--modules and stuff
if lv1lua.isPSP then
    dofile(lv1lua.dataloc.."LOVE-WrapLua/OneLua/graphics_psp.lua")
else
    dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/graphics.lua")
end
dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/whileloop.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/timer.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/audio.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/event.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/keyboard.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/filesystem.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/math.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/system.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/window.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/joystick.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/data.lua")

--LOVE 11.5
function love.getVersion()
    return 11, 5, 0, "Mysterious Mysteries"
end

if lv1lua.mode == "OneLua" then
    __oldRequire = require
    function require(param)
        return __oldRequire("game/"..param)
    end
else
    function require(param)
        if string.sub(param, -4) == ".lua" then
            param = lv1lua.dataloc.."game/"..param
        else
            param = lv1lua.dataloc.."game/"..param..".lua"
        end
        return dofile(param)
    end
end

--START!
love.math.setRandomSeed(os.time())
dofile(lv1lua.dataloc.."game/main.lua")
if love.load then
    love.load()
end

-- Gamepad / keyboard callback bridging
-- If the game only implements gamepadpressed, route keypressed there too.
if not love.keypressed and love.gamepadpressed then
    function love.keypressed(key)
        love.gamepadpressed(love.joystick.getJoysticks()[1], key)
    end
elseif not love.keypressed then
    love.keypressed = function() end
end

if not love.keyreleased and love.gamepadreleased then
    function love.keyreleased(key)
        love.gamepadreleased(love.joystick.getJoysticks()[1], key)
    end
elseif not love.keyreleased then
    love.keyreleased = function() end
end

-- Stub rarely-used callbacks so platform code never needs nil-checks
love.mousepressed  = love.mousepressed  or function() end
love.mousereleased = love.mousereleased or function() end
love.mousemoved    = love.mousemoved    or function() end
love.wheelmoved    = love.wheelmoved    or function() end
love.touchpressed  = love.touchpressed  or function() end
love.touchreleased = love.touchreleased or function() end
love.touchmoved    = love.touchmoved    or function() end
love.focus         = love.focus         or function() end
love.visible       = love.visible       or function() end
love.resize        = love.resize        or function() end
love.lowmemory     = love.lowmemory     or function() end
love.textinput     = love.textinput     or function() end
love.threaderror   = love.threaderror   or function() end

--Main loop
while lv1lua.running do
    lv1lua.draw()
    lv1lua.update()
    lv1lua.updatecontrols()
end
