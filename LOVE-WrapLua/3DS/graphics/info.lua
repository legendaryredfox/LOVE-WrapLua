function love.graphics.getDimensions() return lv1lua.screenWidth, lv1lua.screenHeight end
function love.graphics.getWidth()      return lv1lua.screenWidth end
function love.graphics.getHeight()     return lv1lua.screenHeight end
function love.graphics.isActive()      return true end
function love.graphics.present()       end
function love.graphics.captureScreenshot() end
function love.graphics.getRendererInfo() return "lpp-3ds","1.0","","" end

lv1lua.core.installCapabilities("3DS")
