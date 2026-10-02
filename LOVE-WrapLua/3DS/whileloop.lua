function lv1lua.draw()
    local w, h = lv1lua.screenWidth, lv1lua.screenHeight
    Screen.clear(TOP_SCREEN)
    Graphics.fillRect(0, 0, w, h, lv1lua.current.bgcolor, TOP_SCREEN)
    if love.draw then
        love.draw()
    end
    Screen.flip()
end

local keys = lv1lua.core.newKeyTracker()

function lv1lua.update()
    local ms = Timer.getTime(lv1lua.timer)
    Timer.reset(lv1lua.timer)
    lv1lua.core.step(ms / 1000)
end

function lv1lua.updatecontrols()
    lv1lua.pad = Controls.read()

    local js = lv1lua.joystickState
    js.axes[1] = Controls.getCircleX() / 154
    js.axes[2] = Controls.getCircleY() / 154

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
