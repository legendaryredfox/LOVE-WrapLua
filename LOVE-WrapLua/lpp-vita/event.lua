function love.event.quit(re)
    -- LOVE cancels the quit when love.quit returns true.
    if love.quit and love.quit() then return end
    -- Flush any open save handles before the process goes away.
    if lv1lua.core and lv1lua.core.closeOpenFiles then lv1lua.core.closeOpenFiles() end

    if re == "restart" then
        System.launchEboot("app0:/eboot.bin")
    else
        lv1lua.running = false
        System.exit()
    end
end
