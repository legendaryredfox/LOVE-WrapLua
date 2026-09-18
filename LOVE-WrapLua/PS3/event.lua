function love.event.quit(re)
    if love.quit then
        love.quit()
    end
    -- Flush any open save handles before shutdown (T8.3).
    if lv1lua.core and lv1lua.core.closeOpenFiles then lv1lua.core.closeOpenFiles() end
    EndGFX()
    snd.Finalize()
    lv1lua.running = false
end
