local gfx = lv1lua.gfx

function lv1lua.draw()
    gfx.beginFrame()
    Graphics.fillRect(0, lv1lua.screenWidth, 0, lv1lua.screenHeight, lv1lua.current.bgcolor)
    if love.draw then
        love.draw()
    end
    gfx.endFrame()
    Screen.flip()
    Screen.waitVblankStart()
end

local keys = lv1lua.core.newKeyTracker()

function lv1lua.update()
    -- Timer.getTime is integer milliseconds since the last reset.
    local ms = Timer.getTime(lv1lua.timer)
    Timer.reset(lv1lua.timer)
    lv1lua.core.step(ms / 1000)
end

-- hidCircleRead reports roughly -156..156 per axis, up and right positive;
-- LOVE's axes are -1..1 with down positive.
local CIRCLE_RANGE = 156

local function axis(v)
    v = v / CIRCLE_RANGE
    if v > 1 then return 1 elseif v < -1 then return -1 end
    return v
end

function lv1lua.updatecontrols()
    lv1lua.pad = Controls.read()

    local cx, cy = Controls.readCirclePad()
    local js = lv1lua.joystickState
    js.axes[1] = axis(cx)
    js.axes[2] = -axis(cy)

    local held, physical = {}, {}
    for i = 1, #lv1lua.keyenum do
        local down = Controls.check(lv1lua.pad, lv1lua.keyenum[i]) and true or false
        held[lv1lua.keyname[i]] = down
        physical[lv1lua.padname[i]] = down
        lv1lua.keymask[i] = down
    end
    keys:update(held, lv1lua.frameDelta or 0)
    lv1lua.core.syncJoystick(physical)
end
