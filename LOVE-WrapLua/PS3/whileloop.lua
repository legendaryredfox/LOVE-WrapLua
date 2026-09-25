loadstring = load  -- PS3's Lua is 5.2+, where loadstring was removed

-- The PS3 Lua Player exposes no timer, so the frame time is assumed rather
-- than measured. Kept on lv1lua instead of as a global `dt`.
lv1lua.dt = 1 / 60

sys.UtilRegisterCallback()

local keys = lv1lua.core.newKeyTracker()

local buttonDefs = {
    {fn = "circle",   key = lv1lua.keyset[1], id = "circle"},
    {fn = "cross",    key = lv1lua.keyset[2], id = "cross"},
    {fn = "triangle", key = lv1lua.keyset[3], id = "triangle"},
    {fn = "square",   key = lv1lua.keyset[4], id = "square"},
    {fn = "L1",       key = lv1lua.keyset[5], id = "l"},
    {fn = "R1",       key = lv1lua.keyset[6], id = "r"},
    {fn = "up",       key = "up",             id = "up"},
    {fn = "down",     key = "down",           id = "down"},
    {fn = "left",     key = "left",           id = "left"},
    {fn = "right",    key = "right",          id = "right"},
    {fn = "select",   key = "back",           id = "select"},
    {fn = "start",    key = "start",          id = "start"},
}

function lv1lua.draw()
    StartGFX()
    if love.draw then love.draw() end
    FlipGFX()
end

function lv1lua.update()
    if love.update then love.update(lv1lua.dt) end

    --Check ingame XMB
    local ret = sys.UtilCheckCallback(g_status)
    if ret == sys.SYSUTIL_EXIT_GAME then
        love.event.quit() --quit game over ingame XMB
    end

    --Play audio
    lv1lua.playsound()
end

function lv1lua.updatecontrols()
    -- Update joystick analog axes (-1..1); PS3 sticks report 0-255
    local js = lv1lua.joystickState
    js.axes[1] = (pad.lx(0)  - 128) / 128
    js.axes[2] = (pad.ly(0)  - 128) / 128
    js.axes[3] = (pad.rx(0)  - 128) / 128
    js.axes[4] = (pad.ry(0)  - 128) / 128

    -- Sample the pad, then let the shared tracker produce the edges.
    -- lv1lua.key stays in step because love.keyboard.isDown reads it, and
    -- `physical` (the console's own button names) drives love.joystick.
    local held, physical = {}, {}
    for i = 1, #buttonDefs do
        local def  = buttonDefs[i]
        local down = pad[def.fn](0) > 0
        held[def.key] = down
        physical[def.id] = down
        lv1lua.key[def.id] = down and 1 or 0
    end
    keys:update(held, lv1lua.dt)
    lv1lua.core.syncJoystick(physical)

    --force quit
    if pad.L3(0) > 0 and pad.R3(0) > 0 then
        love.event.quit()
    end
end
