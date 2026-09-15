-- PSP graphics: screen info and capabilities.

function love.graphics.getDimensions() return lv1lua.screenWidth, lv1lua.screenHeight end
function love.graphics.getWidth()      return lv1lua.screenWidth end
function love.graphics.getHeight()     return lv1lua.screenHeight end
function love.graphics.isActive()      return true end
function love.graphics.present()       end  -- the main loop flips the screen
function love.graphics.captureScreenshot() end
function love.graphics.getStats()      return {drawcalls=0, texturememory=0} end
function love.graphics.getRendererInfo() return "OneLua PSP","1.0","","" end

function love.graphics.getSystemLimits()
    -- PSP textures must be power-of-two and at most 512x512.
    return { pointsize=1, texturesize=512, multicanvas=1, canvasmsaa=0 }
end

function love.graphics.getSupported()
    return { clampzero=false, lighten=false, multicanvasformats=false,
             glsl3=false, instancing=false }
end
