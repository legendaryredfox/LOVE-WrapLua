-- Shared graphics state: colour, background colour, clear, line style, blend
-- mode, default filter and the stencil stubs (FIX_PLAN T5.1, second slice).
--
-- All four backends kept a copy of this, differing only in which native call
-- builds a colour and whether clear/filter reach the hardware. Those three
-- differences are hooks the backend sets on lv1lua.gfx *before* loading this
-- file; everything else is identical Lua and lives here once.
--
--   gfx.nativeColor(r,g,b,a)  0-255 components to a native colour handle.
--                             Absent when the backend takes no colour argument
--                             (PS3), in which case colour is only tracked.
--   gfx.clearScreen(native)   Clears the framebuffer. Absent when the frame
--                             loop owns the clear/flip pair (lpp-vita, PS3).
--   gfx.filterValue(name)     Maps a LOVE filter name to the native constant
--                             the backend's draw expects. Absent when the
--                             backend cannot set a filter.
--
-- Colour is stored twice on purpose: `colorRGBA` is LOVE's 0-1 tuple that
-- getColor must return unchanged, and `color` is the native handle the draw
-- calls pass along.

local util = lv1lua.util

lv1lua.gfx.lineWidth = lv1lua.gfx.lineWidth or 1
lv1lua.gfx.filter    = lv1lua.gfx.filter or {}

lv1lua.current.blendMode = lv1lua.current.blendMode or "alpha"

-- ── Colour ───────────────────────────────────────────────────────
local function native(r, g, b, a)
    local toNative = lv1lua.gfx.nativeColor
    if not toNative then return nil end
    return toNative(util.to255(r, g, b, a))
end

function love.graphics.setColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    r, g, b, a = r or 0, g or 0, b or 0, a or 1
    lv1lua.current.colorRGBA = {r, g, b, a}
    lv1lua.current.color = native(r, g, b, a) or lv1lua.current.color
end

function love.graphics.getColor()
    local c = lv1lua.current.colorRGBA
    return c[1], c[2], c[3], c[4]
end

function love.graphics.setBackgroundColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    r, g, b, a = r or 0, g or 0, b or 0, a or 1
    lv1lua.current.bgColorRGBA = {r, g, b, a}
    lv1lua.current.bgcolor = native(r, g, b, a) or lv1lua.current.bgcolor
end

function love.graphics.getBackgroundColor()
    local c = lv1lua.current.bgColorRGBA
    return c[1], c[2], c[3], c[4]
end

-- With no clearScreen hook the frame loop already clears once per frame, so an
-- explicit clear is a no-op rather than a second wipe mid-frame.
function love.graphics.clear(r, g, b, a)
    local clearScreen = lv1lua.gfx.clearScreen
    if not clearScreen then return end
    if r == nil then
        clearScreen(lv1lua.current.bgcolor)
    elseif type(r) == "table" then
        clearScreen(native(r[1] or 0, r[2] or 0, r[3] or 0, r[4] or 1))
    else
        clearScreen(native(r, g or 0, b or 0, a or 1))
    end
end

-- ── Blend mode ───────────────────────────────────────────────────
-- Tracked only: no backend exposes blend state, so the platform default (alpha)
-- is what actually renders. getBlendMode still answers with what the game set,
-- as LOVE does. See getSupported / Implemented.md.
function love.graphics.setBlendMode(mode, alphamode)
    lv1lua.current.blendMode = mode or "alpha"
end

function love.graphics.getBlendMode()
    return lv1lua.current.blendMode, "alphamultiply"
end

-- ── Line width / style ───────────────────────────────────────────
function love.graphics.setLineWidth(w) lv1lua.gfx.lineWidth = w or 1 end
function love.graphics.getLineWidth()  return lv1lua.gfx.lineWidth end
function love.graphics.setLineStyle()  end
function love.graphics.getLineStyle()  return "smooth" end
function love.graphics.setLineJoin()   end
function love.graphics.getLineJoin()   return "miter" end
function love.graphics.setPointSize()  end
function love.graphics.getPointSize()  return 1 end

-- ── Default texture filter ───────────────────────────────────────
-- The names are kept as LOVE strings (that is what getDefaultFilter must
-- return); the native constants the draw path wants live alongside them.
lv1lua.gfx.filter.minName    = lv1lua.gfx.filter.minName or "linear"
lv1lua.gfx.filter.magName    = lv1lua.gfx.filter.magName or "linear"
lv1lua.gfx.filter.anisotropy = lv1lua.gfx.filter.anisotropy or 1

function love.graphics.setDefaultFilter(min, mag, anisotropy)
    local f = lv1lua.gfx.filter
    min = min or "linear"
    mag = mag or min
    f.minName, f.magName = min, mag
    f.anisotropy = anisotropy or 1
    local toNative = lv1lua.gfx.filterValue
    if toNative then
        f.min, f.mag = toNative(min), toNative(mag)
    end
end

function love.graphics.getDefaultFilter()
    local f = lv1lua.gfx.filter
    return f.minName, f.magName, f.anisotropy
end

-- ── Frame statistics (stub on every backend) ─────────────────────
-- None of these SDKs counts draw calls, so the shape is what matters: a game
-- reading `getStats().drawcalls` must find a number on every backend, not a
-- nil on three of them.
function love.graphics.getStats()
    return { drawcalls = 0, canvasswitches = 0, texturememory = 0, images = 0,
             canvases = 0, fonts = 0, shaderswitches = 0, drawcallsbatched = 0 }
end

function love.graphics.isGammaCorrect() return false end

-- ── Stencil (stub on every backend) ──────────────────────────────
function love.graphics.stencil(fn, action, value, keepvalues) if fn then fn() end end
function love.graphics.setStencilTest(compare, value) end
function love.graphics.getStencilTest() return "always", 0 end
