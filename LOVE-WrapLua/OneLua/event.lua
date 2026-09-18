function love.event.quit(re)
    if love.quit then
        love.quit()
    end
    
    -- Flush any open save handles before the process goes away (T8.3).
    if lv1lua.core and lv1lua.core.closeOpenFiles then lv1lua.core.closeOpenFiles() end

    if re == "restart" then
        os.restart()
    else
        lv1lua.running = false
        os.exit()
    end
end
