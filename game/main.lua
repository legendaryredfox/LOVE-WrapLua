--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §LUAJIT -------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

if love.system.getOS( ) == "OS X" then
  print ( "[CONFIGURATION] macOS detected, disabling JIT compilation!" )
  jit.off()
else
  if pcall(require, "jit.opt") then
    require("jit.opt").start(
      "sizemcode=64",
      "maxmcode=131072",--"maxmcode=8192",
      "maxtrace=32768"--maxtrace=8192
    )
  end
end

if BUILD_FLAGS.DISABLE_JIT then
  jit.off()
end

if PLATFORM_FUNCTIONS.INIT then
  PLATFORM_FUNCTIONS.INIT ( )
end

print("[LUAJIT] JIT Enabled: ", not BUILD_FLAGS.DISABLE_JIT )
print("[LUAJIT] FFI Enabled: ", not BUILD_FLAGS.DISABLE_FFI )
print("[manual_gc] Enabled: ",      BUILD_FLAGS.MANUAL_GC   )

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Cheats for naughty people ------------------]]--
--[[----------------------------------------------------------------------------]]--

-- ENV_MODE is (usually) set via BUILD_INFORMATION.lua
if BUILD_FLAGS.DEBUG_BUILD then
  BUILD_FLAGS.ENABLE_MAP_LOAD_WARPS    = true
  BUILD_FLAGS.UNLOCK_ALL_TO_SHOP       = false
  BUILD_FLAGS.UNLOCK_ALL_TO_INVENTORY  = false
  BUILD_FLAGS.ENABLE_HUD_TOGGLE        = true
else
  if BUILD_FLAGS.ENV_MODE ~= "RELEASE" then
    BUILD_FLAGS.ENABLE_MAP_LOAD_WARPS    = true
    BUILD_FLAGS.UNLOCK_ALL_TO_SHOP       = false
    BUILD_FLAGS.UNLOCK_ALL_TO_INVENTORY  = false
    BUILD_FLAGS.ENABLE_HUD_TOGGLE        = true
  else
    -- lets experiment with enabling manual gc for release builds
    BUILD_FLAGS.MANUAL_GC                  = true

    BUILD_FLAGS.ENABLE_MAP_LOAD_WARPS      = false
    BUILD_FLAGS.UNLOCK_ALL_TO_SHOP         = false
    BUILD_FLAGS.UNLOCK_ALL_TO_INVENTORY    = false
    BUILD_FLAGS.ENABLE_HUD_TOGGLE          = false

    -- enable multimonitor support in release builds if we are not on consoles
    if not BUILD_FLAGS.CONSOLE_CONTROLS then
      BUILD_FLAGS.MULTI_MONITOR_SUPPORT    = true
    end
  end
end

-- these should always be toggled like this
BUILD_FLAGS.ENABLE_LANGUAGE_TOGGLE     = true   -- lets user toggle between languages
BUILD_FLAGS.ENABLE_APPDATA_LOC_FILES   = false  -- debug stuff that isn't very useful; should always be turned off

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §DEBUG   ------------------------------------]]--
--[[----------------------------------------------------------------------------]]--

if BUILD_FLAGS.DEBUG_BUILD and love.filesystem.getInfo("debug/debug.lua") then
  local _internalLuaThings = {}
  for k,_ in pairs(_G) do
    _internalLuaThings[k] = true
  end
  
  DEBUG                   = require "debug/debug"
  DEBUG._profiler         = require "debug/jprof/jprof" 
  DEBUG._profiler_2       = require "debug/profiler/profile"
  DEBUG.internalLuaThings = _internalLuaThings
  DEBUG.ENABLED           = function() return true end
end
-- why yes, you will get a gutted debug thing, and you'll love it!
if not DEBUG then
  DEBUG = {
    INIT                          = function ( ) print("[DEBUG] Debug library disabled"); end, 
    ENABLED                       = function ( ) return false end,
    CAN_SAVE_TO_WORKING_DIRECTORY = function ( ) return false end,
    UPDATE                        = function ( ) end,
    FINISH                        = function ( ) end,
    PROF_ENABLE                   = function ( ) end,
    PROF_REGION                   = function ( ) end,
    PROF_SAVE                     = function ( ) end,
    SHENANIGANS                   = function ( ) end,
  }
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Load icon           ------------------------]]--
--[[----------------------------------------------------------------------------]]--

