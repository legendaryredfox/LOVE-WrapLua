-- Shared Font objects: one prototype, one cache, four backends (FIX_PLAN T5.1,
-- font slice).
--
-- Each backend used to carry its own newFont/setFont/getFont/setNewFont and its
-- own ad-hoc font table, and they had drifted: only OneLua cached faces, only
-- OneLua answered hasGlyph/getKerning/getDPIScale, setLineHeight was a no-op
-- everywhere, and resizing a font through setFont silently resized the cached
-- object the game still held.
--
-- What is genuinely native is a hook the backend installs on
-- `lv1lua.gfx.fontHooks` before this file loads:
--
--   load(path)          native print handle; `path` nil means the default face.
--                       Absent when the platform has a single system font (PSP)
--                       or exposes no font object at all (PS3).
--   loadMeasure(path)   second handle used only for measuring, so measuring at
--                       one size never disturbs the handle we print with
--                       (OneLua). Defaults to the print handle.
--   measure(font, text) native pixel width; return nil to fall back to the
--                       glyph-count estimate.
--   applySize(font)     push font.size to the native handle (lpp-vita).
--   sizeAdjust(size)    backend size correction (lpp-vita's scaling factor).
--   defaultSize         size of the font that exists before the game calls
--                       setFont (LOVE's is 12; the PSP PGF face is 15).
--   estimateRatio       glyph width as a fraction of the size, for the estimate.

local util  = lv1lua.util
local hooks = lv1lua.gfx.fontHooks or {}
lv1lua.gfx.fontHooks = hooks

local DEFAULT_SIZE   = hooks.defaultSize or 12
local ESTIMATE_RATIO = hooks.estimateRatio or 0.6

-- Loading the same face twice costs both time and scarce memory on a PSP, so
-- faces are cached per name+size. A font whose size is changed afterwards
-- leaves the cache (see setFont), because the next newFont for the old size
-- must not hand back a resized object.
local cache = { instances = {} }
function cache:get(key)    return key and self.instances[key] or nil end
function cache:put(key, f) if key then self.instances[key] = f end end
function cache:forget(key) if key then self.instances[key] = nil end end
function cache:clear()     self.instances = {} end
lv1lua.gfx.fonts = cache

local Font = {}
Font.__index = Font

function Font:getWidth(text)
    if not text or text == "" then return 0 end
    if hooks.measure then
        local w = hooks.measure(self, text)
        if w then return w end
    end
    return util.glyphCount(text) * self.size * ESTIMATE_RATIO
end

function Font:getHeight()      return self.size end
function Font:getBaseline()    return self.size end
function Font:getAscent()      return self.size end
function Font:getDescent()     return 0 end
function Font:getLineHeight()  return self.lineHeight end
function Font:setLineHeight(h) self.lineHeight = h or 1.2 end
function Font:hasGlyph()       return true end
function Font:getKerning()     return 0 end
function Font:setFallbacks()   end
function Font:getDPIScale()    return 1 end
function Font:setFilter()      end
function Font:release()        return false end
function Font:type()           return "Font" end
function Font:typeOf(t)        return t == "Font" or t == "Object" end

function Font:getFilter()
    local f = lv1lua.gfx.filter or {}
    return f.minName or "linear", f.magName or "linear", f.anisotropy or 1
end

-- LOVE's Font:getWrap: the width of the widest resulting line, then the lines.
function Font:getWrap(text, wrapWidth)
    local self_ = self
    local lines = lv1lua.core.wrapText(text, wrapWidth,
                                       function(s) return self_:getWidth(s) end)
    local widest = 0
    for i = 1, #lines do
        local w = self_:getWidth(lines[i])
        if w > widest then widest = w end
    end
    return widest, lines
end

lv1lua.gfx.Font = Font

local function faceKey(name, size)
    return tostring(name or "@default") .. ":" .. tostring(size)
end

function love.graphics.newFont(setfont, setsize)
    -- newFont(), newFont(size) and newFont(nil, size) all mean the default face.
    if not setfont or tonumber(setfont) then
        setsize = tonumber(setfont) or setsize or DEFAULT_SIZE
        setfont = nil
    end
    setsize = tonumber(setsize) or DEFAULT_SIZE

    local key    = faceKey(setfont, setsize)
    local cached = cache:get(key)
    if cached then return cached end

    local handle  = hooks.load and hooks.load(setfont) or nil
    local measure = (hooks.loadMeasure and hooks.loadMeasure(setfont)) or handle

    local f = setmetatable({
        name       = setfont,
        size       = hooks.sizeAdjust and hooks.sizeAdjust(setsize) or setsize,
        lineHeight = 1.2,
        _key       = key,
        -- `font` is the name the OneLua/PSP print path and love.graphics.getInfo
        -- use; `_font` is the name the lpp-vita path uses. Same handle either way.
        font       = handle,
        _font      = handle,
        guineaPig  = measure,
        _measure   = measure,
    }, Font)

    if hooks.applySize then hooks.applySize(f) end
    cache:put(key, f)
    return f
end

function love.graphics.setFont(setfont, setsize)
    if setfont then lv1lua.current.font = setfont end
    local cur = lv1lua.current.font
    if not cur then return end

    if setsize then
        local size = hooks.sizeAdjust and hooks.sizeAdjust(setsize) or setsize
        if size ~= cur.size then
            -- The game holds this object, so it cannot stay in the cache under
            -- its old size once it is resized.
            cache:forget(cur._key)
            cur._key = nil
            cur.size = size
        end
    end
    -- Push the final size to the native handle, so measuring happens at the
    -- size we actually print with.
    if hooks.applySize then hooks.applySize(cur) end
end

function love.graphics.getFont() return lv1lua.current.font end

function love.graphics.setNewFont(setfont, setsize)
    local newfont = love.graphics.newFont(setfont, setsize)
    love.graphics.setFont(newfont, setsize)
    return newfont
end

-- LOVE starts with a usable default font, so print/printf and getFont():getWidth
-- work before the game calls setFont.
lv1lua.current.font = love.graphics.newFont(nil, DEFAULT_SIZE)
