-- lpp-vita graphics: screen info and capabilities.

function love.graphics.getDimensions() return lv1lua.screenWidth, lv1lua.screenHeight end
function love.graphics.getWidth()      return lv1lua.screenWidth end
function love.graphics.getHeight()     return lv1lua.screenHeight end
function love.graphics.isActive()      return true end
function love.graphics.present()       end  -- the main loop flips the screen
-- System.takeScreenshot writes the frame buffer of the next frame, so a request is kept until the frame
-- that follows it has been presented (lv1lua.draw calls gfx.takeScreenshot). Only a file name can be
-- served: there is no ImageData to hand to a callback. The extension picks the format (PNG by default).
local FORMAT = { bmp = 0, png = 1, jpg = 2, jpeg = 2 }

function love.graphics.captureScreenshot(target)
    if type(target) ~= "string" then
        lv1lua.util.warn("love.graphics.captureScreenshot: lpp-vita can write a file but cannot hand over ImageData")
        return
    end
    local ext = target:match("%.(%a+)$")
    lv1lua.gfx.pendingShot = { path = lv1lua.saveloc .. target, format = FORMAT[ext and ext:lower()] or 1 }
end

function lv1lua.gfx.takeScreenshot()
    local shot = lv1lua.gfx.pendingShot
    if not shot then return end
    lv1lua.gfx.pendingShot = nil
    System.takeScreenshot(shot.path, shot.format)
end
function love.graphics.getRendererInfo() return "lpp-vita","1.0","","" end

-- getSystemLimits / getSupported come from the central capability table.
lv1lua.core.installCapabilities("lpp-vita")
