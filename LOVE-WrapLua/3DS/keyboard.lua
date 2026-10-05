-- Button order matches lv1lua.keyname / padname below: d-pad, start, select,
-- then the six face/shoulder buttons in lv1lua.keyset order (circle-position
-- B, cross-position A, Y, X, L, R). The KEY_* globals are libctru's HID bits,
-- registered by the player.
lv1lua.keyenum = {KEY_DUP, KEY_DDOWN, KEY_DLEFT, KEY_DRIGHT, KEY_START, KEY_SELECT,
                  KEY_A, KEY_B, KEY_X, KEY_Y, KEY_L, KEY_R}
lv1lua.keyname = {"up","down","left","right","start","back"}
-- love.joystick maps from PlayStation names (core/input.lua PAD_BUTTON), so
-- each 3DS button takes the name of the PlayStation button in its position.
lv1lua.padname = {"up","down","left","right","start","select",
                  "circle","cross","triangle","square","l","r"}
lv1lua.keymask = {}

for i = 1, #lv1lua.keyset do
    lv1lua.keyname[#lv1lua.keyname + 1] = lv1lua.keyset[i]
end

local keyLookup = {}
for i, name in ipairs(lv1lua.keyname) do
    keyLookup[name] = i
end

local function isDown(key)
    local idx = keyLookup[key]
    return idx ~= nil and lv1lua.keymask[idx] == true
end

function love.keyboard.isDown(...)
    return lv1lua.core.anyDown(isDown, ...)
end

function love.keyboard.isScancodeDown(sc) return love.keyboard.isDown(sc) end
function love.keyboard.hasTextInput()     return false end
function love.keyboard.getKeyFromScancode(sc)  return sc end
function love.keyboard.getScancodeFromKey(key) return key end
function love.keyboard.showTextInput(tbl) end
function love.keyboard.setTextInput(tbl)  end
