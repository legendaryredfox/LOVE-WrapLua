-- OneLua (PSP / Vita via OneLua) native API mock.
-- Load after mock_common.lua.  Native names are lowercase (color, image,
-- screen, draw, font, sound) to match the real OneLua Lua bindings.

lv1lua.mode  = "OneLua"

-- ── color ────────────────────────────────────────────────────────
color = {
    new = function(r, g, b, a) return { r=r, g=g, b=b, a=a or 255 } end,
    a   = function(c) return c end,
}

-- ── image ────────────────────────────────────────────────────────
-- Loaded images are treated as immutable sources; scale/resize/rotate are
-- recorded so tests can prove the wrapper never mutates a shared drawable.
image = {
    load      = function(f)   return { _w=64, _h=64, _path=f } end,
    getw      = function(h)   return type(h)=="table" and h._w or 64 end,
    geth      = function(h)   return type(h)=="table" and h._h or 64 end,
    getrealw  = function(h)   return type(h)=="table" and h._w or 64 end,
    getrealh  = function(h)   return type(h)=="table" and h._h or 64 end,
    blit      = function(...) __rec.log("image.blit", ...) end,
    scale     = function(...) __rec.log("image.scale", ...) end,
    resize    = function(h, w, ht) __rec.log("image.resize", h, w, ht)
                    if type(h)=="table" then h._w = w or h._w; h._h = ht or h._h end end,
    fliph     = function(...) __rec.log("image.fliph", ...) end,
    flipv     = function(...) __rec.log("image.flipv", ...) end,
    rotate    = function(...) __rec.log("image.rotate", ...) end,
    setfilter = function(...) end,
    -- Returns a *new* handle: the wrapper is expected to scale into a copy
    -- rather than resize the shared source.
    copyscale = function(h, w, ht)
        __rec.log("image.copyscale", h, w, ht)
        return { _w=w, _h=ht, _path=(type(h)=="table" and h._path) }
    end,
    lost      = function(...) end,
}

-- ── screen ───────────────────────────────────────────────────────
screen = {
    print      = function(...) __rec.log("screen.print", ...) end,
    clear      = function(...) __rec.log("screen.clear", ...) end,
    flip       = function(...) end,
    -- 8px per glyph at scale 1 (intraFont measures glyphs, not bytes).
    textwidth  = function(f, t, s) return __glyphCount(t) * 8 * (s or 1) end,
    textheight = function(f, s)    return s or 12 end,
    frame      = function()        return 0 end,
    fps        = function()        return 60 end,
}

-- ── draw ─────────────────────────────────────────────────────────
draw = {
    fillrect = function(...) __rec.log("draw.fillrect", ...) end,
    rect     = function(...) __rec.log("draw.rect", ...) end,
    line     = function(...) __rec.log("draw.line", ...) end,
    circle   = function(...) __rec.log("draw.circle", ...) end,
    pixel    = function(...) __rec.log("draw.pixel", ...) end,
}

-- ── font ─────────────────────────────────────────────────────────
font = {
    load       = function(f)   return { _path = f } end,
    setdefault = function(...) end,
}

-- ── sound ────────────────────────────────────────────────────────
local _sndState = {}
sound = {
    load    = function(f)
        local h = { _f=f }
        _sndState[h] = { playing=false, looping=false, vol=100 }
        return h
    end,
    play    = function(s)    if _sndState[s] then _sndState[s].playing=true  end end,
    stop    = function(s)    if _sndState[s] then _sndState[s].playing=false end end,
    pause   = function(s, m) if _sndState[s] then _sndState[s].playing=(m==0) end end,
    vol     = function(s, v)
        if not _sndState[s] then return 100 end
        if v then _sndState[s].vol = v end
        return _sndState[s].vol
    end,
    playing = function(s) return (_sndState[s] and _sndState[s].playing) or false end,
    looping = function(s) return (_sndState[s] and _sndState[s].looping) or false end,
    loop    = function(s)
        if _sndState[s] then _sndState[s].looping = not _sndState[s].looping end
    end,
    duration= function()  return 0 end,
    time    = function()  return 0 end,
    seek    = function(...) end,
}
