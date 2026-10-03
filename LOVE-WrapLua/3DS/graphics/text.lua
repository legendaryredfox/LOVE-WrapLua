-- lpp-3ds graphics: print. Wrapping, alignment and line spacing are shared
-- (core/text.lua).
--
-- Font.print(font, x, y, text, color, screen) writes the CPU framebuffer, which
-- the GPU transfer at termBlend overwrites. Inside a frame, lines are queued
-- with the size and colour current at the call and printed by endFrame, so
-- text always lands on top of the frame's sprites and shapes. Outside a frame
-- they print at once.
--
-- The binding raises for integer-less, negative or off-screen coordinates
-- (x > 400 or y > 227 on the top screen), so a line that starts off screen is
-- dropped rather than crashing the game.

local stack = lv1lua.gfx.transform
local gfx   = lv1lua.gfx
local queue = {}

local MAX_X, MAX_Y = 400, 227

local function nativeFont()
    local f = lv1lua.current.font
    if type(f) == "table" then return f._font, f.size end
    return f, nil
end

local function emit(handle, size, x, y, text, color)
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    if x < 0 or y < 0 or x > MAX_X or y > MAX_Y then return end
    if size then Font.setPixelSizes(handle, math.max(1, math.floor(size + 0.5))) end
    Font.print(handle, x, y, text, color, TOP_SCREEN)
end

function gfx.flushText()
    local pending = queue
    queue = {}
    for i = 1, #pending do
        local q = pending[i]
        emit(q[1], q[2], q[3], q[4], q[5], q[6])
    end
    local f = lv1lua.current.font
    if type(f) == "table" and f._font and f.size then
        Font.setPixelSizes(f._font, math.max(1, math.floor(f.size + 0.5)))
    end
end

function love.graphics.print(text, x, y)
    if text == nil then return end
    text = tostring(text)
    if text == "" then return end

    stack:updateTransform()
    local t = stack.transform
    x = (x or 0) * t._scaleX + t._offsetX
    y = (y or 0) * t._scaleY + t._offsetY

    local handle, size = nativeFont()
    local lineHeight = love.graphics.getFont():getHeight()
    local row = 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line ~= "" then
            local ly = y + row * lineHeight
            if gfx.inFrame then
                queue[#queue + 1] = { handle, size, x, ly, line, lv1lua.current.color }
            else
                emit(handle, size, x, ly, line, lv1lua.current.color)
            end
        end
        row = row + 1
    end
end
