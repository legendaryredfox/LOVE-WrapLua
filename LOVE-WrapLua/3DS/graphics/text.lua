local function nativeFont()
    local f = lv1lua.current.font
    return type(f) == "table" and f._font or f
end

function love.graphics.print(text, x, y)
    if not text or text == "" then return end
    Font.print(nativeFont(), x or 0, y or 0, text, TOP_SCREEN, lv1lua.current.color)
end
