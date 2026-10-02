-- lpp-3ds (Rinnegatamante/lpp-3ds) native API mock.
-- Load after mock_common.lua.
--
-- Native argument orders:
--   Graphics.fillRect(x, y, w, h, color, screen)    -- LOVE coordinate order
--   Graphics.drawRect(x, y, w, h, color, screen)
--   Graphics.drawLine(x1, y1, x2, y2, color, screen)
--   Graphics.fillCircle(x, y, r, color, screen)
--   Graphics.drawImage(x, y, tex, screen)
--   Graphics.drawImageExtended(x, y, tex, sx, sy, w, h, angle, scaleX, scaleY, screen)
--   Font.print(font, x, y, text, screen, color)
--   Font.getTextWidth(font, text)  -> pixel width
-- TOP_SCREEN = 1, BOTTOM_SCREEN = 0

lv1lua.mode = "3DS"

TOP_SCREEN    = 1
BOTTOM_SCREEN = 0

-- ── Color ────────────────────────────────────────────────────────
Color = {
    new = function(r, g, b, a) return { r=r, g=g, b=b, a=a or 255 } end,
    getR = function(c) return c.r end, getG = function(c) return c.g end,
    getB = function(c) return c.b end, getA = function(c) return c.a end,
}

-- ── Graphics ─────────────────────────────────────────────────────
Graphics = {
    loadImage        = function(path) return { _w=64, _h=64, _path=path } end,
    getImageWidth    = function(tex)  return type(tex)=="table" and tex._w or 64 end,
    getImageHeight   = function(tex)  return type(tex)=="table" and tex._h or 64 end,
    freeImage        = function(...) end,

    fillRect   = function(x, y, w, h, c, screen) __rec.log("Graphics.fillRect",   x, y, w, h, c, screen) end,
    drawRect   = function(x, y, w, h, c, screen) __rec.log("Graphics.drawRect",   x, y, w, h, c, screen) end,
    drawLine   = function(x1, y1, x2, y2, c, screen) __rec.log("Graphics.drawLine", x1, y1, x2, y2, c, screen) end,
    fillCircle = function(x, y, r, c, screen)    __rec.log("Graphics.fillCircle", x, y, r, c, screen) end,
    drawImage  = function(x, y, tex, screen)     __rec.log("Graphics.drawImage",  x, y, tex, screen) end,
    drawImageExtended = function(x, y, tex, sx, sy, w, h, angle, scaleX, scaleY, screen)
        __rec.log("Graphics.drawImageExtended", x, y, tex, sx, sy, w, h, angle, scaleX, scaleY, screen) end,
}

-- ── Font ─────────────────────────────────────────────────────────
Font = {
    load          = function(path) return { _path=path, _px=12 } end,
    setPixelSizes = function(f, px) if type(f)=="table" then f._px = px end end,
    print         = function(f, x, y, text, screen, c) __rec.log("Font.print", f, x, y, text, screen, c) end,
    getTextWidth  = function(f, text)
        local px = (type(f)=="table" and f._px) or 12
        return __glyphCount(text) * px * 0.5
    end,
}

-- ── Screen ───────────────────────────────────────────────────────
Screen = {
    init  = function() end,
    flip  = function() end,
    clear = function(screen) __rec.log("Screen.clear", screen) end,
}

-- ── Sound ────────────────────────────────────────────────────────
local _snd = {}
Sound = {
    init      = function() end,
    open      = function(f) local h={_f=f}; _snd[h]={playing=false,vol=64}; return h end,
    close     = function(h) _snd[h]=nil end,
    play      = function(h) if _snd[h] then _snd[h].playing=true end end,
    stop      = function(h) if _snd[h] then _snd[h].playing=false end end,
    pause     = function(h) if _snd[h] then _snd[h].playing=false end end,
    isPlaying = function(h) return (_snd[h] and _snd[h].playing) or false end,
    setVolume = function(h, v) if _snd[h] then _snd[h].vol=v end end,
    getVolume = function(h) return _snd[h] and _snd[h].vol or 0 end,
}

-- ── Controls ─────────────────────────────────────────────────────
Controls = {
    _down    = {},
    read     = function() return 0 end,
    check    = function(pad, btn) return Controls._down[btn] == true end,
    getCircleX = function() return 0 end,
    getCircleY = function() return 0 end,
}

-- ── Timer ────────────────────────────────────────────────────────
Timer = {
    new     = function() return { _t = 0 } end,
    getTime = function(t) return type(t)=="table" and t._t or 0 end,
    reset   = function(t) if type(t)=="table" then t._t = 0 end end,
    delay   = function(ms) end,
}

-- ── System ───────────────────────────────────────────────────────
System = {
    doesFileExist   = function(f) return files.exists(f) end,
    doesDirExist    = function(f) return files.exists(f) end,
    createDirectory = function(f) files.mkdir(f) end,
    deleteFile      = function(f) files.delete(f); return true end,
    deleteDirectory = function(f) files.delete(f); return true end,
    listDirectory   = function(d)
        local out = {}
        for _, name in ipairs(files.list(d)) do out[#out+1] = { name = name } end
        return out
    end,
    exit = function() lv1lua.running = false end,
}
