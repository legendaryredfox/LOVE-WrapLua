local mask = {"up", "down", "left", "right", "cross", "circle", "square", "triangle", "r", "l", "start", "select", "home", "volup", "voldown"}

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
    end
end

function lv1lua.checkGameRestart()
    if buttons.held.start and buttons.held.l and buttons.held.r
       and buttons.held.down then
        os.restart()
    end
end

-- Touches seen last frame, by id, so press / move / release are edges. The
-- first finger is also the mouse (button 1, istouch true), as on a phone.
local lastTouches = {}

local function emit(name, ...)
    if love[name] then love[name](...) end
end

function lv1lua.updateFrontTouch()
    touch.read()
    love.touch.__getFrontTouches(touch)
    love.mouse.__updateMouse()

    local now = {}
    for id = 1, love.touch._count do
        local t = love.touch._touches[id]
        if t then now[id] = { x = t.x, y = t.y } end
    end

    for id, p in pairs(now) do
        local was = lastTouches[id]
        if not was then
            emit("touchpressed", id, p.x, p.y, 0, 0, 1)
            if id == 1 then emit("mousepressed", p.x, p.y, 1, true, 1) end
        elseif was.x ~= p.x or was.y ~= p.y then
            local dx, dy = p.x - was.x, p.y - was.y
            emit("touchmoved", id, p.x, p.y, dx, dy, 1)
            if id == 1 then emit("mousemoved", p.x, p.y, dx, dy, true) end
        end
    end
    for id, p in pairs(lastTouches) do
        if not now[id] then
            emit("touchreleased", id, p.x, p.y, 0, 0, 1)
            if id == 1 then emit("mousereleased", p.x, p.y, 1, true, 1) end
        end
    end
    lastTouches = now
end
