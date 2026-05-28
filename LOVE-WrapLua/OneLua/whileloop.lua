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

function lv1lua.update()
    if lv1lua.timer:time() >= 16 then
        dt = lv1lua.timer:time() / 1000
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

    for i = 1, #mask do
        local btn = mask[i]
        local key = buttonMap[btn] or btn
        if buttons[btn] then
            love.keypressed(key)
        end
        if buttons.released[btn] then
            love.keyreleased(key)
        end
    end
    __checkGameRestart()
    if not lv1lua.isPSP then
        ___updateFrontTouch()
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
        homeHeldtime = homeHeldtime + dt
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

function ___updateFrontTouch()
    local lastMouseDown = love.mouse.isDown()
    touch.read()
    love.touch.__getFrontTouches(touch)
    love.mouse.__updateMouse()

    local newMouseDown = love.mouse.isDown()
    if(not lastMouseDown and newMouseDown) then
        love.mousepressed(love.mouse.getX(), love.mouse.getY(), 1)
    end
end
