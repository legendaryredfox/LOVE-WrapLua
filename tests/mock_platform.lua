-- Stubs all console-specific globals so modules can be loaded and tested
-- in a standard Lua 5.3+ environment.  Must be dofile'd before the module
-- under test.

-- ── Runtime state ────────────────────────────────────────────────
lv1lua = {
    dataloc      = "",
    mode         = "OneLua",
    isPSP        = false,
    running      = true,
    screenWidth  = 960,
    screenHeight = 544,
    loveconf     = { window = { title = "Test" }, modules = {}, identity = "test" },
    keyset       = { "b", "a", "y", "x", "leftshoulder", "rightshoulder" },
    joystickState = {
        axes    = { 0, 0, 0, 0, 0, 0 },
        buttons = {},
        hats    = { "c" },
    },
}

lv1luaconf = { keyconf = "XB", imgscale = false, resscale = false }

-- ── love namespace ───────────────────────────────────────────────
love = {
    graphics   = {}, timer = {}, audio  = {}, event      = {},
    math       = {}, system= {}, filesystem={}, keyboard  = {},
    window     = {}, joystick={}, data   = {}, touch      = {},
    mouse      = {}, thread= {},
    _console_name = "Vita",
}

-- ── color ────────────────────────────────────────────────────────
color = {
    new = function(r, g, b, a) return { r=r, g=g, b=b, a=a or 255 } end,
    a   = function(c) return c end,
}

-- ── image ────────────────────────────────────────────────────────
image = {
    load      = function(f)   return { _w=64, _h=64, _path=f } end,
    getw      = function(h)   return type(h)=="table" and h._w or 64 end,
    geth      = function(h)   return type(h)=="table" and h._h or 64 end,
    getrealw  = function(h)   return type(h)=="table" and h._w or 64 end,
    getrealh  = function(h)   return type(h)=="table" and h._h or 64 end,
    blit      = function(...) end,
    scale     = function(...) end,
    resize    = function(...) end,
    fliph     = function(...) end,
    flipv     = function(...) end,
    rotate    = function(...) end,
    setfilter = function(...) end,
    copyscale = function(h, w, ht) return { _w=w, _h=ht } end,
    lost      = function(...) end,
}

-- ── screen ───────────────────────────────────────────────────────
screen = {
    print      = function(...) end,
    clear      = function(...) end,
    flip       = function(...) end,
    textwidth  = function(f, t, s) return #t * 8 end,
    textheight = function(f, s)    return s or 12 end,
    frame      = function()        return 0 end,
    fps        = function()        return 60 end,
}

-- ── draw ─────────────────────────────────────────────────────────
draw = {
    fillrect = function(...) end,
    rect     = function(...) end,
    line     = function(...) end,
    circle   = function(...) end,
    pixel    = function(...) end,
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

-- ── timer ────────────────────────────────────────────────────────
timer = {
    new = function()
        local t = { _elapsed = 0 }
        function t:time()  return self._elapsed end
        function t:reset() self._elapsed = 0    end
        function t:start() end
        return t
    end,
}

-- ── buttons ──────────────────────────────────────────────────────
buttons = {
    held = {}, released = {},
    read     = function() end,
    assign   = function() return 1 end,
    analoglx = 128, analogly = 128,
    analogrx = 128, analogry = 128,
}

-- ── os extensions ────────────────────────────────────────────────
os.delay         = function(ms) end
os.ram           = function() return 128 * 1024 * 1024 end
os.totalram      = function() return 512 * 1024 * 1024 end
os.cpu           = function() return 444 end
os.gpuclock      = function() return 166 end
os.crossbarclock = function() return 222 end
os.restart       = function() end
os.cfw           = false
os.language      = function() return "en" end
os.nick          = function() return "Player" end

-- ── mock VFS (used by files API) ─────────────────────────────────
local _vfs = {}
_mockVFS = _vfs

files = {
    exists = function(f)   return _vfs[f] ~= nil end,
    mkdir  = function(f)   _vfs[f] = "" end,
    delete = function(f)   _vfs[f] = nil end,
    list   = function(d)
        local res = {}
        for k in pairs(_vfs) do
            -- direct children only
            if k ~= d and k:sub(1, #d + 1) == d .. "/" then
                local tail = k:sub(#d + 2)
                if not tail:find("/") then res[#res+1] = tail end
            end
        end
        return res
    end,
}

-- ── lv1lua.exists ────────────────────────────────────────────────
function lv1lua.exists(file)
    return files.exists(file)
end

-- ── touch / osk ──────────────────────────────────────────────────
touch = { read = function() end }
osk   = { init = function() return "" end }

-- ── image filter constants ───────────────────────────────────────
__IMG_FILTER_LINEAR = 3
__IMG_FILTER_POINT  = 0