-- reserve the global variable
GLOBAL_LOADER_ICON = false

--[[----------------------------------------------------------------------------]]--
--[[----------------------------- Global helper funcs --------------------------]]--
--[[----------------------------------------------------------------------------]]--

function NoOP() end
function pairprint (t) for k,v in pairs (t) do print (k,v)    end end
function forprint  (t) for i = 1, #t        do print(i, t[i]) end end

local _callstack = debug and debug.traceback or (function() return '[DEBUG DISABLED]' end)
CALLSTACK = BUILD_FLAGS.DEBUG_BUILD and (function (noPrint) 
  local stack = _callstack()
  if debug then
    stack = utf8.sub(stack, 1, utf8.find(stack, "main")-3) .. utf8.sub(stack, utf8.find(stack, "'CALLSTACK'")+11)
  end
  if not noPrint then
    print(stack)
  else
    return stack
  end
end) or NoOP

function isNumber ( n )
  return n and type(n) == "number"
end

function isTable ( t )
  return t and type(t) == "table"
end

function isFunction ( f )
  return f and type(f) == "function"
end

function isString ( s )
  return s and type(s) == "string"
end

function isBoolean ( b )
  return type(b) == "boolean"
end

function ensureNumber ( val, min, max, default, roundDown )
  if not isNumber(val) then
    return default
  end
  if roundDown then
    val = math.floor ( val )
  end
  if val < min then
    return min
  elseif val > max then
    return max
  end
  return val
end

function ensureBoolean ( val, default )
  if not isBoolean ( val ) then
    return default
  end
  return val
end

function createEnumTable ( ... )
  local enums = {...}
  local t = {}
  for i, key in ipairs ( enums ) do
    t[key] = i
  end
  return t
end

local memoizedColorVectors = {}
function createColorVector ( c1, c2, c3, c4, c5, c6 )
  for i = 1, #memoizedColorVectors do
    local vec = memoizedColorVectors[i]
    if vec[1].val == c1
      and vec[2].val == c2
      and vec[3].val == c3
      and vec[4].val == c4
      and vec[5].val == c5
      and vec[6].val == c6
      then
        return vec
      end
  end
  local newVec = {
    {c1[1],c1[2],c1[3],1,val=c1}, 
    {c2[1],c2[2],c2[3],1,val=c2}, 
    {c3[1],c3[2],c3[3],1,val=c3}, 
    {c4[1],c4[2],c4[3],1,val=c4}, 
    {c5[1],c5[2],c5[3],1,val=c5}, 
    {c6[1],c6[2],c6[3],1,val=c6}, 
  }

  memoizedColorVectors[#memoizedColorVectors+1] = newVec
  newVec.isColorVector = true
  return newVec
end

function createVariantedPaletteTable ( ... )
  local t = {...}
  for i = 1, #t, 2 do
    t[ t[i] ] = t[i+1]
  end
  t.DEFAULT = t[2]
  t.isVariantedPaletteTable = true
  return t
end

-- Like assert() but with support for a function argument
function xassert(a, ...)
  if a then return a, ... end
  local f = ...
  if type(f) == ___f then
    local args = {...}
    table.remove(args, 1)
    error(f(unpack(args)), 2)
  else
    error(f or "assertion failed!", 2)
  end
end

function sassert(a, ...)
  if a then return end
  error(string.concat(...), 2)
end

function string.concat(...)
  return table.concat({...})
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §table.clear from luajit if available -------]]--
--[[----------------------------------------------------------------------------]]--

cleanTable    = nil
oldCleanTable = function (t)
  for k, _ in pairs(t) do
    t[k] = nil
  end
end
do 
  local ok, clear = pcall(require, 'table.clear')
  if not ok then
    cleanTable = oldCleanTable
  else
    cleanTable = clear
    print ( "[LUAJIT] Using table.clear from luajit" )
  end
  clearTable = cleanTable
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §File handling       ------------------------]]--
--[[----------------------------------------------------------------------------]]--

local filef = require ( "fileFunctions" )

