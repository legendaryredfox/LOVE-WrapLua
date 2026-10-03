-- lpp-3ds (Rinnegatamante/lpp-3ds) native API mock. Load after mock_common.lua.
--
-- Grounded against the player's own bindings (source/luaGraphics.cpp,
-- luaScreen.cpp, luaControls.cpp, luaSound.cpp, luaTimer.cpp, luaSystem.cpp,
-- luaPlayer.cpp) and sf2dlib, which Graphics.* wraps. Where the real binding
-- raises, this mock raises too, so a wrapper mistake fails in tests instead of
-- on a console:
--
--   Graphics.* GPU draws only work between Graphics.initBlend(screen) and
--     Graphics.termBlend(); outside that they raise "you need to call
--     initBlend to use GPU rendering".
--   Graphics.fillRect / fillEmptyRect / drawLine take (x1, x2, y1, y2, color),
--     the same order as lpp-vita, and no screen argument (initBlend picked it).
--   Graphics.drawCircle(x, y, radius, color) is the filled circle; radius is
--     read as an integer.
--   Graphics.drawImage(x, y, tex [, color]) and drawScaleImage(x, y, tex, sx,
--     sy [, color]) take the top-left corner.
--   Graphics.drawImageExtended(x, y, st_x, st_y, w, h, rad, sx, sy, tex
--     [, color]) takes the texture TENTH and places the scaled sub-rect by its
--     CENTRE, rotating around it (sf2d_draw_texture_part_rotate_scale).
--     st_x / st_y are integers.
--   Color.new(r, g, b [, a]) returns an integer (a<<24 | r<<16 | g<<8 | b), and
--     every colour argument is read with luaL_checkinteger.
--   Font.print(font, x, y, text, color, screen) draws into the CPU framebuffer:
--     x / y are integers and it raises for x < 0, y < 0, or past the screen
--     (x > 400 or y > 227 on the top screen). Called during a GPU frame its
--     pixels are overwritten by the frame's transfer at termBlend, so the mock
--     raises there as well.
--   Font.measureText(font, text) -> width, height. There is no getTextWidth.
--   Sound has openWav / openOgg / openAiff(path [, streamed]), play(h, loop),
--     pause, resume, close, isPlaying, getTime, getTotalTime. No stop, no
--     volume, no seek, no pitch.
--   Controls.read() -> held bitmask; Controls.check(pad, KEY_*);
--     Controls.readCirclePad() -> dx, dy.
--   Timer.getTime(t) -> integer milliseconds. There is no Timer.delay.
--   System.doesFileExist works for files only (it opens the path). There is no
--     doesDirExist. System.exit() unwinds with a fake error.
--   The player rebinds io.open / io.read / io.write / io.close / io.size to the
--     handle-based System.openFile / readFile / writeFile / closeFile /
--     getFileSize. io.open is rebound here the same way (io.write is left alone
--     because the test runner prints with it).

lv1lua.mode = "3DS"
lv1lua.screenWidth, lv1lua.screenHeight = 400, 240

TOP_SCREEN    = 0
BOTTOM_SCREEN = 1
LEFT_EYE      = 0
RIGHT_EYE     = 1

FREAD, FWRITE, FCREATE = 0, 1, 2

KEY_A, KEY_B, KEY_SELECT, KEY_START = 1, 2, 4, 8
KEY_DRIGHT, KEY_DLEFT, KEY_DUP, KEY_DDOWN = 16, 32, 64, 128
KEY_R, KEY_L, KEY_X, KEY_Y = 256, 512, 1024, 2048
KEY_ZL, KEY_ZR, KEY_TOUCH = 16384, 32768, 1048576

-- Mock-side state the tests inspect.
__3ds = {
    blend     = nil,   -- screen of the open GPU frame, or nil
    frames    = 0,     -- completed initBlend/termBlend pairs
    scissor   = nil,   -- last setViewport args
    clock     = 0,     -- milliseconds, advanced by tests
    circle    = { 0, 0 },
    down      = {},    -- KEY_* value -> true
    sounds    = {},
    exitError = "lpp_exit_0456432",
    textures  = {},
    nextTexture = 4096,
}

local function checkInt(fname, argn, v) __checkInteger(fname, argn, v) end

local function needBlend(fname)
    if __3ds.blend == nil then
        error(fname .. ": you need to call initBlend to use GPU rendering", 3)
    end
end

local function texture(fname, tex)
    local t = type(tex) == "number" and __3ds.textures[tex]
    if not t then error(fname .. ": attempt to access wrong memory block type", 3) end
    return t
