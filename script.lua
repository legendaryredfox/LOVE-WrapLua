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

--set up love
love = {}
love.graphics = {}
love.timer = {}
love.audio = {}
love.event = {}
love.math = {}
love.system = {}
love.filesystem = {}
love.keyboard = {}

--for checking conf files
function lv1lua.exists(file)
	local f = io.open(file, "r")
	if f ~= nil then io.close(f) return true else return false end
end

--love conf, custom configs go to game/conf.lua
t = {
	window = {},
	modules = {}
}
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
    --lv1luaconf, custom configs should go to lv1lua.lua
    lv1luaconf = {
        keyconf = "SE",
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
	end
	
	if not lv1lua.confirm then
		lv1lua.keyset = {"b","a","y","x","leftshoulder","rightshoulder"}
	else
		lv1lua.keyset = {"a","b","x","y","leftshoulder","rightshoulder"}
	end
elseif lv1luaconf.keyconf == "PS" then
	lv1lua.keyset = {"circle","cross","triangle","square","l","r"}
end

--modules and stuff
dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/whileloop.lua")

dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/graphics.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/timer.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/audio.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/event.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/keyboard.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/filesystem.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/math.lua")
dofile(lv1lua.dataloc.."LOVE-WrapLua/system.lua")

--return LOVE 0.10.2
function love.getVersion()
	return 0, 10, 2
end

--require replacement?
function require(param)
	if string.sub(param, -4) == ".lua" then
		param = lv1lua.dataloc.."game/"..param
	else
		param = lv1lua.dataloc.."game/"..param..".lua"
	end
	dofile(param)
end

--START!
love.math.setRandomSeed(os.time())
dofile(lv1lua.dataloc.."game/main.lua")
if love.load then
	love.load()
end

--gamepadpressed or keypressed stuff
if not love.keypressed and love.gamepadpressed then
	function love.keypressed(key)
		love.gamepadpressed(joy,button)
	end
elseif not love.keypressed then
	love.keypressed = function() end
end

if not love.keyreleased and love.gamepadreleased then
	function love.keyreleased(key)
		love.gamepadreleased(joy,button)
	end
elseif not love.keyreleased then
	love.keyreleased = function() end
end

--Main loop
while lv1lua.running do
	--Draw
	lv1lua.draw()
	
	--Update
	lv1lua.update()
	
	--Controls
	lv1lua.updatecontrols()
end
