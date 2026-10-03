local mask = {"up", "down", "left", "right", "cross", "circle", "square", "triangle", "r", "l", "start", "select", "home", "volup", "voldown"}
local homeHeldtime = 0
local homeCallbackThreshold = 0.04 --Next to 3 frames
local homeCallbackCancel = 1
local homeTime = 545

dofile(lv1lua.dataloc.."LOVE-WrapLua/"..lv1lua.mode.."/callbacks.lua")

--Live area will be handled manually

local buttonMap = {
    circle   = lv1lua.keyset[1],
    cross    = lv1lua.keyset[2],
    triangle = lv1lua.keyset[3],
    square   = lv1lua.keyset[4],
    l        = lv1lua.keyset[5],
    r        = lv1lua.keyset[6],
    select   = "back",
}

function lv1lua.draw()
    -- LOVE's own loop clears before every draw; without this a game that does
    -- not clear itself smears on OneLua while looking right on the other
    -- backends, which do clear.
    screen.clear(lv1lua.current.bgcolor)
    if love.draw then love.draw() end
    screen.flip()
end

local keys = lv1lua.core.newKeyTracker()

function lv1lua.update()
    -- The native timer counts milliseconds since the last reset; the shared
    -- accumulator (core/timestep.lua) turns that into fixed update slices and
    -- keeps the remainder, so a frame shorter than one slice is carried over
    -- instead of discarded. lv1lua.dt is set there.
    local ms = lv1lua.timer:time()
    lv1lua.timer:reset()
    lv1lua.timer:start()
    lv1lua.core.step(ms / 1000)
end

function lv1lua.updatecontrols()
    -- buttons.homepopup(0)
    buttons.read()

    -- Update joystick analog axes (-1..1)
    local js = lv1lua.joystickState
    js.axes[1] = ((buttons.analoglx or 128) - 128) / 128
    js.axes[2] = ((buttons.analogly or 128) - 128) / 128
    js.axes[3] = ((buttons.analogrx or 128) - 128) / 128
    js.axes[4] = ((buttons.analogry or 128) - 128) / 128

    -- Sample every button's held state, then let the tracker work out the
    -- edges. buttons.held is the SDK's "down right now" table. `physical` keeps
    -- the console's own button names, which love.joystick needs because the
    -- LOVE key names change with the configured layout.
    local held, physical = {}, {}
    for i = 1, #mask do
        local btn  = mask[i]
        local down = buttons.held[btn] and true or false
        held[buttonMap[btn] or btn] = down
        physical[btn] = down
    end
    -- Key repeat is a wall-clock effect, so it follows the real frame time
    -- rather than the fixed update slice.
    keys:update(held, lv1lua.frameDelta or 0)
    lv1lua.core.syncJoystick(physical)

    lv1lua.checkGameRestart()
    if not lv1lua.isPSP and love.touch.__getFrontTouches then
        lv1lua.updateFrontTouch()
        -- lv1lua.checkHomePress()
    end
end

function lv1lua.checkGameRestart()
    if buttons.held.start and buttons.held.l and buttons.held.r
       and buttons.held.down then
        os.restart()
    end
end

--WIP
function lv1lua.checkHomePress()
    --When all analogs are 0 and not flicking, it means that home is pressed
    if(buttons.analoglx == 0 and buttons.analogly == 0 and buttons.analogrx == 0 and buttons.analogry == 0) then
        homeHeldtime = homeHeldtime + (lv1lua.dt or 0)
    else
        if(homeHeldtime>= homeCallbackThreshold and homeHeldtime < homeCallbackCancel) then
            lv1lua.goLiveArea()
        end
        lv1lua.resumeFromLiveArea()
    end
end

function lv1lua.goLiveArea()
    lv1lua.onLiveArea()
    os.golivearea()
    os.delay(homeTime)
end

function lv1lua.resumeFromLiveArea()
    if(homeHeldtime>= homeCallbackThreshold and homeHeldtime < homeCallbackCancel) then
        while(buttons.waitforkey(__HOME)) do
            os.delay(1)
        end
        homeHeldtime = 0
        lv1lua.onResume()
    end
end

function lv1lua.updateFrontTouch()
    local lastMouseDown = love.mouse.isDown()
    touch.read()
    love.touch.__getFrontTouches(touch)
    love.mouse.__updateMouse()

    local newMouseDown = love.mouse.isDown()
    if(not lastMouseDown and newMouseDown) then
        love.mousepressed(love.mouse.getX(), love.mouse.getY(), 1)
    end
end