end

local function checkColor(fname, argn, c)
    checkInt(fname, argn, c)
end

-- ── Color ────────────────────────────────────────────────────────
local function channel(c, div) return math.floor(c / div) % 256 end
Color = {
    new = function(r, g, b, a)
        checkInt("Color.new", 1, r); checkInt("Color.new", 2, g); checkInt("Color.new", 3, b)
        a = a or 255
        checkInt("Color.new", 4, a)
        return b + g * 256 + r * 65536 + a * 16777216
    end,
    getR = function(c) return channel(c, 65536) end,
    getG = function(c) return channel(c, 256) end,
    getB = function(c) return channel(c, 1) end,
    getA = function(c) return channel(c, 16777216) end,
}

-- ── Graphics (GPU, sf2d) ─────────────────────────────────────────
Graphics = {
    init = function() __rec.log("Graphics.init") end,
    term = function() __rec.log("Graphics.term") end,

    initBlend = function(screen, side)
        checkInt("Graphics.initBlend", 1, screen)
        if __3ds.blend ~= nil then error("Graphics.initBlend: frame already open", 2) end
        __3ds.blend = screen
        __rec.log("Graphics.initBlend", screen, side)
    end,
    termBlend = function()
        __3ds.blend = nil
        __3ds.frames = __3ds.frames + 1
        __rec.log("Graphics.termBlend")
    end,
    flip = function() __rec.log("Graphics.flip") end,

    -- Textures come back as integers (lua_pushinteger of the gpu_text
    -- pointer), so the wrapper can never tell one from a number by type.
    loadImage = function(path)
        if type(path) ~= "string" then error("Graphics.loadImage: bad path", 2) end
        __3ds.nextTexture = __3ds.nextTexture + 16
        __3ds.textures[__3ds.nextTexture] = { _w = 64, _h = 64, _path = path }
        return __3ds.nextTexture
    end,
    freeImage      = function(tex) texture("Graphics.freeImage", tex); __3ds.textures[tex] = nil end,
    getImageWidth  = function(tex) return texture("Graphics.getImageWidth", tex)._w end,
    getImageHeight = function(tex) return texture("Graphics.getImageHeight", tex)._h end,

    drawImage = function(x, y, tex, c)
        needBlend("Graphics.drawImage")
        texture("Graphics.drawImage", tex)
        if c ~= nil then checkColor("Graphics.drawImage", 4, c) end
        __rec.log("Graphics.drawImage", x, y, tex, c)
    end,
    drawScaleImage = function(x, y, tex, sx, sy, c)
        needBlend("Graphics.drawScaleImage")
        texture("Graphics.drawScaleImage", tex)
        if c ~= nil then checkColor("Graphics.drawScaleImage", 6, c) end
        __rec.log("Graphics.drawScaleImage", x, y, tex, sx, sy, c)
    end,
    drawPartialImage = function(x, y, stx, sty, w, h, tex, c)
        needBlend("Graphics.drawPartialImage")
        texture("Graphics.drawPartialImage", tex)
        checkInt("Graphics.drawPartialImage", 3, stx)
        checkInt("Graphics.drawPartialImage", 4, sty)
        __rec.log("Graphics.drawPartialImage", x, y, stx, sty, w, h, tex, c)
    end,
    drawImageExtended = function(x, y, stx, sty, w, h, rad, sx, sy, tex, c)
        needBlend("Graphics.drawImageExtended")
        checkInt("Graphics.drawImageExtended", 3, stx)
        checkInt("Graphics.drawImageExtended", 4, sty)
        texture("Graphics.drawImageExtended", tex)
        if c ~= nil then checkColor("Graphics.drawImageExtended", 11, c) end
        __rec.log("Graphics.drawImageExtended", x, y, stx, sty, w, h, rad, sx, sy, tex, c)
    end,

    fillRect = function(x1, x2, y1, y2, c, angle)
        needBlend("Graphics.fillRect")
        checkColor("Graphics.fillRect", 5, c)
        __rec.log("Graphics.fillRect", x1, x2, y1, y2, c, angle)
    end,
    fillEmptyRect = function(x1, x2, y1, y2, c)
        needBlend("Graphics.fillEmptyRect")
        checkColor("Graphics.fillEmptyRect", 5, c)
        __rec.log("Graphics.fillEmptyRect", x1, x2, y1, y2, c)
    end,
    drawLine = function(x1, x2, y1, y2, c)
        needBlend("Graphics.drawLine")
        checkColor("Graphics.drawLine", 5, c)
        __rec.log("Graphics.drawLine", x1, x2, y1, y2, c)
    end,
    drawCircle = function(x, y, r, c)
        needBlend("Graphics.drawCircle")
        checkInt("Graphics.drawCircle", 3, r)
        checkColor("Graphics.drawCircle", 4, c)
        __rec.log("Graphics.drawCircle", x, y, r, c)
    end,

    setViewport = function(x, y, w, h, mode)
        for i, v in ipairs({ x, y, w, h, mode }) do checkInt("Graphics.setViewport", i, v) end
        __3ds.scissor = { x, y, w, h, mode }
        __rec.log("Graphics.setViewport", x, y, w, h, mode)
    end,
}

