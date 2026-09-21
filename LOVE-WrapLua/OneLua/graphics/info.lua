-- OneLua graphics: screen info, capabilities, and the debug overlay.

function love.graphics.getDimensions()
    return lv1lua.screenWidth, lv1lua.screenHeight
end

function love.graphics.getWidth()  return lv1lua.screenWidth  end
function love.graphics.getHeight() return lv1lua.screenHeight end

function love.graphics.getStats()
    return { drawcalls=0, canvasswitches=0, texturememory=0, images=0,
             canvases=0, fonts=0, shaderswitches=0, drawcallsbatched=0 }
end

function love.graphics.isActive()       return true  end
function love.graphics.isGammaCorrect() return false end

function love.graphics.getRendererInfo()
    return "OneLua","1.0","",""
end

-- getSystemLimits / getSupported come from the central capability table.
lv1lua.core.installCapabilities("OneLua")

function love.graphics.captureScreenshot(callback_or_filename)
    -- Not available on this platform.
end

function love.graphics.present() end  -- the main loop flips the screen

-- ── Debug overlay (internal utility, not part of the LÖVE API) ───
function lv1lua.displaySystemInfo()
    local currRam  = math.floor((os.ram()      / 1000000) * 100) / 100
    local totalRam = math.floor((os.totalram() / 1000000) * 100) / 100
    currRam = totalRam - currRam
    local fnt      = lv1lua.current.font.font
    local dbgColor = color.new(0, 255, 0, 255)
    local sz       = 12 / lv1lua.gfx.fontUnit
    screen.print(fnt, 10, 10, "FPS: "..screen.frame().."/"..screen.fps(), sz, dbgColor)
    screen.print(fnt, 10, 30, "RAM: "..currRam.."/"..totalRam.."MB",       sz, dbgColor)
    screen.print(fnt, 10, 50, "CPU: "..os.cpu().."/444Mhz",                sz, dbgColor)
    screen.print(fnt, 10, 70, "GPU: "..os.gpuclock().."/166Mhz",           sz, dbgColor)
    screen.print(fnt, 10, 90, "GPU CROSS: "..os.crossbarclock().."/222Mhz",sz, dbgColor)
end
