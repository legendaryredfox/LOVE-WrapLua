-- System.exit() unwinds the script with a sentinel error the player catches,
-- so everything that must happen before exit runs first.
function love.event.quit(re)
    -- LOVE cancels the quit when love.quit returns true.
    if love.quit and love.quit() then return end
    if lv1lua.core and lv1lua.core.closeOpenFiles then lv1lua.core.closeOpenFiles() end
    lv1lua.running = false
    Sound.term()
    Graphics.term()
    System.exit()
end
