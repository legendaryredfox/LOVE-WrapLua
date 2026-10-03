function lv1lua.draw()
    local w, h = lv1lua.screenWidth, lv1lua.screenHeight
    Graphics.initBlend()
    Screen.clear()
    Screen.waitVblankStart()
    -- Native order is (x1, x2, y1, y2): both x values before both y values.
    Graphics.fillRect(0, w, 0, h, lv1lua.current.bgcolor)
    if love.draw then
        love.draw()
    end
    -- vita2d leaves the last few scanlines of the framebuffer undefined, which
    -- shows as noise along the bottom edge; paint them out before the flip.
    Graphics.fillRect(0, w, h - 4, h, Color.new(0, 0, 0, 255))
    Graphics.termBlend()
    Screen.flip()
end

local keys = lv1lua.core.newKeyTracker()

function lv1lua.update()
    -- Timer.getTime is milliseconds since the last reset; the shared
    -- accumulator (core/timestep.lua) turns that into fixed update slices and
    -- carries the remainder, so short frames are no longer thrown away.
    -- lv1lua.dt is set there.
    local ms = Timer.getTime(lv1lua.timer)
    Timer.reset(lv1lua.timer)
    lv1lua.core.step(ms / 1000)
end

function lv1lua.updatecontrols()
    lv1lua.pad = Controls.read()

    -- Update joystick analog axes (-1..1); lpp-vita sticks report 0-255
    local js = lv1lua.joystickState
    js.axes[1] = (Controls.getLeftX(lv1lua.pad)  - 128) / 128
    js.axes[2] = (Controls.getLeftY(lv1lua.pad)  - 128) / 128
    js.axes[3] = (Controls.getRightX(lv1lua.pad) - 128) / 128
    js.axes[4] = (Controls.getRightY(lv1lua.pad) - 128) / 128

    -- Sample the pad, then let the shared tracker produce the edges.
    -- lv1lua.keymask stays in step because love.keyboard.isDown reads it.
    -- `physical` carries the console's own button names, which love.joystick
    -- needs because the LOVE key names change with the configured layout.
    local held, physical = {}, {}
    for i = 1, #lv1lua.keyenum do
        local down = Controls.check(lv1lua.pad, lv1lua.keyenum[i]) and true or false
        held[lv1lua.keyname[i]] = down
        physical[lv1lua.padname[i]] = down
        lv1lua.keymask[i] = down
    end
    -- Key repeat is a wall-clock effect, so it follows the real frame time
    -- rather than the fixed update slice.
    keys:update(held, lv1lua.frameDelta or 0)
    lv1lua.core.syncJoystick(physical)

    -- The on-screen keyboard closes on some later frame than the one that
    -- opened it, so its result has to be collected here.
    if love.keyboard.pollTextInput then love.keyboard.pollTextInput() end
end