-- ── Screen (CPU framebuffer) ─────────────────────────────────────
Screen = {
    refresh         = function() __rec.log("Screen.refresh") end,
    clear           = function(screen) __rec.log("Screen.clear", screen) end,
    flip            = function() __rec.log("Screen.flip") end,
    waitVblankStart = function() __rec.log("Screen.waitVblankStart") end,
    debugPrint      = function(x, y, text, c, screen) __rec.log("Screen.debugPrint", x, y, text, c, screen) end,
}

-- ── Font (TTF into the CPU framebuffer) ──────────────────────────
Font = {
    load = function(path)
        if type(path) ~= "string" then error("Font.load: bad path", 2) end
        return { _path = path, _px = 16 }
    end,
    unload = function(f) end,
    setPixelSizes = function(f, px)
        checkInt("Font.setPixelSizes", 2, px)
        f._px = px
    end,
    print = function(f, x, y, text, c, screen)
        checkInt("Font.print", 2, x); checkInt("Font.print", 3, y)
        checkColor("Font.print", 5, c)
        checkInt("Font.print", 6, screen)
        if x < 0 or y < 0 then error("Font.print: out of bounds", 2) end
        if (screen == 0 and x > 400) or (screen == 1 and x > 320)
           or (screen <= 1 and y > 227) then
            error("Font.print: out of framebuffer bounds", 2)
        end
        if __3ds.blend ~= nil then
            error("Font.print during a GPU frame is overwritten at termBlend", 2)
        end
        __rec.log("Font.print", f, x, y, text, c, screen)
    end,
    measureText = function(f, text)
        local px = f._px or 16
        return math.floor(__glyphCount(text) * px * 0.5), px
    end,
}

-- ── Sound (DSP) ──────────────────────────────────────────────────
local function openSound(kind)
    return function(path, streamed)
        if type(path) ~= "string" then error("Sound." .. kind .. ": bad path", 2) end
        local h = { _path = path, _kind = kind }
        __3ds.sounds[h] = { playing = false, loop = false, streamed = streamed and true or false, plays = 0 }
        return h
    end
end
local function snd(h)
    local s = __3ds.sounds[h]
    if not s then error("Sound: attempt to access wrong memory block type", 3) end
    return s
end
Sound = {
    init     = function() __rec.log("Sound.init") end,
    term     = function() __rec.log("Sound.term") end,
    openWav  = openSound("openWav"),
    openOgg  = openSound("openOgg"),
    openAiff = openSound("openAiff"),
    play = function(h, loop, interp)
        if loop == nil then error("Sound.play: wrong number of arguments", 2) end
        local s = snd(h)
        s.playing, s.loop, s.plays = true, loop and true or false, s.plays + 1
        __rec.log("Sound.play", h, loop)
    end,
    pause    = function(h) snd(h).playing = false; __rec.log("Sound.pause", h) end,
    resume   = function(h) snd(h).playing = true;  __rec.log("Sound.resume", h) end,
    close    = function(h) snd(h); __3ds.sounds[h] = nil; __rec.log("Sound.close", h) end,
    isPlaying    = function(h) return snd(h).playing end,
    getTime      = function(h) snd(h); return 0 end,
    getTotalTime = function(h) snd(h); return 3 end,
    getSrate     = function(h) snd(h); return 44100 end,
}

-- ── Controls ─────────────────────────────────────────────────────
Controls = {
    read = function()
        local mask = 0
        for key, held in pairs(__3ds.down) do if held then mask = mask + key end end
        return mask
    end,
    check = function(pad, button)
        checkInt("Controls.check", 1, pad); checkInt("Controls.check", 2, button)
        return math.floor(pad / button) % 2 == 1
    end,
    readCirclePad = function() return __3ds.circle[1], __3ds.circle[2] end,
    readTouch     = function() return 0, 0 end,
}

