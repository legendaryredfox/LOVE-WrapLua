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
    if love.draw then love.draw() end
    screen.flip()
end

local keys = lv1lua.core.newKeyTracker()

function lv1lua.update()
    if lv1lua.timer:time() >= 16 then
        -- Kept on lv1lua rather than as a global, so game code cannot collide
        -- with it (and so the helpers below can read it).
        local dt = lv1lua.timer:time() / 1000
        lv1lua.dt = dt
        if love.update then
            love.update(dt)
        end
        lv1lua.timer:reset()
        lv1lua.timer:start()
    end
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
    -- edges. buttons.held is the SDK's "down right now" table.
    local held = {}
    for i = 1, #mask do
        local btn = mask[i]
        held[buttonMap[btn] or btn] = buttons.held[btn] and true or false
    end
    keys:update(held, lv1lua.dt or 0)

    __checkGameRestart()
    if not lv1lua.isPSP then
        lv1lua.updateFrontTouch()
        -- __checkHomePress()
    end
end

function __checkGameRestart()
    if buttons.start and buttons.held.l and buttons.held.r and buttons.held.down
    then
        print("RESTART")
        os.restart()
    end
end

--WIP
function __checkHomePress()
    --When all analogs are 0 and not flicking, it means that home is pressed
    if(buttons.analoglx == 0 and buttons.analogly == 0 and buttons.analogrx == 0 and buttons.analogry == 0) then
        homeHeldtime = homeHeldtime + (lv1lua.dt or 0)
    else
        if(homeHeldtime>= homeCallbackThreshold and homeHeldtime < homeCallbackCancel) then
            __goLiveArea()
        end
        __resume()
    end
end

function __goLiveArea()
    print("Live Area")
    onLiveArea()
    os.golivearea()
    os.delay(homeTime)
end

function __resume()
    if(homeHeldtime>= homeCallbackThreshold and homeHeldtime < homeCallbackCancel) then
        while(buttons.waitforkey(__HOME)) do
            os.delay(1)
        end
        print("Resume")
        homeHeldtime = 0
        onResume()
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
