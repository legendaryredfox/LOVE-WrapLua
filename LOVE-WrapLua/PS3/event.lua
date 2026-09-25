function love.event.quit(re)
    if love.quit then
        love.quit()
    end
    -- Flush any open save handles before shutdown (T8.3).
    if lv1lua.core and lv1lua.core.closeOpenFiles then lv1lua.core.closeOpenFiles() end
    -- Shutdown entry points differ between PS3 Lua Player builds, so a missing
    -- one must not turn quitting into an error.
    if type(EndGFX) == "function" then EndGFX() end
    if type(snd) == "table" and type(snd.Finalize) == "function" then snd.Finalize() end
    lv1lua.running = false
end