--[[----------------------------------------------------------------------------]]--
--[[---------------------------- Class registering -----------------------------]]--
--[[----------------------------------------------------------------------------]]--

local _classCache = {}
__State = nil
__Class = nil
function register ( name, state )
  if _classCache[name] then
    error ( "[Register] Duplicate class identification: " .. tostring(name) )
  end
  if state and __State then 
    _classCache[name] = __Class ( name ):include ( __State ) 
  else
    _classCache[name] = __Class ( name )
  end
  return _classCache[name]
end

--[[----------------------------------------------------------------------------]]--
--[[-----------------------------  §Window   -----------------------------------]]--
--[[----------------------------------------------------------------------------]]--

local tick = require ( "window" )

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ §Quitting game, oh no! ----------------------]]--
--[[----------------------------------------------------------------------------]]--

local function quit( )
  -- peacefully wait for threads to resolve
  -- so comfy

  -------------------------
  -- manager threads.... --
  -------------------------
  Audio:quit       ( )
  Texture:quit     ( )
  Map:quit         ( )

  -----------------------
  -- save any debug... --
  -----------------------
  DEBUG.PROF_SAVE  ( )

  ---------------------------
  -- close file threads... --
  ---------------------------
  filef.quit ( )

  -------------------------
  -- platform specifics? --
  -------------------------
  if PLATFORM_FUNCTIONS and PLATFORM_FUNCTIONS.QUIT then
    PLATFORM_FUNCTIONS.QUIT ( )
  end

  ----------------
  -- freedom!!  --
  ----------------
  love.event.quit  ( )
end

local quitNextTick = false
local function checkQuit ()
  if quitNextTick then return true end
  if not BUILD_FLAGS.DEBUG_BUILD then return false end
  if not (SaveQueueLength () > 0) and UI.kb.isComboDown ("ctrl", "q") then return true end
end

function QUIT_GAME ()
  quitNextTick = true
end

function love.setUpdateTimestep(ts)
  love.updateTimestep = ts
end

