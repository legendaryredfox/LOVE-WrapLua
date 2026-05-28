pad.InitPads(1)
lv1lua.key = {
    up=0, down=0, left=0, right=0,
    cross=0, circle=0, square=0, triangle=0,
    l=0, r=0, select=0, start=0,
}

local keysetReverse = {
    [lv1lua.keyset[1]] = function() return pad.circle(0)   > 0 end,
    [lv1lua.keyset[2]] = function() return pad.cross(0)    > 0 end,
    [lv1lua.keyset[3]] = function() return pad.triangle(0) > 0 end,
    [lv1lua.keyset[4]] = function() return pad.square(0)   > 0 end,
    [lv1lua.keyset[5]] = function() return pad.L1(0)       > 0 end,
    [lv1lua.keyset[6]] = function() return pad.R1(0)       > 0 end,
}

function love.keyboard.isDown(key)
    if key == "up"    then return pad.up(0)    > 0 end
    if key == "down"  then return pad.down(0)  > 0 end
    if key == "left"  then return pad.left(0)  > 0 end
    if key == "right" then return pad.right(0) > 0 end
    if key == "back" or key == "select" then return pad.select(0) > 0 end
    if key == "start" then return pad.start(0) > 0 end
    local fn = keysetReverse[key]
    if fn then return fn() end
    return false
end

function love.keyboard.isScancodeDown(sc) return love.keyboard.isDown(sc) end
function love.keyboard.hasKeyRepeat()     return false end
function love.keyboard.setKeyRepeat(b)    end
function love.keyboard.hasTextInput()     return false end
function love.keyboard.getKeyFromScancode(sc)  return sc end
function love.keyboard.getScancodeFromKey(key) return key end
function love.keyboard.showTextInput(tbl) end
function love.keyboard.setTextInput(tbl)  end
