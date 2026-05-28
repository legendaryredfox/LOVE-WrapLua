buttons      = buttons      or {}
buttons.held = buttons.held or {}

local keysetMap = {
    [lv1lua.keyset[1]] = "circle",
    [lv1lua.keyset[2]] = "cross",
    [lv1lua.keyset[3]] = "triangle",
    [lv1lua.keyset[4]] = "square",
    [lv1lua.keyset[5]] = "l",
    [lv1lua.keyset[6]] = "r",
    ["back"]           = "select",
}

function love.keyboard.isDown(key)
    local btn = keysetMap[key] or key
    return buttons.held[btn] or false
end

function love.keyboard.isScancodeDown(scancode)
    return love.keyboard.isDown(scancode)
end

function love.keyboard.hasKeyRepeat()     return false end
function love.keyboard.setKeyRepeat(b)    end
function love.keyboard.hasTextInput()     return false end

function love.keyboard.getKeyFromScancode(sc)  return sc end
function love.keyboard.getScancodeFromKey(key) return key end

function love.keyboard.showTextInput(tbl)
    if tbl then
        local h1 = (tbl["header"]    or "")
        local h2 = (tbl["subheader"] or "")
        local text = osk.init(h1, h2)
        if text and text ~= "" and love.textinput then love.textinput(text) end
    end
end

function love.keyboard.setTextInput(tbl)
    love.keyboard.showTextInput(tbl)
end
