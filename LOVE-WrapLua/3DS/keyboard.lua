-- 3DS button bitmasks (CTR HID scan codes).
-- KEY_A=1, KEY_B=2, KEY_SELECT=4, KEY_START=8
-- KEY_DRIGHT=16, KEY_DLEFT=32, KEY_DUP=64, KEY_DDOWN=128
-- KEY_R=256, KEY_L=512, KEY_X=1024, KEY_Y=2048

lv1lua.keyenum = {64, 128, 32, 16, 8, 4, 2, 1, 2048, 1024, 512, 256}
lv1lua.keyname = {"up","down","left","right","start","back"}
lv1lua.padname = {"up","down","left","right","start","select",
                  "b","a","y","x","l","r"}
lv1lua.keymask = {}

for i = 1, #lv1lua.keyset do
    lv1lua.keyname[#lv1lua.keyname + 1] = lv1lua.keyset[i]
end

local keyLookup = {}
for i, name in ipairs(lv1lua.keyname) do
    keyLookup[name] = i
end

function love.keyboard.isDown(key)
    local idx = keyLookup[key]
    if idx then return lv1lua.keymask[idx] or false end
    return false
end

function love.keyboard.isScancodeDown(sc) return love.keyboard.isDown(sc) end
function love.keyboard.hasTextInput()     return false end
function love.keyboard.getKeyFromScancode(sc)  return sc end
function love.keyboard.getScancodeFromKey(key) return key end
function love.keyboard.showTextInput(tbl) end
function love.keyboard.setTextInput(tbl)  end
