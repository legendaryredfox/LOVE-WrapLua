function lv1lua.draw()
    Graphics.initBlend()
    Screen.clear()
    Screen.waitVblankStart()
    Graphics.fillRect(0, 960, 0, 544, lv1lua.current.bgcolor)
    if love.draw then
        love.draw()
    end
    Graphics.fillRect(0, 960, 540, 544, Color.new(0,0,0,255))
    Graphics.termBlend()
    Screen.flip()
end

function lv1lua.update()
    if Timer.getTime(lv1lua.timer) >= 16 then
        dt = Timer.getTime(lv1lua.timer) / 1000
        if love.update then
            love.update(dt)
        end
        Timer.reset(lv1lua.timer)
    end
end

function lv1lua.updatecontrols()
    lv1lua.pad = Controls.read()

    -- Update joystick analog axes (-1..1); lpp-vita sticks report 0-255
    local js = lv1lua.joystickState
    js.axes[1] = (Controls.getLeftX(lv1lua.pad)  - 128) / 128
    js.axes[2] = (Controls.getLeftY(lv1lua.pad)  - 128) / 128
    js.axes[3] = (Controls.getRightX(lv1lua.pad) - 128) / 128
    js.axes[4] = (Controls.getRightY(lv1lua.pad) - 128) / 128

    for i = 1, #lv1lua.keyenum do
        if Controls.check(lv1lua.pad, lv1lua.keyenum[i]) then
            if not lv1lua.keymask[i] then
                love.keypressed(lv1lua.keyname[i])
                lv1lua.keymask[i] = true
            end
        else
            if lv1lua.keymask[i] then
                love.keyreleased(lv1lua.keyname[i])
                lv1lua.keymask[i] = false
            end
        end
    end
end
