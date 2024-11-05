--[[----------------------------------------------------------------------------]] --
--[[----------------------------- Global build flags ---------------------------]] --
--[[----------------------------------------------------------------------------]] --
local GET_BUILD_FLAGS = function()
    BUILD_FLAGS = require "debug/buildFlags"
end

local GET_DEMO_FLAGS = function()
    BUILD_FLAGS = require "demo/demoFlags"
end

local CHECK_FORCED_DEMO_BUILD = function()
    local force = require("demo/FORCE_FUSED")
    if force.FORCE_DEMO_FUSED then
        love.filesystem.isFused = function() return true end
    end
end

local GET_BUILD_INFO = function(skipRequire)
    local info = false

    if not skipRequire then
        info = require("BUILD_INFORMATION")
    end
    if info then
        BUILD_FLAGS.BUILD_DATE  = info.BUILD_DATE
        BUILD_FLAGS.REGION_CODE = info.REGION_CODE or "WORLDWIDE"

        if info.USE_PLATFORM and BUILD_FLAGS.RELEASE_BUILD then
            BUILD_FLAGS.USE_PLATFORM = info.USE_PLATFORM
        end
        if info.ENV_MODE then
            BUILD_FLAGS.ENV_MODE = info.ENV_MODE
        end
    else
        BUILD_FLAGS.BUILD_DATE   = "UNSPECIFIED_BUILD"
        BUILD_FLAGS.REGION_CODE  = "WORLDWIDE"
        BUILD_FLAGS.USE_PLATFORM = nil
    end

    if BUILD_FLAGS.REGION_CODE_DEBUG then
        BUILD_FLAGS.REGION_CODE       = BUILD_FLAGS.REGION_CODE_DEBUG
        BUILD_FLAGS.REGION_CODE_DEBUG = nil
    end

    BUILD_FLAGS.BUILD_VER       = BUILD_FLAGS.RELEASE_BUILD and "RELEASE" or "DEBUG"
    BUILD_FLAGS.BUILD_FULL_INFO = "BUILD: " .. BUILD_FLAGS.BUILD_DATE
    if not BUILD_FLAGS.RELEASE_BUILD then
        BUILD_FLAGS.BUILD_FULL_INFO = BUILD_FLAGS.BUILD_FULL_INFO .. " (" .. BUILD_FLAGS.BUILD_VER .. ")"
    end
end

if not pcall(GET_BUILD_FLAGS) then
    if not pcall(CHECK_FORCED_DEMO_BUILD) then
        print("[BUILD] Not forcing demo mode.")
    end

    --local fused = love.filesystem.isFused ( )

    -- if fused and pcall(GET_DEMO_FLAGS) then
    --   -- force demo if demo folder is present
    --   BUILD_FLAGS.DEMO_MODE                 = true
    --   BUILD_FLAGS.WORKING_DIRECTORY         = love.filesystem.getRealDirectory ( "main.lua" )
    --   BUILD_FLAGS.RELEASE_BUILD             = true
    --   BUILD_FLAGS.LOAD_USER_CONTROL_CONFIG  = true
    -- else
    -- local handle = io.popen("ls")
    -- local result = handle:read("*a")
    BUILD_FLAGS = {
        GAME_IS_FUSED            = fused,
        --WORKING_DIRECTORY        = love.filesystem.getWorkingDirectory(), --love.filesystem.getRealDirectory("main.lua"),
        RELEASE_BUILD            = true,
        LOAD_USER_CONTROL_CONFIG = true,
    }
    -- end
end

if not pcall(GET_BUILD_INFO) then
    GET_BUILD_INFO(true)
end

if BUILD_FLAGS.GAME_IS_FUSED then
    BUILD_FLAGS.CLOSE_ON_ERROR = false
end

if BUILD_FLAGS.PROFILER_ENABLED then
    BUILD_FLAGS.INTERNAL_PROFILING = false
end

if BUILD_FLAGS.GAME_IS_FUSED then
    BUILD_FLAGS.DEBUG_KEYS_ENABLED_BY_DEFAULT = false
end

if BUILD_FLAGS.MUSIC_PREVIEW then
    BUILD_FLAGS.DISABLE_MISSION_BEGIN_ANIM = true
end

--[[----------------------------------------------------------------------------]] --
--[[----------------------------- Global settings and constants ----------------]] --
--[[----------------------------------------------------------------------------]] --

-- table to store global setting configs to
GLOBAL_SETTINGS         = {}
DEFAULT_GLOBAL_SETTINGS = {}

collectgarbage("setpause", 105)
collectgarbage("setstepmul", 400)

--[[----------------------------------------------------------------------------]] --
--[[------------------------------ §Platform            ------------------------]] --
--[[----------------------------------------------------------------------------]] --

-- platform specific stuff, populate this table with any such functions
PLATFORM_FUNCTIONS = {}
-- available functions for it:
-- PLATFORM_FUNCTIONS.INIT                           - called once at startup
-- PLATFORM_FUNCTIONS.RUN                            - called once per frame
-- PLATFORM_FUNCTIONS.LOOK_UP_CHALLENGE_UNLOCKS      - unlocks platform specific challenges if player's challenges.sav file has them unlocked
-- PLATFORM_FUNCTIONS.CLEAR_ALL_CHALLENGES_ON_RECORD - clear any platform specific challenges, debug function
-- PLATFORM_FUNCTIONS.UNLOCK_CHALLENGE_ON_PLATFORM   - handle platform specific challenge unlock
-- PLATFORM_FUNCTIONS.QUIT                           - handle any platform-specific cleanup before closing the game
-- PLATFORM_FUNCTIONS.HANDLE_DEFAULT_MAP_LOAD        - return true/false if game should load the latest save file after startup

if BUILD_FLAGS.USE_PLATFORM then
    local info = love.filesystem.getInfo("platform/" .. BUILD_FLAGS.USE_PLATFORM)
    if info then
        local req = "platform." .. BUILD_FLAGS.USE_PLATFORM .. ".init"
        require(req)
    end
end


--[[----------------------------------------------------------------------------]] --
--[[------------------------------ §Version history     ------------------------]] --
--[[----------------------------------------------------------------------------]] --

-- quickly patch in semantic versioning instead of relying on build timestamps
BUILD_FLAGS.BUILD_FULL_INFO = "VERSION: 1.2.0c"
--require("VERSION_INFORMATION")
BUILD_FLAGS.BUILD_DATE      = BUILD_FLAGS.BUILD_FULL_INFO

--[[----------------------------------------------------------------------------]] --
--[[----------------------------- love.conf ------------------------------------]] --
--[[----------------------------------------------------------------------------]] --

function love.conf(t)
    arg               = nil
    t.identity        = "Gravity Circuit" -- The name of the save directory (string)
    t.version         = "11.4"            -- The LÖVE version this game was made for (string)
    t.window          = false             -- Disable window until initial configurations have been loaded
    t.modules.physics = false             -- Disable the physics module; we don't use Box2D around here
    t.appendidentity  = false             -- Look in the source directory before save directory when loading files

    if BUILD_FLAGS.ENABLE_CONSOLE_OUTPUT then
        io.stdout:setvbuf("no") -- Enable live console output from print()-commands
    else
        print = function() end
    end

    print("[" .. t.identity .. "]")
end
