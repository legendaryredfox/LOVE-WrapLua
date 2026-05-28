loadstring = load
dt = 0.0167
sys.UtilRegisterCallback()

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

function lv1lua.update() --this isn't really dt stuff, but ok heh
    if love.update then love.update(dt) end

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

    for i = 1, #buttonDefs do
        local def = buttonDefs[i]
        if pad[def.fn](0) > 0 and lv1lua.key[def.id] == 0 then
            love.keypressed(def.key)
            lv1lua.key[def.id] = 1
        elseif pad[def.fn](0) == 0 and lv1lua.key[def.id] == 1 then
            love.keyreleased(def.key)
            lv1lua.key[def.id] = 0
        end
    end

    --force quit
    if pad.L3(0) > 0 and pad.R3(0) > 0 then
        love.event.quit()
    end
end
