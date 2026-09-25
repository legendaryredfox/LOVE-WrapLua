lv1lua.keyenum = {16,64,128,32,8,1,8192,16384,4096,32768,256,512}
lv1lua.keyname = {"up","down","left","right","start","back"}
-- The console's own button names, in the same order as keyenum. love.joystick
-- is mapped from these because keyname changes with lv1luaconf.keyconf.
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

function love.keyboard.isDown(key)
    local idx = keyLookup[key]
    if idx then return lv1lua.keymask[idx] or false end
    return false
end

function love.keyboard.isScancodeDown(sc) return love.keyboard.isDown(sc) end
function love.keyboard.hasTextInput()     return false end
function love.keyboard.getKeyFromScancode(sc)  return sc end
function love.keyboard.getScancodeFromKey(key) return key end

-- The IME is modal and asynchronous: it is still opening on the frame that
-- starts it, so reading its state immediately (as this used to) always found it
-- unfinished and silently dropped whatever the player typed. The frame loop
-- polls lv1lua.pollTextInput instead, and love.textinput fires when the on-screen
-- keyboard closes.
local imeOpen = false

function love.keyboard.showTextInput(tbl)
    if not tbl then return end
    Keyboard.start(tbl["header"] or "", tbl["subheader"] or "")
    imeOpen = true
end

function love.keyboard.pollTextInput()
    if not imeOpen then return end
    if Keyboard.getState() ~= FINISHED then return end

    local text = Keyboard.getInput()
    imeOpen = false
    if Keyboard.clear then Keyboard.clear() end
    if text and text ~= "" and love.textinput then love.textinput(text) end
end

function love.keyboard.isTextInputActive() return imeOpen end

function love.keyboard.setTextInput(tbl)
    love.keyboard.showTextInput(tbl)
end

-- setKeyRepeat / hasKeyRepeat live in core/input.lua, which owns the repeat
-- state the key tracker reads.
