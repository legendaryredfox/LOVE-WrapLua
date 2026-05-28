love.window = {}

function love.window.getDimensions()
    return lv1lua.screenWidth, lv1lua.screenHeight
end

function love.window.getWidth()
    return lv1lua.screenWidth
end

function love.window.getHeight()
    return lv1lua.screenHeight
end

function love.window.getTitle()
    return (lv1lua.loveconf.window and lv1lua.loveconf.window.title) or "LOVE-WrapLua"
end

function love.window.setTitle(title)
    if lv1lua.loveconf.window then
        lv1lua.loveconf.window.title = title
    end
end

function love.window.getMode()
    return lv1lua.screenWidth, lv1lua.screenHeight, {
        fullscreen     = true,
        fullscreentype = "exclusive",
        vsync          = 1,
        msaa           = 0,
        display        = 1,
        highdpi        = false,
        refreshrate    = 60,
        x = 0, y = 0,
    }
end

function love.window.setMode()
    -- window size is fixed on consoles
end

function love.window.getFullscreen()
    return true, "exclusive"
end

function love.window.setFullscreen()
    return true
end

function love.window.hasFocus()      return true  end
function love.window.hasMouseFocus() return false end
function love.window.isVisible()     return true  end
function love.window.isOpen()        return lv1lua.running end
function love.window.maximize()      end
function love.window.minimize()      end
function love.window.restore()       end
function love.window.fromPixels(v)   return v end
function love.window.toPixels(v)     return v end

function love.window.getSafeArea()
    return 0, 0, lv1lua.screenWidth, lv1lua.screenHeight
end

function love.window.getDisplayCount()  return 1 end
function love.window.getDisplayName(n)  return love._console_name end
function love.window.getDPIScale()      return 1 end
function love.window.getPixelDimensions()
    return lv1lua.screenWidth, lv1lua.screenHeight
end

function love.window.showMessageBox(title, message, mtype, attachtowindow)
    return true
end

function love.window.requestAttention(continuous) end
