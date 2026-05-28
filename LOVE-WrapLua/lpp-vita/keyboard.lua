lv1lua.keyenum = {16,64,128,32,8,1,8192,16384,4096,32768,256,512}
lv1lua.keyname = {"up","down","left","right","start","back"}
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
function love.keyboard.hasKeyRepeat()     return false end
function love.keyboard.setKeyRepeat(b)    end
function love.keyboard.hasTextInput()     return false end
function love.keyboard.getKeyFromScancode(sc)  return sc end
function love.keyboard.getScancodeFromKey(key) return key end

function love.keyboard.showTextInput(tbl)
    if tbl then
        local h1 = tbl["header"]    or ""
        local h2 = tbl["subheader"] or ""
        Keyboard.start(h1, h2)
        if Keyboard.getState() == FINISHED then
            local text = Keyboard.getInput()
            if text and text ~= "" and love.textinput then love.textinput(text) end
        end
    end
end

function love.keyboard.setTextInput(tbl)
    love.keyboard.showTextInput(tbl)
end
