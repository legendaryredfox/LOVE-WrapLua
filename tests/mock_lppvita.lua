-- lpp-vita (Rinnegatamante/lpp-vita) native API mock.
-- Load after mock_common.lua.
--
-- IMPORTANT: the argument orders below mirror the *real* native contract in
-- lpp-vita `source/luaGraphics.cpp` so that wrong-order wrapper bugs (#12)
-- surface as test failures rather than silent mis-renders on device:
--
--   Graphics.drawLine(x1, x2, y1, y2, color)          -- NOT (x1,y1,x2,y2)
--   Graphics.fillRect(x1, x2, y1, y2, color)
--   Graphics.fillEmptyRect(x1, x2, y1, y2, color)
--   Graphics.fillCircle(x, y, radius, color)
--   Graphics.drawScaleImage(x, y, tex, sx, sy [, color])
--   Graphics.drawImageExtended(x, y, tex, st_x, st_y, w, h, radius, sx, sy [, color])
--   Font.getTextWidth(font, text)  -> pixel width
--   Font.print(font, x, y, text, color)

lv1lua.mode = "lpp-vita"

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
    initBlend        = function() end,
    termBlend        = function() end,

    drawLine       = function(x1, x2, y1, y2, c) __rec.log("Graphics.drawLine", x1, x2, y1, y2, c) end,
    fillRect       = function(x1, x2, y1, y2, c) __rec.log("Graphics.fillRect", x1, x2, y1, y2, c) end,
    fillEmptyRect  = function(x1, x2, y1, y2, c) __rec.log("Graphics.fillEmptyRect", x1, x2, y1, y2, c) end,
    fillCircle     = function(x, y, r, c)        __rec.log("Graphics.fillCircle", x, y, r, c) end,
    drawScaleImage = function(x, y, tex, sx, sy, c)
        __rec.log("Graphics.drawScaleImage", x, y, tex, sx, sy, c) end,
    drawImageExtended = function(x, y, tex, st_x, st_y, w, h, rad, sx, sy, c)
        __rec.log("Graphics.drawImageExtended", x, y, tex, st_x, st_y, w, h, rad, sx, sy, c) end,
}

-- ── Font ─────────────────────────────────────────────────────────
Font = {
    load          = function(path) return { _path=path, _px=12 } end,
    setPixelSizes = function(f, px) if type(f)=="table" then f._px = px end end,
    print         = function(f, x, y, text, c) __rec.log("Font.print", f, x, y, text, c) end,
    -- Real native call: returns pixel width of `text` in `font`.
    getTextWidth  = function(f, text)
        local px = (type(f)=="table" and f._px) or 12
        return __glyphCount(text) * px * 0.5
    end,
}

-- ── Screen ───────────────────────────────────────────────────────
Screen = {
    clear          = function(...) __rec.log("Screen.clear", ...) end,
    flip           = function(...) end,
    waitVblankStart= function(...) end,
}

-- ── Sound ────────────────────────────────────────────────────────
local _snd = {}
Sound = {
    init      = function() end,
    term      = function() end,
    open      = function(f) local h={_f=f}; _snd[h]={playing=false,vol=32767}; return h end,
    close     = function(h) _snd[h]=nil end,
    play      = function(h, loop) if _snd[h] then _snd[h].playing=true; _snd[h].loop=loop end end,
    pause     = function(h) if _snd[h] then _snd[h].playing=false end end,
    resume    = function(h) if _snd[h] then _snd[h].playing=true end end,
    stop      = function(h) if _snd[h] then _snd[h].playing=false end end,
    isPlaying = function(h) return (_snd[h] and _snd[h].playing) or false end,
    setVolume = function(h, v) if _snd[h] then _snd[h].vol=v end end,
    getVolume = function(h) return _snd[h] and _snd[h].vol or 0 end,
}

-- ── Controls ─────────────────────────────────────────────────────
Controls = {
    -- Tests drive the pad through Controls._down, keyed by the native button
    -- bitmask value (see lv1lua.keyenum).
    _down    = {},
    read     = function() return 0 end,
    check    = function(pad, btn) return Controls._down[btn] == true end,
    getLeftX = function() return 0 end, getLeftY = function() return 0 end,
    getRightX= function() return 0 end, getRightY= function() return 0 end,
}

-- ── Keyboard (IME) ───────────────────────────────────────────────
Keyboard = {
    start    = function(...) end,
    getState = function() return 0 end,
    getInput = function() return "" end,
    clear    = function() end,
}

-- ── Timer ────────────────────────────────────────────────────────
Timer = {
    new     = function() return { _t = 0 } end,
    getTime = function(t) return type(t)=="table" and t._t or 0 end,
    reset   = function(t) if type(t)=="table" then t._t = 0 end end,
    delay   = function(ms) end,
}

-- ── System (filesystem + process) ────────────────────────────────
System = {
    doesFileExist  = function(f) return lv1lua.exists(f) end,
    doesDirExist   = function(f) return files.exists(f) end,
    createDirectory= function(f) files.mkdir(f) end,
    deleteFile     = function(f) files.delete(f); return true end,
    deleteDirectory= function(f) files.delete(f); return true end,
    listDirectory  = function(d)
        local out = {}
        for _, name in ipairs(files.list(d)) do out[#out+1] = { name = name } end
        return out
    end,
    exit           = function() lv1lua.running = false end,
    launchEboot    = function(...) end,
}