-- ── Timer ────────────────────────────────────────────────────────
Timer = {
    new     = function() return { _start = __3ds.clock } end,
    getTime = function(t) return __3ds.clock - t._start end,
    reset   = function(t) t._start = __3ds.clock end,
    destroy = function(t) end,
}

-- ── System ───────────────────────────────────────────────────────
-- Files live on the real disk (through the io functions captured before the
-- rebinding below), so the filesystem suite can run here as on the other
-- backends; the save and game roots are just directories.
local realOpen = io.__lv1RealOpen or io.open
local handles = {}

System = {
    exit = function()
        lv1lua.running = false
        __rec.log("System.exit")
        error(__3ds.exitError, 0)
    end,
    currentDirectory = function() return "/3ds/LOVE-WrapLua/" end,

    doesFileExist = function(path)
        if _mockVFS[path] ~= nil then return true end
        local f = realOpen(path, "rb")
        if not f then return false end
        -- A directory opens on some hosts but refuses to read; the 3DS
        -- binding opens it as a file and fails.
        local _, err = f:read(1)
        f:close()
        return err == nil
    end,
    -- Entries are { name, size, directory }; a missing directory lists empty,
    -- as FSUSER_OpenDirectory failing does on the console.
    listDirectory = function(path)
        local out = {}
        local p = io.popen('ls -1p "' .. path .. '" 2>/dev/null')
        if not p then return out end
        for line in p:lines() do
            local dir = string.sub(line, -1) == "/"
            out[#out + 1] = { name = dir and string.sub(line, 1, -2) or line,
                              size = 0, directory = dir }
        end
        p:close()
        return out
    end,
    -- Only scratch paths reach the disk: the wrapper's real save root
    -- (/3ds/data/...) must not be created on the machine running the tests.
    createDirectory = function(path)
        __rec.log("System.createDirectory", path)
        if string.sub(path, 1, 5) == "/tmp/" then
            os.execute('mkdir -p "' .. path .. '" 2>/dev/null')
        end
    end,
    deleteFile      = function(path) __rec.log("System.deleteFile", path); os.remove(path); _mockVFS[path] = nil end,
    deleteDirectory = function(path) __rec.log("System.deleteDirectory", path); os.remove(path) end,
    renameFile      = function(a, b) os.rename(a, b) end,

    openFile = function(path, mode)
        checkInt("System.openFile", 2, mode)
        local f
        if mode == FREAD then
            f = realOpen(path, "rb")
        elseif mode == FWRITE then
            f = realOpen(path, "r+b")
        elseif mode == FCREATE then
            -- FS_OPEN_CREATE | FS_OPEN_WRITE: creates, but does not truncate.
            f = realOpen(path, "r+b") or realOpen(path, "w+b")
        end
        if not f then error("System.openFile: file doesn't exist.", 2) end
        local h = { _path = path, _mode = mode }
        handles[h] = f
        return h
    end,
    getFileSize = function(h)
        local f = handles[h]
        local cur = f:seek()
        local size = f:seek("end")
        f:seek("set", cur)
        return size
    end,
    readFile = function(h, offset, size)
        checkInt("System.readFile", 2, offset); checkInt("System.readFile", 3, size)
        local f = handles[h]
        f:seek("set", offset)
        local data = f:read(size) or ""
        -- The binding always returns `size` bytes (lua_pushlstring of the whole
        -- buffer), zero-padded past the end of the file.
        return data .. string.rep("\0", size - #data)
    end,
    writeFile = function(h, offset, data, size)
        checkInt("System.writeFile", 2, offset); checkInt("System.writeFile", 4, size)
        if h._mode == FREAD then error("System.writeFile: file opened for reading", 2) end
        local f = handles[h]
        f:seek("set", offset)
        f:write(string.sub(data, 1, size))
    end,
    closeFile = function(h)
        local f = handles[h]
        if not f then error("System.closeFile: attempt to access wrong memory block type", 2) end
        f:close()
        handles[h] = nil
    end,

    getBatteryLife    = function() return 4 end,
    isBatteryCharging = function() return false end,
    getLanguage       = function() return 1 end,
    getUsername       = function() return "Player" end,
    getModel          = function() return 0 end,
}

-- The player's io patch (luaPlayer.cpp): any io.open(path, "rb") from wrapper
-- code raises on the string mode, as luaL_checkinteger does on the console.
io.__lv1RealOpen = realOpen
io.open = function(path, mode)
    if type(mode) ~= "number" then
        error("bad argument #2 to 'open' (number expected, got " .. type(mode) .. ")", 2)
    end
    return System.openFile(path, mode)
end
