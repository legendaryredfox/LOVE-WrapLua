-- OneLua graphics: print. Wrapping, alignment and line spacing are shared
-- (core/text.lua).

local stack = lv1lua.gfx.transform

function love.graphics._defaultPrint(text, x, y, fontsize)
    x, y = x or 0, y or 0
    fontsize = fontsize or (lv1lua.current.font.size / lv1lua.gfx.fontUnit)
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        local s = lv1lua.gfx.scale
        x = x * s; y = y * s; fontsize = fontsize * s
    end
    screen.print(lv1lua.current.font.font, x, y, text, fontsize, lv1lua.current.color)
end

function love.graphics.print(text, x, y)
    if not text or text == "" then return end
    stack:updateTransform()
    local t          = stack.transform
    local fontScale  = (t._scaleX + t._scaleY) / 2
    local fontsize   = lv1lua.current.font.size / lv1lua.gfx.fontUnit * fontScale
    local heightOff  = lv1lua.current.font:getHeight() * fontScale
    x = (x or 0) * t._scaleX
    y = (y or 0) * t._scaleY
    -- screen.print anchors on the native baseline; pull it up to LÖVE's top-left.
    y = y - (lv1lua.gfx.fontUnit - heightOff)
    love.graphics._defaultPrint(text, x, y, fontsize)
end
