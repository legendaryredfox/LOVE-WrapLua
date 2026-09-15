-- lpp-vita graphics: screen info and capabilities.

function love.graphics.getDimensions() return lv1lua.screenWidth, lv1lua.screenHeight end
function love.graphics.getWidth()      return lv1lua.screenWidth end
function love.graphics.getHeight()     return lv1lua.screenHeight end
function love.graphics.isActive()      return true end
function love.graphics.present()       end  -- the main loop flips the screen
function love.graphics.captureScreenshot() end
function love.graphics.getStats()      return {drawcalls=0, texturememory=0} end
function love.graphics.getRendererInfo() return "lpp-vita","1.0","","" end
