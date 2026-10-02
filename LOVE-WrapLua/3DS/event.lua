function love.event.quit(re)
    if love.quit then
        love.quit()
    end
    if lv1lua.core and lv1lua.core.closeOpenFiles then lv1lua.core.closeOpenFiles() end
    lv1lua.running = false
    System.exit()
end
