-- lpp-3ds graphics: platform constants, the GPU frame, and the native hooks
-- core/state.lua drives.
--
-- Graphics.* is sf2d underneath: every GPU draw has to sit between
-- Graphics.initBlend(screen) and Graphics.termBlend(), or the binding raises.
-- Text is different: Font.print writes the CPU framebuffer, and the frame's
-- GPU transfer at termBlend would paint over anything printed before it. So a
-- frame is begin (refresh + initBlend) ... GPU draws ... end (termBlend, then
-- the text queued during the frame).

Graphics.init()

lv1lua.gfx = {
    defaultFont = Font.load(lv1lua.dataloc .. "LOVE-WrapLua/Vera.ttf"),
    lineWidth   = 1,
    inFrame     = false,

    -- Color.new returns the packed integer every Graphics/Font call expects.
    -- No clearScreen hook: the frame paints the background itself.
    nativeColor = function(r, g, b, a) return Color.new(r, g, b, a) end,
}
Font.setPixelSizes(lv1lua.gfx.defaultFont, 12)

lv1lua.current = {
    font        = nil,
    color       = Color.new(255, 255, 255, 255),
    colorRGBA   = {1, 1, 1, 1},
    bgcolor     = Color.new(0, 0, 0, 255),
    bgColorRGBA = {0, 0, 0, 1},
    canvas      = nil,
}

local gfx = lv1lua.gfx

function gfx.beginFrame()
    Screen.refresh()
    Graphics.initBlend(TOP_SCREEN)
    gfx.inFrame = true
    if gfx.applyScissor then gfx.applyScissor() end
end

function gfx.endFrame()
    Graphics.termBlend()
    gfx.inFrame = false
    if gfx.flushText then gfx.flushText() end
end

-- A GPU call outside a frame raises on the console (love.load drawing, or a
-- Canvas:renderTo run from love.update). Such a draw cannot reach the screen
-- anyway, so it is dropped with a one-time warning instead of crashing.
function gfx.canDraw()
    if gfx.inFrame then return true end
    lv1lua.util.warn("draw call outside love.draw ignored: lpp-3ds can only draw inside a GPU frame")
    return false
end