if BUILD_FLAGS.CLOSE_ON_ERROR then
  local function error_printer(msg, layer)
    print((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
  end

  function love.errorhandler (msg)
    msg = tostring(msg)
    error_printer(msg, 2)
  end
else
  if not BUILD_FLAGS.CONSOLE_CONTROLS then
    require ( "lua/misc/errorhandler" )
  end
end

--[[----------------------------------------------------------------------------]]--
--[[----------------------------- Initialization -------------------------------]]--
--[[----------------------------------------------------------------------------]]--

local __init,
      __loadStaticCode,
      __gameLoop,
      __initGame,
      __update,
      __draw,
      __initialAssetLoad,
      __windowIcon,
      __finalize

__finalize = function (loop, init)
  __gameLoop    = loop
  __initGame    = init
  love.update   = __loadStaticCode
end

__init = function ( playerSettings, conf, file )
  if playerSettings then
    if conf and isTable(conf) then
      print ("[MAIN] Loaded player's settings.")
      DEFAULT_GLOBAL_SETTINGS.PLAYER = conf
    else
      print("[MAIN] Failed to load player settings.")
    end
    loadAsync ( "lua/defaultSettings.lua", __init, false  )
    return
  end
  DEFAULT_GLOBAL_SETTINGS.DEFAULT = conf

  if DEFAULT_GLOBAL_SETTINGS.PLAYER then
    if DEFAULT_GLOBAL_SETTINGS.PLAYER.EFFECT_TIMERS == nil then
      DEFAULT_GLOBAL_SETTINGS.PLAYER.EFFECT_TIMERS = true
    end
    if DEFAULT_GLOBAL_SETTINGS.PLAYER.SPEEDRUN_MODE_DEFAULT == nil then
      DEFAULT_GLOBAL_SETTINGS.PLAYER.SPEEDRUN_MODE_DEFAULT = 2
    end
    if DEFAULT_GLOBAL_SETTINGS.PLAYER.AIMING_ARROW == nil then
      DEFAULT_GLOBAL_SETTINGS.PLAYER.AIMING_ARROW      = false
      DEFAULT_GLOBAL_SETTINGS.PLAYER.AIMING_ARROW_VERT = false
      DEFAULT_GLOBAL_SETTINGS.PLAYER.AIMING_ARROW_FULL = false
    end
  end

  local settingsToUse = DEFAULT_GLOBAL_SETTINGS.PLAYER or DEFAULT_GLOBAL_SETTINGS.DEFAULT 
  for k,v in pairs ( settingsToUse ) do
    GLOBAL_SETTINGS[k] = v
  end

  for k,v in pairs ( DEFAULT_GLOBAL_SETTINGS.DEFAULT ) do
    if GLOBAL_SETTINGS[k] == nil then
      if isTable ( v ) then
        GLOBAL_SETTINGS[k] = {}
        for k2,v2 in pairs ( v ) do
          GLOBAL_SETTINGS[k][k2] = v2
        end
      else
        GLOBAL_SETTINGS[k] = v
      end
    end
  end

  -------------------------------------------------------
  -- we seriously don't want players messing with this --
  -------------------------------------------------------
  -- it might be cool to support random res here,      --
  -- but... please don't. for my sake                  --
  -------------------------------------------------------
  GAME_WIDTH  = 400 --GLOBAL_SETTINGS.GAME_WIDTH
  GAME_HEIGHT = 240 --GLOBAL_SETTINGS.GAME_HEIGHT
  if DEFAULT_GLOBAL_SETTINGS.PLAYER  then
    DEFAULT_GLOBAL_SETTINGS.PLAYER.GAME_WIDTH   = GAME_WIDTH
    DEFAULT_GLOBAL_SETTINGS.PLAYER.GAME_HEIGHT  = GAME_HEIGHT
  end

  -- enforce some settings if console is enabled
  if BUILD_FLAGS.CONSOLE_CONTROLS then
    BUILD_FLAGS.MULTI_MONITOR_SUPPORT = false
  end

  ----------------------------------------------------
  -- check the maximum window resolutions available --
  ----------------------------------------------------
  checkMaximumWindowedSize ( )

  -----------------
  -- open window --
  -----------------
  love.window.setTitle                   ( "Gravity Circuit"          ) 
  -- do not set the application icon if on OSX
  if not BUILD_FLAGS.CONSOLE_CONTROLS then
    if love.system.getOS( ) ~= "OS X" then
      __windowIcon = love.image.newImageData ( "content/gfx/ICO/icon.png" )
      love.window.setIcon   ( __windowIcon )
    end
  end

  updateWindowMode ( )
  if BUILD_FLAGS.CONSOLE_LOAD_ICON then
    require ( "lua/loadIcon" )
  end

  if BUILD_FLAGS.MULTI_MONITOR_SUPPORT then
    local c = love.window.getDisplayCount()
    BUILD_FLAGS.MULTI_MONITOR_SUPPORT = c > 1
  end

  -- reset this setting on boot if main menu has the toggle, as opposed to pause menu
  if BUILD_FLAGS.SPEEDRUN_TIMER_TOGGLE_IN_MENU then
    GLOBAL_SETTINGS.SPEEDRUN_TIMER_SETTING = 1
  end

  GLOBAL_SETTINGS.FIXED_FRAMERATE         = 2--ensureNumber  ( GLOBAL_SETTINGS.FIXED_FRAMERATE,         1, 4, 4, true )
  GLOBAL_SETTINGS.SPEEDRUN_TIMER_SETTING  = ensureNumber  ( GLOBAL_SETTINGS.SPEEDRUN_TIMER_SETTING,  1, 4, 1, true )
  GLOBAL_SETTINGS.SPEEDRUN_MODE_DEFAULT   = ensureNumber  ( GLOBAL_SETTINGS.SPEEDRUN_MODE_DEFAULT,   1, 2, 2, true )
  GLOBAL_SETTINGS.SHOW_BURST_CHARGES      = ensureNumber  ( GLOBAL_SETTINGS.SHOW_BURST_CHARGES,      1, 4, 1, true )
  GLOBAL_SETTINGS.CHALLENGE_NOTIFICATIONS = ensureBoolean ( GLOBAL_SETTINGS.CHALLENGE_NOTIFICATIONS, true )
  
  SetGameFramerate ( GLOBAL_SETTINGS.FIXED_FRAMERATE )

  load ( "lua/loader" ) ( __finalize )
end

function SetGameFramerate ( setting )
  setting = 2
  tick.framerate = 60
  --[[
  if setting == 1 then
    tick.framerate = 30
  elseif setting == 2 then
    tick.framerate = 60
  elseif setting == 3 then
    tick.framerate = 120
  else
    tick.framerate = -1
  end]]
end

--[[----------------------------------------------------------------------------]]--
--[[----------------------------- love.load func -------------------------------]]--
--[[----------------------------------------------------------------------------]]--

function love.load()

  -- Set seeds for built-in RNGs
  math.randomseed         ( os.time ( ) )
  love.math.setRandomSeed ( os.time ( ) )

  -- Set game's framerate
  tick.framerate = 60 -- -1

  -- Set game's save directory root
  love.filesystem.setIdentity(love.filesystem.getIdentity(),false)
  print ( "[Save directory set to: " .. love.filesystem.getSaveDirectory() .. "]")
  local a,b,c = love.getVersion() 
  local str   = a.."."..b.."."..c
  print ( "[LÖVE] ", str )
  -- Create user config directories
  local s3 = love.filesystem.createDirectory( "profile" )
  if not s3 then
    print ( "[.load] Could not create save folder for user!")
  end
  local s0 = love.filesystem.createDirectory( "userconfig" )
  if not s0 then
    print ("[.load] Could not create config folder for user" )
  end

  -- Create user save directories for maps
  -- if applicable to current release, anyway
  if not BUILD_FLAGS.CONSOLE_CONTROLS then
    local s1,s2 = love.filesystem.createDirectory( "usergenerated/maps" ), love.filesystem.createDirectory( "usergenerated/tilesets" )
    if not s1 or not s2 then
      print ("[love.load] Could not create either usergenerated/maps or usergenerated/tilesets" )
    end
  end

  loadAsyncWithErrorHandler ( "userconfig/playerSettings.lua", __init, __init, true  ) 
end

--[[----------------------------------------------------------------------------]]--
--[[------------------------------ love.update func ----------------------------]]--
--[[----------------------------------------------------------------------------]]--

function love.update()
  filef.check()
end

--[[----------------------------------------------------------------------------]]--
--[[----------------------------- Startup love.draw ----------------------------]]--
--[[----------------------------------------------------------------------------]]--

local function loaderDraw (val)
  if not BUILD_FLAGS.CONSOLE_CONTROLS then
    -- see gfxManager.lua->GFX.draw for explanation
    love.graphics.print("a")
  end

  local wWdith, wHeight = love.graphics.getWidth(), love.graphics.getHeight()
  love.graphics.setColor      (0,0,0,1)
  love.graphics.setBlendMode  ( "alpha" )
  love.graphics.rectangle     ( "fill", -10, -10, wWdith+20, wHeight+20 )
  if GLOBAL_LOADER_ICON then
    GLOBAL_LOADER_ICON.DRAW_RAW ( )
  end
end

love.draw = loaderDraw

--[[----------------------------------------------------------------------------]]--
--[[----------------------------- Asset loading --------------------------------]]--
--[[----------------------------------------------------------------------------]]--
local waitFrames = 0
__loadStaticCode = function ( dt )
  filef.check ()
  if (LoadQueueLength () > 0) or Audio:isLoading () then 
    waitFrames = waitFrames + 1
    Audio:update (dt)
    if waitFrames >= 100 then
      if BUILD_FLAGS.ENABLE_LOADER_WARNINGS then    
        print("[LOADER] Taking a while for static code, with a queue length of...", #_queue)
      end
    end
    return 
  end

  -- This starts the asset loading for GameObjectManager
  GameObject  = GameObject:new ()
  BaseObject.INIT_BASE_OBJECT  ()
  love.update = __initialAssetLoad 
end

INITIAL_ASSETS_LOADED = false
function __initialAssetLoad ( dt )

  if AnimationLoader:isLoading() or GameObject:isLoading() then
    filef.check             ()
    AnimationLoader :update ()
    Texture         :lateUpdate ()
    return
  end
  if StringHelper:isLoading() then
    return
  end
  if not Particles.preloaded then
    if MapManager.preload then
      MapManager.preload()
    end
    Particles.preload()
    EnvironmentManager.preload()
    for k,v in pairs (UI.objects) do
      if v.preload then
        v.preload()
      end
    end
    return
  end
  if not Challenges.isLoading() then
    return
  end

  UI.createCommons()

  Text                = Text:new()
  Particles           = Particles:new()
  EnvironmentManager  = EnvironmentManager:new()
  BackgroundManager   = BackgroundManager:new()

  GAMEDATA.init()

  __initGame  ()
  GFX:init    ()
  --sGFX:push    (1,loaderDraw,1)
  --GFX:finish  ()
  GFX:setReady()

  -- randomness does not care for your feelings
  RNG:setRandomInput ( )

  love.update = __update
  love.draw   = __draw

  jit.off()
  local t = love.timer.getTime( )
  BUILD_FLAGS.LOAD_ASYNC = true
  tick.enableWarnings    = true

  DataChip.checkStrings ( )

  GameObject:disableDraw ( true )
  -- preallocate money and burst pickups
  for i = 1, 100 do
    GameObject:spawn ( "money_pickup", 0, 0, 1, 0, 0)
    GameObject:spawn ( "burst_energy", 0, 0 )
  end

  if BUILD_FLAGS.CONSOLE_ICON_SET == 2 then
    GLOBAL_SETTINGS.EFFECTS.GIBS_HAVE_PHYSICS = false
    GLOBAL_SETTINGS.EFFECTS.GIBS_SPAWN        = true
  end
  
  print ( "[INITIAL ASSETS LOADED]" )
  INITIAL_ASSETS_LOADED = true
end

--[[----------------------------------------------------------------------------]]--
--[[----------------------------- Main program loop ----------------------------]]--
--[[----------------------------------------------------------------------------]]--

__update = function ( dt )

  -- run platform specific callbacks and functions
  if PLATFORM_FUNCTIONS.RUN then
    PLATFORM_FUNCTIONS.RUN ( )
  end

  -- profiler start
  DEBUG.PROF_ENABLE ( true )
  DEBUG.PROF_REGION ( true, "frame" )
  DEBUG.PROF_REGION ( true, "pre-frame-managers" )

  -- Run any locale changes etc
  StringHelper:update()

  -- Check file loading thread
  filef.check       ()

  -- Check profile timer, if iron circuit mod is on
  UserProfile.timer ()

  -- Check animation loading
  AnimationLoader:update ()

  -- Update Texture state
  Texture:earlyUpdate()

  -- Check bg loading
  BackgroundManager:checkQueue()

  -- Update UI state
  UI.update()

  -- Update GUI state
  GUI.update()

  -- Update text state
  Text:update ( )

  -- Update Audio state
  Audio:update ( dt )

  -- Update shader state
  --Shader:update ( )

  -- Check if we're quitting the game
  local quitting = checkQuit ()

  -- Tick global timer
  TICK_GLOBAL_TIMER ( )

  -- Advance internal RNG
  RNG:tick ( )

  -- debug
  DEBUG.PROF_REGION ( true, "debug-itself" )
  DEBUG.UPDATE(dt)
  DEBUG.PROF_REGION ( false, "debug-itself" )

  -- prof regions for pre-frame
  DEBUG.PROF_REGION ( false, "pre-frame-managers" )
  
  -- Run the game loop
  DEBUG.PROF_REGION ( true,  "gameloop" )
  __gameLoop(dt)
  DEBUG.PROF_REGION ( false, "gameloop" )

  -- prof regions for post-frame
  DEBUG.PROF_REGION ( true, "post-frame-managers" )

  -- debug finish
  DEBUG.FINISH(dt)  

  -- Clean palettes from text buffers
  Text:finish ( )

  -- Finish handling UI state for this update
  UI.finish   ( )
  GUI.finish  ( )

  -- Switch buffers
  GFX:finish  ( )

  -- Update Texture state
  Texture:lateUpdate()

  -- profiler end
  DEBUG.PROF_REGION ( false, "post-frame-managers" )
  DEBUG.PROF_REGION ( false, "frame" )
  DEBUG.PROF_ENABLE ( false )

  if quitting then
    quit()
  end
end

__draw = function ( )
  GFX:draw()
end
