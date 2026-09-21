-- Backend-agnostic mock environment shared by every platform mock.
-- Re-dofile'ing this file resets all state and creates a *fresh* `love`
-- namespace, so a single Lua process can load OneLua, lpp-vita and PS3
-- backends one after another without state bleeding between them.
--
-- The selected backend is read from the global `__MODE` (default "OneLua").
-- Load order:  mock_common.lua  →  mock_<backend>.lua  →  module under test.

local MODE = __MODE or "OneLua"

-- ── native-call recorder ─────────────────────────────────────────
-- Backend mocks log every native draw/primitive call here so tests can
-- assert the *exact* argument order the real console API expects.
__rec = { calls = {} }
function __rec.reset() __rec.calls = {} end
function __rec.log(name, ...)
    __rec.calls[#__rec.calls + 1] = { fn = name, args = { ... }, n = select("#", ...) }
end
function __rec.last(name)
    for i = #__rec.calls, 1, -1 do
        if __rec.calls[i].fn == name then return __rec.calls[i] end
    end
    return nil
end
function __rec.all(name)
    local r = {}
    for _, c in ipairs(__rec.calls) do
        if c.fn == name then r[#r + 1] = c end
    end
    return r
end
function __rec.count(name) return #__rec.all(name) end

-- ── text measuring helper ────────────────────────────────────────
-- Real native text measuring (intraFont on PSP, freetype on Vita) works per
-- glyph, not per byte. The mocks measure the same way so that a wrapper which
-- measures byte counts is visibly wrong for multibyte text.
function __glyphCount(s)
    local n = 0
    for _ in tostring(s):gmatch("[^\128-\191][\128-\191]*") do n = n + 1 end
    return n
end

-- ── Runtime state ────────────────────────────────────────────────
lv1lua = {
    dataloc      = "",
    mode         = MODE,
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

-- Real internal loader (dataloc = "" resolves paths from the repo root), so
-- tests exercise the same lv1lua.load / loadOnce that modules use on-device —
-- e.g. data.lua lazily pulling in vendor/sha2 and vendor/LibDeflate.
dofile("LOVE-WrapLua/core/loader.lua")

-- ── love namespace (fresh each load) ─────────────────────────────
love = {
    graphics   = {}, timer = {}, audio  = {}, event      = {},
    math       = {}, system= {}, filesystem={}, keyboard  = {},
    window     = {}, joystick={}, data   = {}, touch      = {},
    mouse      = {}, thread= {},
    _console_name = "Vita",
}

-- ── generic timer (used by system helpers) ───────────────────────
timer = {
    new = function()
        local t = { _elapsed = 0 }
        function t:time()  return self._elapsed end
        function t:reset() self._elapsed = 0    end
        function t:start() end
        return t
    end,
}

-- ── os extensions (present on every backend) ─────────────────────
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

-- ── mock VFS (used by OneLua `files` + shared helpers) ───────────
local _vfs = {}
_mockVFS = _vfs

files = {
    exists = function(f)   return _vfs[f] ~= nil end,
    mkdir  = function(f)   _vfs[f] = "" end,
    delete = function(f)   _vfs[f] = nil end,
    list   = function(d)
        local res = {}
        for k in pairs(_vfs) do
            if k ~= d and k:sub(1, #d + 1) == d .. "/" then
                local tail = k:sub(#d + 2)
                if not tail:find("/") then res[#res+1] = tail end
            end
        end
        return res
    end,
}

function lv1lua.exists(file)
    return files.exists(file)
end

-- ── input / osk ──────────────────────────────────────────────────
buttons = {
    held = {}, released = {},
    read     = function() end,
    assign   = function() return 1 end,
    analoglx = 128, analogly = 128,
    analogrx = 128, analogry = 128,
}

-- Touch panels. The real API exposes touch.front / touch.back as arrays of
-- {x, y} with a `count` field; tests fill those in to simulate a touch.
touch = {
    read  = function() end,
    front = { count = 0 },
    back  = { count = 0 },
}
osk   = { init = function() return "" end }

-- ── image filter constants ───────────────────────────────────────
__IMG_FILTER_LINEAR = 3
__IMG_FILTER_POINT  = 0
