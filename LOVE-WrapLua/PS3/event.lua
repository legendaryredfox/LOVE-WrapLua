-- Shutdown entry points differ between PS3 Lua Player builds, so a missing
-- one must not turn quitting into an error.
function lv1lua.shutdown()
    if lv1lua.core and lv1lua.core.closeOpenFiles then lv1lua.core.closeOpenFiles() end
    if type(EndGFX) == "function" then EndGFX() end
    if type(snd) == "table" and type(snd.Finalize) == "function" then snd.Finalize() end
    lv1lua.running = false
end

function love.event.quit(re)
    -- LOVE cancels the quit when love.quit returns true.
    if love.quit and love.quit() then return end
    lv1lua.shutdown()
end
