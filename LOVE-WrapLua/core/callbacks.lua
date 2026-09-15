-- Callback wiring, run after the game's main.lua has been loaded.
--
-- Console games are usually written against the gamepad callbacks while the
-- wrapper reports button presses as keys, so the two are bridged here. Every
-- remaining callback gets a no-op stub so platform code can call it without
-- nil checks on every frame.

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
