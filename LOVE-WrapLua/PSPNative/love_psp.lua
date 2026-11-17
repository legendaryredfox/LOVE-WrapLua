-- LÖVE 11 backend for the native PSP engine (game-independent).
PSP_THREAD_COS = PSP_THREAD_COS or setmetatable({}, { __mode = "k" })
-- Config: global PSP_CONFIG (set by the host script, or psp_config.lua next to the EBOOT), all optional:
--   identity (save name), title, os (love.system.getOS), font (default TTF path inside game/).
-- Sits on the C module `native` (GPU sprites, polygons, TTF text, pad, fs, zlib).
local N = native
PSP_CONFIG = PSP_CONFIG or (loadfile("psp_config.lua") or function() return {} end)()
local CFG = PSP_CONFIG
-- Garbage collector: the PSP has ~40 MB of Lua heap, so collect earlier than stock Lua (pause 200).
-- Config: gc_pause (default 130), gc_stepmul (default 300).
collectgarbage("setpause", CFG.gc_pause or 130); collectgarbage("setstepmul", CFG.gc_stepmul or 300)
-- Games written for desktop RAM stop the collector and step it by time (e.g. a 2 GB "ceiling"): on the PSP that
-- ends in "not enough memory". Ignore collectgarbage("stop") unless the config sets gc_allow_stop = true.
if not CFG.gc_allow_stop then
    local real_gc = collectgarbage
    function collectgarbage(opt, ...)
        if opt == "stop" then return 0 end
        return real_gc(opt, ...)
    end
end
local floor, sin, cos, sqrt, abs, max, min = math.floor, math.sin, math.cos, math.sqrt, math.abs, math.max, math.min
local unpack = unpack

local W, H = 480, 272
local DEFAULT_FONT = (PSP_CONFIG or {}).font or "default.ttf"
local GAME, SAVE = "game/", "save/"

function PSP_LOG(msg)
    local f = io.open("psp_log.txt", "a")
    if f then f:write(tostring(msg), "\n"); f:close() end
end

love = { _version = "11.5", _psp = true }
function love.getVersion() return 11, 5, 0, "Mysterious Mysteries" end
local love = love

-- Honest capability table, same schema as LOVE-WrapLua's core/capabilities.lua (love._backend).
love._backend = {
    renderer  = "PSP native (GU)",
    tier      = 2,   -- partial: no shader yet (canvas: 2 render targets in VRAM)
    limits    = { pointsize = 1, texturesize = 512, multicanvas = 1, canvasmsaa = 0, potonly = false },   -- larger images are tiled
    supported = { clampzero = false, glsl3 = false, instancing = false, multicanvasformats = false, lighten = false,
                  fullnpot = false, pixelshaderhighp = false, shaderderivatives = false, canvas = true, shader = false },
    features  = { transform = true, quaddraw = true, polygonfill = true, primitives = true, scissor = true, blendmode = true,
                  rotation = true, scaling = true, tiling = true, fonts = "ttf", text = true },
    emulator  = "PPSSPP",
    rendersensitive = { blendmode = false, framebufferread = true, texturefilter = true, savepersistence = true },
    system    = { cores = 1, battery = false, vibrate = false, openurl = false, clipboard = "memory" },
    audio     = { voices = 24, seek = true, pitch = true, formats = "ogg wav" },   -- C mixer thread, see native/src/audio.c
    blend     = { native = true, modes = { alpha = true, add = true, multiply = true } },
}

-- ------------------------------------------------------------------ filesystem
local fs = {}
love.filesystem = fs
PSP_FSCOUNT = {}

local function exists(p) return N.stat(p) ~= nil end
local function resolve(path)
    path = path:gsub("^/", "")
    if exists(SAVE .. path) then return SAVE .. path end
    if exists(GAME .. path) then return GAME .. path end
    return nil
end
local function ensure_dirs(path)
    local dir = ""
    for part in path:gmatch("([^/]+)/") do
        dir = dir .. part .. "/"
        if not exists(SAVE .. dir) then N.mkdir(SAVE .. dir) end
    end
end
fs.getSaveDirectory = function() return SAVE end
fs.getSourceBaseDirectory = function() return "." end
fs.getWorkingDirectory = function() return "." end
fs.setIdentity = function() end
fs.getIdentity = function() return CFG.identity or "love" end
fs.isFused = function() return false end
function fs.read(path, size)
    local p = resolve(path)
    if not p then return nil, "Could not open file " .. tostring(path) end
    local f = io.open(p, "rb"); if not f then return nil, "Could not open file " .. p end
    local data = size and f:read(size) or f:read("*a")
    f:close()
    return data, #data
end
function fs.write(path, data)
    ensure_dirs(path)
    local f = io.open(SAVE .. path, "wb"); if not f then return false, "cannot write " .. path end
    f:write(data); f:close(); return true
end
function fs.append(path, data)
    ensure_dirs(path)
    local f = io.open(SAVE .. path, "ab")
    if not f then f = io.open(SAVE .. path, "wb") end   -- the emulator host FS cannot append to a missing file
    if not f then return false, "cannot append " .. path end
    f:write(data); f:close(); return true
end
function fs.getInfo(path, filter)
    local p = resolve(path)
    if not p then return nil end
    local kind, size, mtime = N.stat(p)
    if filter and filter ~= kind then return nil end
    return { type = kind, size = size, modtime = mtime }
end
function fs.createDirectory(path)
    ensure_dirs(path .. "/")
    return true
end
function fs.remove(path)
    local p = SAVE .. path
    return exists(p) and N.remove(p) or false
end
local manifest
do local f = loadfile("manifest.lua"); if f then manifest = f() end end
function fs.getDirectoryItems(path)
    local seen, out = {}, {}
    path = path:gsub("/$", "")
    -- the game dir comes from the build manifest (correct file-name case), the save dir from the device
    local mlist = manifest and manifest[path]
    if mlist then for _, n in ipairs(mlist) do seen[n] = true; out[#out + 1] = n end
    elseif not manifest then
        local list = N.listdir(GAME .. path)
        if list then for _, n in ipairs(list) do seen[n] = true; out[#out + 1] = n end end
    end
    local list = N.listdir(SAVE .. path)
    if list then
        for _, n in ipairs(list) do if not seen[n] then seen[n] = true; out[#out + 1] = n end end
    end
    table.sort(out)
    return out
end
function fs.load(path)
    local p = resolve(path)
    if not p then return nil, "Could not open file " .. tostring(path) end
    return loadfile(p)
end
function fs.lines(path)
    local data = fs.read(path) or ""
    return data:gmatch("([^\n]*)\n?")
end
fs.mount = function() return true end
fs.unmount = function() return true end
for _, name in ipairs({ "read", "write", "append", "getInfo", "createDirectory", "remove", "getDirectoryItems", "load" }) do
    local orig = fs[name]
    fs[name] = function(a, ...)
        local k = name .. ":" .. tostring(a)
        PSP_FSCOUNT[k] = (PSP_FSCOUNT[k] or 0) + 1
        return orig(a, ...)
    end
end

-- ----------------------------------------------------------------------- timer
local timer = {}
love.timer = timer
do
    local t0 = N.time()
    local last, delta, avg, frames, fpst, fps = t0, 0, 0, 0, t0, 0
    function timer.getTime() return N.time() - t0 end
    function timer.step()
        local n = N.time(); delta = n - last; last = n
        avg = avg * 0.9 + delta * 0.1
        frames = frames + 1
        if n - fpst >= 1 then fps = frames; frames = 0; fpst = n end
        return delta
    end
    function timer.getDelta() return delta end
    function timer.getAverageDelta() return avg end
    function timer.getFPS() return fps end
    -- inside a love.thread coroutine, sleeping hands control back to the main loop (threads are cooperative)
function timer.sleep(s)
    local co = coroutine.running()
    if co and PSP_THREAD_COS[co] then coroutine.yield() else N.sleep(s) end
end
end

-- ----------------------------------------------------------------------- system
love.system = {
    getOS = function() return CFG.os or "PSP" end,
    getProcessorCount = function() return 1 end,
    openURL = function() return false end,
    getClipboardText = function() return "" end,
    setClipboardText = function() end,
    getPowerInfo = function() return "unknown", nil, nil end,
}
love.arg = { parseGameArguments = function() return {} end }
love.data = {
    compress = function(_, _, data) return N.deflate(data) end,
    decompress = function(_, _, data) return N.inflate(data) end,
}

-- ----------------------------------------------------------------------- window/mouse/touch/keyboard stubs
love.window = {
    getMode = function() return W, H, { fullscreen = true, vsync = 1, resizable = false, display = 1, msaa = 0, minwidth = W, minheight = H, borderless = false, centered = true } end,
    updateMode = function() return true end, setMode = function() return true end,
    getDesktopDimensions = function() return W, H end,
    getFullscreenModes = function() return { { width = W, height = H } } end,
    getDisplayCount = function() return 1 end,
    toPixels = function(...) return ... end, fromPixels = function(...) return ... end,
    getDPIScale = function() return 1 end, getPixelScale = function() return 1 end,
    isOpen = function() return true end, getTitle = function() return CFG.title or "LOVE" end, setTitle = function() end,
    showMessageBox = function() return true end, setFullscreen = function() return true end,
    getFullscreen = function() return true end, setVSync = function() end, getVSync = function() return 1 end,
    hasFocus = function() return true end, getSafeArea = function() return 0, 0, W, H end,
    isVisible = function() return true end, setIcon = function() return true end,
}
local noop = function() end
love.mouse = {
    setVisible = noop, isVisible = function() return false end, setGrabbed = noop, isGrabbed = function() return false end,
    setRelativeMode = noop, getRelativeMode = function() return false end,
    getPosition = function() return 0, 0 end, getX = function() return 0 end, getY = function() return 0 end,
    isDown = function() return false end, setPosition = noop, newCursor = function() return {} end, setCursor = noop,
}
love.touch = { getTouches = function() return {} end, getPosition = function() return 0, 0 end }
love.keyboard = {
    isDown = function() return false end, isScancodeDown = function() return false end, setKeyRepeat = noop,
    hasKeyRepeat = function() return false end, setTextInput = noop, hasTextInput = function() return false end,
    hasKeyboard = function() return false end,
}

-- ----------------------------------------------------------------------- graphics
local g = {}
love.graphics = g
local bg = { 0, 0, 0, 1 }
local linew = 1
local default_linear = false
local blend_mode = "alpha"
local cur_font
local scissor_rect

local Image = {}; Image.__index = Image
local Quad = {}; Quad.__index = Quad
local Font = {}; Font.__index = Font
local Text = {}; Text.__index = Text
local Stub = {}; Stub.__index = Stub

function g.getWidth() return W end
function g.getHeight() return H end
function g.getDimensions() return W, H end
g.getPixelWidth = g.getWidth; g.getPixelHeight = g.getHeight; g.getPixelDimensions = g.getDimensions
function g.getDPIScale() return 1 end
function g.isActive() return true end
function g.isCreated() return true end
function g.isGammaCorrect() return false end
function g.getSystemLimits() return love._backend.limits end
function g.getRendererInfo() return "PSP", "GE", "Sony", "1.0" end
function g.getSupported() return love._backend.supported end
function g.setDefaultFilter(min, mag) default_linear = (min == "linear" or mag == "linear") end
function g.getDefaultFilter() return default_linear and "linear" or "nearest", default_linear and "linear" or "nearest" end
function g.setLineStyle() end
function g.setLineJoin() end
function g.setLineWidth(w) linew = w end
function g.getLineWidth() return linew end
function g.setPointSize() end
function g.setColorMask() end
function g.setDepthMode() end
function g.setWireframe() end
function g.setMeshCullMode() end

local function readcolor(a, b, c, d)
    if type(a) == "table" then return a[1], a[2], a[3], a[4] or 1 end
    return a, b, c, d or 1
end
g.setColor, g.getColor = N.set_color, N.get_color
function g.setBackgroundColor(a, b, c, d) bg[1], bg[2], bg[3], bg[4] = readcolor(a, b, c, d) end
function g.getBackgroundColor() return bg[1], bg[2], bg[3], bg[4] end
function g.clear(a, b, c, d)
    if a == nil or a == false then N.clear(bg[1], bg[2], bg[3], bg[4]) return end
    local r, gg, bb, aa = readcolor(a, b, c, d)
    N.clear(r, gg, bb, aa)
end
function g.setBlendMode(mode)
    blend_mode = mode
    N.blend(mode == "add" and 1 or mode == "multiply" and 2 or 0)
end
function g.getBlendMode() return blend_mode, "alphamultiply" end
function g.setScissor(x, y, w, h)
    if x == nil then scissor_rect = nil; N.scissor(); return end
    scissor_rect = { x, y, w, h }; N.scissor(x, y, w, h)
end
function g.getScissor() if scissor_rect then return unpack(scissor_rect) end end

-- transforms live in C (matrix stack)
g.push, g.pop, g.origin, g.translate, g.scale, g.rotate = N.push, N.pop, N.origin, N.translate, N.scale, N.rotate
g.shear = N.shear
function g.transformPoint(x, y)
    local a, b, c, d, e, f = N.get_matrix()
    return a * x + c * y + e, b * x + d * y + f
end
function g.inverseTransformPoint(x, y)
    local a, b, c, d, e, f = N.get_matrix()
    local det = a * d - b * c
    if det == 0 then return x, y end
    x, y = x - e, y - f
    return (d * x - c * y) / det, (a * y - b * x) / det
end
-- A love.math Transform keeps a column-major 3x3 in `_m`: columns (1,2), (4,5) and the translation (7,8).
function g.applyTransform(t)
    local m = t and t._m
    if m then N.mul_matrix(m[1], m[2], m[4], m[5], m[7], m[8]) end
end
function g.replaceTransform(t)
    local m = t and t._m
    if m then N.set_matrix(m[1], m[2], m[4], m[5], m[7], m[8]) end
end
function g.reset()
    N.reset_stack(); g.setColor(1, 1, 1, 1)
    g.setBlendMode("alpha"); g.setScissor(); linew = 1
end

-- images
local ImageData = {}; ImageData.__index = ImageData
function g.newImage(path)
    if type(path) == "table" and getmetatable(path) == ImageData then  -- from love.image.newImageData (shares the texture)
        local d = path
        if not d._tex then error("ImageData has no pixel data (blank ImageData is not supported yet)", 2) end
        N.tex_filter(d._tex, default_linear)
        return setmetatable({ _tex = d._tex, w = d.w, h = d.h, linear = default_linear }, Image)
    end
    local p = type(path) == "string" and (love.filesystem.getInfo(path) and (resolve(path))) or nil
    if not p then error("Could not open file " .. tostring(path), 2) end
    local tex, w, h = N.image_load(p)
    if not tex then error("Could not load image " .. p .. ": " .. tostring(w), 2) end
    N.tex_filter(tex, default_linear)
    return setmetatable({ _tex = tex, w = w, h = h, linear = default_linear }, Image)
end
function ImageData:getWidth() return self.w end
function ImageData:getHeight() return self.h end
function ImageData:getDimensions() return self.w, self.h end
function ImageData:getPixel() return 0, 0, 0, 0 end   -- CPU pixel access: E3
function ImageData:setPixel() end
function ImageData:release() return true end            -- handles are shared by reference; the texture lives with the Image
function ImageData:type() return "ImageData" end
function ImageData:typeOf(t) return t == "ImageData" or t == "Data" or t == "Object" end
g._ImageData = ImageData
function Image:getWidth() return self.w end
function Image:getHeight() return self.h end
function Image:getDimensions() return self.w, self.h end
Image.getPixelWidth = Image.getWidth; Image.getPixelHeight = Image.getHeight; Image.getPixelDimensions = Image.getDimensions
function Image:getDPIScale() return 1 end
function Image:setFilter(min, mag) self.linear = (min == "linear" or mag == "linear"); if self._tex then N.tex_filter(self._tex, self.linear) end end
function Image:getFilter() return self.linear and "linear" or "nearest", self.linear and "linear" or "nearest" end
function Image:setWrap() end
function Image:type() return "Image" end
function Image:typeOf(t) return t == "Image" or t == "Texture" or t == "Drawable" end
function Image:release() end

function g.newQuad(x, y, w, h, sw, sh) return setmetatable({ x = x, y = y, w = w, h = h }, Quad) end
function Quad:getViewport() return self.x, self.y, self.w, self.h end
function Quad:setViewport(x, y, w, h) self.x, self.y, self.w, self.h = x, y, w, h end
function Quad:type() return "Quad" end
function Quad:release() return true end
function Quad:typeOf(t) return t == "Quad" or t == "Object" end

-- stubs for features the PSP lacks: shaders, canvas, video
function Stub:send() end
function Stub:sendColor() end
function Stub:hasUniform() return false end
function Stub:getWidth() return self._w or W end
function Stub:getHeight() return self._h or H end
function Stub:getDimensions() return self._w or W, self._h or H end
Stub.getPixelWidth = Stub.getWidth; Stub.getPixelHeight = Stub.getHeight; Stub.getPixelDimensions = Stub.getDimensions
function Stub:setFilter() end
function Stub:getFilter() return "linear", "linear" end
function Stub:release() end
function Stub:play() end
function Stub:pause() end
function Stub:isPlaying() return false end
function Stub:getSource() return nil end
function Stub:getDuration() return 0 end
function Stub:rewind() end
function Stub:seek() end
function Stub:tell() return 0 end
function Stub:setLooping() end
function Stub:newImageData() return {} end
function Stub:getWarnings() return "" end
g.newShader = function() return setmetatable({ _stub = true }, Stub) end
g.newVideo = function() return setmetatable({ _stub = true }, Stub) end
g.setShader = noop
g.getShader = function() return nil end
-- Canvas: render-to-texture in spare VRAM (native.canvas_*). Two 512x<=256 RGBA targets fit next to the screen buffers;
-- a canvas that does not fit (too big, or VRAM exhausted) is "null": setCanvas on it leaves the current target
-- unchanged (content goes wherever it was going) and drawing the canvas itself draws nothing (the old stub behaviour).
local Canvas = setmetatable({}, { __index = Image }); Canvas.__index = Canvas
g._Canvas = Canvas
local current_canvas = nil
function g.newCanvas(w, h)
    if type(w) ~= "number" then w, h = 480, 272 end
    h = type(h) == "number" and h or w
    local tex = N.canvas_new(w, h)
    if tex then N.tex_filter(tex, default_linear) end
    return setmetatable({ _tex = tex, w = w, h = h, linear = default_linear, _null = tex == nil }, Canvas)
end
function Canvas:type() return "Canvas" end
function Canvas:typeOf(t) return t == "Canvas" or t == "Texture" or t == "Drawable" or t == "Object" end
function Canvas:getMSAA() return 0 end
function Canvas:getFormat() return "normal" end
function Canvas:newImageData() return setmetatable({ w = self.w, h = self.h }, ImageData) end   -- CPU readback: not supported
function Canvas:renderTo(fn) local prev = current_canvas; g.setCanvas(self); fn(); g.setCanvas(prev) end
function g.setCanvas(c, ...)
    if type(c) == "table" and getmetatable(c) ~= Canvas then c = c[1] end   -- {canvas, stencil = true}
    current_canvas = c
    if c == nil then N.canvas_set(nil)
    elseif not c._null then N.canvas_set(c._tex) end
    if scissor_rect then N.scissor(scissor_rect[1], scissor_rect[2], scissor_rect[3], scissor_rect[4]) else N.scissor() end
end
function g.getCanvas() return current_canvas end

local present_n, draws_n = 0, 0   -- frame log (PSP_FRAMELOG)
-- draw: (drawable, [quad,] x, y, r, sx, sy, ox, oy)
local nativedraw, fontdraw = N.draw, N.font_draw

function g.draw(obj, a, b, c, d, e, f, h, i)
    draws_n = draws_n + 1
    local mt = getmetatable(obj)
    if mt == Image or mt == Canvas then
        if obj._null then return end
        if getmetatable(a) == Quad then
            nativedraw(obj._tex, a.x, a.y, a.w, a.h, b, c, d, e, f, h, i)
        else
            nativedraw(obj._tex, 0, 0, obj.w, obj.h, a, b, c, d, e, f, h)
        end
    elseif mt == Text then
        obj:_draw(a, b, c, d, e, f, h)
    elseif obj ~= nil and lv1lua and lv1lua.util.isDrawObject(obj) then   -- SpriteBatch, ParticleSystem (shared)
        obj:_draw(a, b, c, d, e, f, h)
    end
    -- Canvas / Video / Shader stubs draw nothing
end

-- fonts
local font_cache = {}
function g.newFont(path, size)
    if type(path) == "number" then size = path; path = DEFAULT_FONT end
    size = size or 12
    local p = resolve(path)
    if not p then error("Could not open font " .. tostring(path), 2) end
    local rsize = size > 40 and 40 or size
    local nf, asc, desc, lh = N.font_load(p, size, rsize)
    if not nf then error("font load failed: " .. tostring(asc), 2) end
    return setmetatable({ _f = nf, size = size, asc = asc, desc = desc, lh = lh, lineheight = 1 }, Font)
end
function g.setNewFont(path, size) cur_font = g.newFont(path, size); return cur_font end
function g.setFont(f) cur_font = f end
function g.getFont()
    if not cur_font then cur_font = g.newFont(DEFAULT_FONT, 12) end
    return cur_font
end
local function plain(text)
    if type(text) == "table" then
        local parts = {}
        for i = 1, #text do if type(text[i]) == "string" then parts[#parts + 1] = text[i] end end
        return table.concat(parts)
    end
    return tostring(text)
end
function Font:getWidth(text) return N.font_width(self._f, plain(text)) end
function Font:getHeight() return floor(self.asc - self.desc + 0.5) end
function Font:getAscent() return self.asc end
function Font:getDescent() return self.desc end
function Font:getBaseline() return self.asc end
function Font:getLineHeight() return self.lineheight end
function Font:setLineHeight(h) self.lineheight = h end
function Font:hasGlyphs(text) return N.font_has(self._f, plain(text)) end
function Font:setFilter() end
function Font:getFilter() return "linear", "linear" end
function Font:getDPIScale() return 1 end
function Font:setFallbacks() end
function Font:type() return "Font" end
function Font:getWrap(text, limit)
    text = plain(text)
    local lines, maxw = {}, 0
    for para in (text .. "\n"):gmatch("([^\n]*)\n") do
        local line = ""
        for word in para:gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            if line ~= "" and self:getWidth(try) > limit then
                lines[#lines + 1] = line; maxw = max(maxw, self:getWidth(line)); line = word
            else line = try end
        end
        lines[#lines + 1] = line; maxw = max(maxw, self:getWidth(line))
    end
    return maxw, lines
end

-- Text objects: font + string or coloured-text table
local function segments(text)
    if type(text) == "table" then
        local segs, col = {}, nil
        for i = 1, #text do
            local v = text[i]
            if type(v) == "table" then col = v elseif type(v) == "string" then segs[#segs + 1] = { col, v } end
        end
        return segs
    end
    return { { nil, tostring(text) } }
end
function g.newText(font, text)
    local t = setmetatable({ font = font }, Text)
    t:set(text or "")
    return t
end
function Text:set(text)
    self.segs = segments(text)
    local w = 0
    for _, s in ipairs(self.segs) do local sw = N.font_width(self.font._f, s[2]); s[3] = sw; w = w + sw end
    self.w = w
    local _, n = plain(text):gsub("\n", "")
    self.h = self.font:getHeight() * (n + 1)
end
function Text:setf(text) self:set(text) end
function Text:clear() self:set("") end
function Text:getWidth() return self.w end
function Text:getHeight() return self.h end
function Text:getDimensions() return self.w, self.h end
function Text:getFont() return self.font end
function Text:type() return "Text" end
function Text:_draw(x, y, r, sx, sy, ox, oy)
    local penx = 0
    local fn = self.font._f
    local segs = self.segs
    local n = #segs
    for i = 1, n do
        local s = segs[i]
        local col = s[1]
        if col then fontdraw(fn, s[2], x, y, r, sx, sy, ox, oy, penx, 0, col[1], col[2], col[3], col[4] or 1)
        else fontdraw(fn, s[2], x, y, r, sx, sy, ox, oy, penx, 0) end
        -- the pen only moves for a following segment; widths are cached per segment
        if i < n then
            local w = s[3]
            if not w then w = N.font_width(fn, s[2]); s[3] = w end
            penx = penx + w
        end
    end
end
function g.print(text, x, y, r, sx, sy, ox, oy)
    local font = g.getFont()
    if type(text) == "table" then g.newText(font, text):_draw(x, y, r, sx, sy, ox, oy)
    else fontdraw(font._f, tostring(text), x, y, r, sx, sy, ox, oy, 0, 0) end
end
function g.printf(text, x, y, limit, align, r, sx, sy, ox, oy)
    local font = g.getFont()
    local _, lines = font:getWrap(text, limit)
    local lh = font:getHeight() * font.lineheight
    for i, line in ipairs(lines) do
        local w = font:getWidth(line)
        local dx = 0
        if align == "center" then dx = (limit - w) / 2 elseif align == "right" then dx = limit - w end
        fontdraw(font._f, line, x, y, r, sx, sy, ox, oy, dx, (i - 1) * lh)
    end
end

-- primitives (transform + colour applied in C)
local fill_poly, fill_rect, nline = N.fill_poly, N.fill_rect, N.line
local function segment(x1, y1, x2, y2) nline(x1, y1, x2, y2, linew) end
local function rounded(x, y, w, h, rx, ry)
    rx = min(rx, w / 2); ry = min(ry or rx, h / 2)
    local pts, seg = {}, 6
    local function corner(cx, cy, a0)
        for i = 0, seg do
            local a = a0 + (math.pi / 2) * i / seg
            pts[#pts + 1] = cx + cos(a) * rx; pts[#pts + 1] = cy + sin(a) * ry
        end
    end
    corner(x + w - rx, y + h - ry, 0); corner(x + rx, y + h - ry, math.pi / 2)
    corner(x + rx, y + ry, math.pi); corner(x + w - rx, y + ry, math.pi * 1.5)
    return pts
end
local function outline(pts)
    local n = #pts
    for i = 1, n, 2 do local j = (i + 2 > n) and 1 or i + 2; nline(pts[i], pts[i + 1], pts[j], pts[j + 1], linew) end
end
function g.rectangle(mode, x, y, w, h, rx, ry)
    if rx and rx > 0 then
        local pts = rounded(x, y, w, h, rx, ry)
        if mode == "fill" then fill_poly(pts) else outline(pts) end
    elseif mode == "fill" then fill_rect(x, y, w, h)
    else outline({ x, y, x + w, y, x + w, y + h, x, y + h }) end
end
function g.polygon(mode, ...)
    local pts = ...
    if type(pts) ~= "table" then pts = { ... } end
    if mode == "fill" then fill_poly(pts) else outline(pts) end
end
function g.line(...)
    local pts = ...
    if type(pts) ~= "table" then pts = { ... } end
    for i = 1, #pts - 3, 2 do nline(pts[i], pts[i + 1], pts[i + 2], pts[i + 3], linew) end
end
function g.circle(mode, x, y, r, segs)
    segs = segs or 24
    local pts = {}
    for i = 0, segs - 1 do local a = 2 * math.pi * i / segs; pts[#pts + 1] = x + cos(a) * r; pts[#pts + 1] = y + sin(a) * r end
    g.polygon(mode, pts)
end
function g.points() end

-- frame handling
function g.present()
    present_n = present_n + 1
    if PSP_FRAMELOG and present_n % PSP_FRAMELOG == 0 then
        PSP_LOG(string.format("present #%d t=%.1f lua=%dKB tex=%dKB draws/frame~%d canvas=%s", present_n, love.timer.getTime(), collectgarbage("count"), (N.tex_mem and N.tex_mem() or 0) / 1024, draws_n, tostring(current_canvas ~= nil)))
    end
    draws_n = 0
    N.end_frame(true)
    N.begin_frame()
    N.reset_stack()
    N.blend(0); N.scissor(); scissor_rect = nil; current_canvas = nil
end
love._begin = function() N.begin_frame() end

-- ------------------------------------------------------------------------ audio / sound
-- Sources are C voices mixed by the engine's audio thread (native/src/audio.c): .ogg and .wav, pitch, volume,
-- looping, seek. A file that cannot be played (other formats, missing, unreadable) gives a silent source and a
-- line in psp_log.txt, so a game that loads its sounds at start keeps running.
local Source = {}; Source.__index = Source
local all_sources = setmetatable({}, { __mode = "k" })

local function wrap_source(h, kind)
    local s = setmetatable({ _h = h, _kind = kind, _vol = 1, _pitch = 1, _loop = false }, Source)
    all_sources[s] = true
    return s
end

love.audio = {}
function love.audio.newSource(path, kind)
    if type(path) ~= "string" then
        PSP_LOG("audio: newSource needs a file name, got " .. type(path) .. "; silent source")
        return setmetatable({ _stub = true }, Stub)
    end
    local p = resolve(path)
    if not p then
        PSP_LOG("audio: " .. path .. " not found; silent source")
        return setmetatable({ _stub = true }, Stub)
    end
    local h, err = N.audio_new(p, kind == "stream")
    if not h then
        PSP_LOG("audio: " .. path .. ": " .. tostring(err) .. "; silent source")
        return setmetatable({ _stub = true }, Stub)
    end
    return wrap_source(h, kind or "static")
end
local function each(list, fn, ...)
    if #list == 1 and type(list[1]) == "table" and not getmetatable(list[1]) then list = list[1] end
    for i = 1, #list do local s = list[i]; if s and s[fn] then s[fn](s, ...) end end
end
function love.audio.play(...) each({ ... }, "play") end
function love.audio.pause(...)
    if select("#", ...) == 0 then for s in pairs(all_sources) do if s:isPlaying() then s:pause() end end
    else each({ ... }, "pause") end
end
function love.audio.stop(...)
    if select("#", ...) == 0 then for s in pairs(all_sources) do s:stop() end
    else each({ ... }, "stop") end
end
function love.audio.resume(...) each({ ... }, "play") end
function love.audio.setVolume(v) N.audio_master(v) end
function love.audio.getVolume() return N.audio_master() end
function love.audio.getActiveSourceCount() return N.audio_count() end
love.audio.setPosition = noop
love.audio.getPosition = function() return 0, 0, 0 end
love.audio.setOrientation = noop
love.audio.setVelocity = noop
love.audio.setDistanceModel = noop
love.audio.getDistanceModel = function() return "inverseclamped" end
love.audio.setDopplerScale = noop
love.audio.getMaxSourceEffects = function() return 0 end
love.audio.isEffectsSupported = function() return false end
love.audio.getRecordingDevices = function() return {} end

function Source:play() return N.audio_play(self._h) end
function Source:pause() N.audio_pause(self._h) end
function Source:stop() N.audio_stop(self._h) end
function Source:resume() N.audio_play(self._h) end
function Source:rewind() N.audio_seek(self._h, 0) end
function Source:isPlaying() return N.audio_is_playing(self._h) end
function Source:isPaused() return N.audio_is_paused(self._h) end
function Source:isStopped() return not N.audio_is_playing(self._h) and not N.audio_is_paused(self._h) end
function Source:setVolume(v) self._vol = v; N.audio_volume(self._h, v) end
function Source:getVolume() return self._vol end
function Source:setPitch(p) self._pitch = p; N.audio_pitch(self._h, p) end
function Source:getPitch() return self._pitch end
function Source:setLooping(b) self._loop = b and true or false; N.audio_loop(self._h, self._loop) end
function Source:isLooping() return self._loop end
local function secs(self, v, unit)
    if unit == "samples" then local rate = N.audio_info(self._h); return v * rate end
    return v
end
function Source:seek(pos, unit)
    if unit == "samples" then local rate = N.audio_info(self._h); pos = pos / rate end
    N.audio_seek(self._h, pos)
end
function Source:tell(unit) return secs(self, N.audio_tell(self._h), unit) end
function Source:getDuration(unit) return secs(self, N.audio_duration(self._h), unit) end
function Source:getChannelCount() local _, ch = N.audio_info(self._h); return ch end
function Source:getType() return self._kind end
function Source:clone()
    local h = N.audio_clone(self._h)
    if not h then return setmetatable({ _stub = true }, Stub) end
    local c = wrap_source(h, self._kind)
    c:setVolume(self._vol); c:setPitch(self._pitch); c:setLooping(self._loop)
    return c
end
function Source:release() N.audio_stop(self._h); return true end
function Source:type() return "Source" end
function Source:typeOf(t) return t == "Source" or t == "Object" end
Source.setPosition = noop
function Source:getPosition() return 0, 0, 0 end
Source.setVelocity = noop
Source.setDirection = noop
Source.setCone = noop
Source.setRelative = noop
Source.setAttenuationDistances = noop
Source.setRolloff = noop
Source.setAirAbsorption = noop
Source.setEffect = noop
Source.setFilter = noop
function Source:getEffect() return false end

love.sound = { newSoundData = function() return setmetatable({ _stub = true }, Stub) end }
function Stub:setVolume() end
function Stub:setPitch() end
function Stub:stop() end
function Stub:setPosition() end
function Stub:isLooping() return false end
function Stub:clone() return setmetatable({ _stub = true }, Stub) end
-- audio is silent: queueable sources never ask for data (0 free buffers), sound data is empty
function Stub:getFreeBufferCount() return 0 end
function Stub:queue() return true end
function Stub:getSampleCount() return 0 end
function Stub:getSample() return 0 end
function Stub:setSample() end
function Stub:getSampleRate() return 44100 end
function Stub:getChannelCount() return 2 end
function Stub:getBitDepth() return 16 end
function Stub:getVolume() return 1 end
function Stub:getPitch() return 1 end
function Stub:isStopped() return true end
function Stub:isPaused() return false end
function Stub:getType() return "static" end
-- Quad/Image: an unknown public method is a harmless no-op too (release/flush-style calls)
for _, class in ipairs({ Quad, Image }) do
    setmetatable(class, { __index = function(_, k) if type(k) == "string" and k:sub(1, 1) ~= "_" then return function() end end end })
end
-- any other method a game calls on a stub object is a harmless no-op
setmetatable(Stub, { __index = function(_, k) if type(k) == "string" and k:sub(1, 1) ~= "_" then return function() end end end })

-- ----------------------------------------------------------------------- threads (cooperative coroutines)
local thread = {}
love.thread = thread
local channels = {}
local running = {}
local Channel = {}; Channel.__index = Channel
function thread.getChannel(name)
    local c = channels[name]
    if not c then c = setmetatable({ q = {}, first = 1, last = 0 }, Channel); channels[name] = c end
    return c
end
function thread.newChannel() return setmetatable({ q = {}, first = 1, last = 0 }, Channel) end
-- LÖVE copies tables sent through a channel (the sender may keep mutating its table); functions/userdata pass by reference.
local function chcopy(v, seen)
    if type(v) ~= "table" or getmetatable(v) then return v end   -- LÖVE objects are shared, plain tables are copied
    if seen[v] then return seen[v] end
    local c = {}; seen[v] = c
    for k, x in pairs(v) do c[chcopy(k, seen)] = chcopy(x, seen) end
    return c
end
function Channel:push(v) self.last = self.last + 1; self.q[self.last] = chcopy(v, {}); return self.last end
function Channel:supply(v) return self:push(v) end
function Channel:pop()
    if self.first > self.last then return nil end
    local v = self.q[self.first]; self.q[self.first] = nil; self.first = self.first + 1
    return v
end
function Channel:peek() if self.first > self.last then return nil end return self.q[self.first] end
function Channel:getCount() return self.last - self.first + 1 end
function Channel:clear() self.q = {}; self.first = 1; self.last = 0 end
function Channel:demand(timeout)
    while self.first > self.last do
        if not coroutine.running() then return nil end
        coroutine.yield()
    end
    return self:pop()
end
local Thread = {}; Thread.__index = Thread
function thread.newThread(src)
    if type(src) ~= "string" then  -- FileData / ByteData
        local code = src:getString()
        return setmetatable({ code = code, name = (src.getFilename and src:getFilename() or "thread"):sub(1, 40) }, Thread)
    end
    local code = src
    if not src:find("\n") and love.filesystem.getInfo(src) then code = love.filesystem.read(src) end
    return setmetatable({ code = code, name = src:sub(1, 40) }, Thread)
end
function Thread:start(...)
    if self.code:find("https") then self.dead = true; return end  -- no network on the PSP
    local chunk, err = loadstring(self.code, "=thread")
    if not chunk then PSP_LOG("thread compile error: " .. tostring(err)); self.dead = true; return end
    local env = setmetatable({}, { __index = _G })
    setfenv(chunk, env)
    local args = { ... }
    self.co = coroutine.create(function() return chunk(unpack(args)) end)
    PSP_THREAD_COS[self.co] = true
    if PSP_MEMWATCH then debug.sethook(self.co, PSP_MEMWATCH, "", 20000) end
    if PSP_HOOK then debug.sethook(self.co, function() PSP_LOG("[thread " .. self.name .. "]"); PSP_HOOK() end, "", 30000000) end
    running[#running + 1] = self
    self:_step()
end
function Thread:_step()
    if self.dead or not self.co then return end
    local ok, err = coroutine.resume(self.co)
    if not ok then self.err = err; self.dead = true; PSP_LOG("thread error (" .. self.name .. "): " .. tostring(err)) end
    if coroutine.status(self.co) == "dead" then self.dead = true end
end
function Thread:isRunning() return not self.dead end
function Thread:getError() return self.err end
function Thread:wait() end
function thread._step() for i = 1, #running do running[i]:_step() end end

-- require("love.xxx") inside thread code
-- (love.image/joystick/keyboard/mouse/touch are filled in later by the stubs section; resolve lazily)
for _, name in ipairs({ "system", "timer", "thread", "filesystem", "audio", "sound", "data", "window", "graphics", "event", "math" }) do
    package.loaded["love." .. name] = love[name] or true
end
for _, name in ipairs({ "image", "joystick", "keyboard", "mouse", "touch", "video", "font", "physics" }) do
    package.preload["love." .. name] = function() love[name] = love[name] or {}; return love[name] end
end
package.loaded["bit"] = package.loaded["bit"] or bit
love.math = love.math or { random = math.random, setRandomSeed = math.randomseed }

-- ----------------------------------------------------------------------- utf8 (LÖVE 11 ships the Lua 5.3 module)
do
    local u = {}
    u.charpattern = "[\0-\x7F\xC2-\xF4][\x80-\xBF]*"
    local function enc(c)
        if c < 0x80 then return string.char(c)
        elseif c < 0x800 then return string.char(0xC0 + math.floor(c / 0x40), 0x80 + c % 0x40)
        elseif c < 0x10000 then return string.char(0xE0 + math.floor(c / 0x1000), 0x80 + math.floor(c / 0x40) % 0x40, 0x80 + c % 0x40)
        else return string.char(0xF0 + math.floor(c / 0x40000), 0x80 + math.floor(c / 0x1000) % 0x40, 0x80 + math.floor(c / 0x40) % 0x40, 0x80 + c % 0x40) end
    end
    function u.char(...)
        local t = { ... }
        for i = 1, #t do t[i] = enc(t[i]) end
        return table.concat(t)
    end
    -- decode the sequence at byte i: returns codepoint, next index (or nil on invalid)
    local function dec(s, i)
        local c = s:byte(i); if not c then return nil end
        if c < 0x80 then return c, i + 1 end
        local n, cp
        if c >= 0xF0 and c <= 0xF4 then n, cp = 3, c - 0xF0 elseif c >= 0xE0 then n, cp = 2, c - 0xE0
        elseif c >= 0xC2 and c < 0xE0 then n, cp = 1, c - 0xC0 else return nil end
        for k = 1, n do
            local b = s:byte(i + k); if not b or b < 0x80 or b > 0xBF then return nil end
            cp = cp * 64 + (b - 0x80)
        end
        return cp, i + n + 1
    end
    local function posrel(i, len) if i >= 0 then return i elseif -i > len then return 0 else return len + i + 1 end end
    function u.len(s, i, j)
        local len = #s; i = posrel(i or 1, len); j = posrel(j or -1, len); local n = 0
        while i <= j do
            local cp, nx = dec(s, i); if not cp then return nil, i end
            i = nx; n = n + 1
        end
        return n
    end
    function u.codepoint(s, i, j)
        local len = #s; i = posrel(i or 1, len); j = posrel(j or i, len); local out = {}
        while i <= j do
            local cp, nx = dec(s, i); if not cp then error("invalid UTF-8 code", 2) end
            out[#out + 1] = cp; i = nx
        end
        return unpack(out)
    end
    function u.offset(s, n, i)
        local len = #s
        i = i and posrel(i, len) or (n > 0 and 1 or len + 1)
        local function cont(p) local b = s:byte(p); return b and b >= 0x80 and b < 0xC0 end
        if n == 0 then while i > 1 and cont(i) do i = i - 1 end return i end
        if cont(i) then error("initial position is a continuation byte", 2) end
        if n < 0 then
            while n < 0 and i > 1 do repeat i = i - 1 until i <= 1 or not cont(i); n = n + 1 end
        else
            n = n - 1
            while n > 0 and i <= len do repeat i = i + 1 until not cont(i); n = n - 1 end
        end
        if n == 0 then return i end
    end
    function u.codes(s)
        return function(_, i)
            if i > 0 then local _, nx = dec(s, i); i = nx or (i + 1) else i = 1 end
            if i > #s then return nil end
            local cp = dec(s, i); if not cp then error("invalid UTF-8 code", 2) end
            return i, cp
        end, s, 0
    end
    package.loaded.utf8 = u; love.utf8 = u
    if rawget(_G, "utf8") == nil then utf8 = u end
end

-- ----------------------------------------------------------------------- joystick + events
local J = {}; J.__index = J
local joy = setmetatable({}, J)
local gp = { name = "PSP", down = {}, axes = { leftx = 0, lefty = 0, rightx = 0, righty = 0, triggerleft = 0, triggerright = 0 } }
function J:isGamepad() return true end
function J:getName() return "PSP" end
function J:getGUID() return "psp" end
function J:getID() return 1, 1 end
function J:isConnected() return true end
function J:getGamepadMappingString() return "" end
function J:isGamepadDown(...)
    for i = 1, select("#", ...) do if gp.down[(select(i, ...))] then return true end end
    return false
end
function J:getGamepadAxis(a) return gp.axes[a] or 0 end
function J:getAxis(i) return 0 end
function J:getAxisCount() return 0 end
function J:getButtonCount() return 0 end
function J:getHatCount() return 0 end
function J:setVibration() return true end
function J:isVibrationSupported() return false end
love.joystick = {
    getJoysticks = function() return { joy } end,
    getJoystickCount = function() return 1 end,
    loadGamepadMappings = noop,
}

local event = {}
love.event = event
local queue, qh = {}, 1
function event.push(name, ...) queue[#queue + 1] = { name, ... } end
function event.quit(code) event.push("quit", code) end
function event.clear() queue = {}; qh = 1 end
function event.poll()
    return function()
        if qh > #queue then queue = {}; qh = 1; return nil end
        local e = queue[qh]; queue[qh] = false; qh = qh + 1
        return unpack(e)
    end
end

local BUTTONS = {
    { 0x1, "back" }, { 0x8, "start" }, { 0x10, "dpup" }, { 0x20, "dpright" }, { 0x40, "dpdown" }, { 0x80, "dpleft" },
    { 0x100, "leftshoulder" }, { 0x200, "rightshoulder" }, { 0x1000, "y" }, { 0x2000, "b" }, { 0x4000, "a" }, { 0x8000, "x" },
}
local prev_mask, frame_no = 0, 0
-- autoplay.lua returns either a list {frame, "press"|"release", button} or a function(api) run as a
-- coroutine, one step per pump: api.tap(btn), api.wait(frames), api.wait_until(fn), api.log(msg)
local autoplay, autoplay_co
local btn_event
do
    local f = loadfile("autoplay.lua")
    if f then
        local r = f()
        if type(r) == "function" then
            local api = {}
            function api.wait(n) for _ = 1, n do coroutine.yield() end end
            function api.wait_until(fn, max) local n = 0; while not fn() do coroutine.yield(); n = n + 1; if max and n > max then return false end end return true end
            function api.press(b) btn_event(b, true) end
            function api.release(b) btn_event(b, false) end
            function api.tap(b) btn_event(b, true); api.wait(4); btn_event(b, false); api.wait(4) end
            api.log = PSP_LOG
            autoplay_co = coroutine.create(function() r(api) end)
        else autoplay = r end
    end
end
btn_event = function(name, down)
    gp.down[name] = down or nil
    event.push(down and "gamepadpressed" or "gamepadreleased", joy, name)
end
local function axis_event(name, v)
    v = floor(v * 20 + 0.5) / 20
    if abs(v) < 0.2 then v = 0 end
    if gp.axes[name] ~= v then gp.axes[name] = v; event.push("gamepadaxis", joy, name, v) end
end
local sent_added = false
function event.pump()
    if not sent_added then sent_added = true; event.push("joystickadded", joy) end
    frame_no = frame_no + 1
    local mask, lx, ly = N.pad()
    for _, b in ipairs(BUTTONS) do
        local was, now = bit.band(prev_mask, b[1]) ~= 0, bit.band(mask, b[1]) ~= 0
        if was ~= now then btn_event(b[2], now) end
    end
    prev_mask = mask
    axis_event("leftx", lx); axis_event("lefty", ly)
    if autoplay_co and coroutine.status(autoplay_co) ~= "dead" then
        local ok, err = coroutine.resume(autoplay_co)
        if not ok then PSP_LOG("autoplay error: " .. tostring(err)); autoplay_co = nil end
    end
    if autoplay then
        for _, a in ipairs(autoplay) do
            if a[1] == frame_no then btn_event(a[3], a[2] == "press") end
        end
    end
    thread._step()
end


-- ----------------------------------------------------------------------- extra API (third-party games)
do
    local g, noop = love.graphics, function() end
    function g.ellipse(mode, x, y, rx, ry, segs)
        segs = segs or 24
        local pts = {}
        for i = 0, segs - 1 do local a = i / segs * 2 * math.pi; pts[#pts + 1] = x + cos(a) * rx; pts[#pts + 1] = y + sin(a) * (ry or rx) end
        g.polygon(mode, pts)
    end
    g.stencil, g.setStencilTest, g.getStencilTest = noop, noop, function() return "always", 0 end   -- no stencil buffer: everything draws
    g.flushBatch = noop
    love._backend.features.stencil = false
    love._backend.features.particles = "basic"
    love.filesystem.getRealDirectory = function() return GAME end
    love.filesystem.newFileData = function(data, name)
        if name == nil then  -- newFileData(filepath)
            local path = data
            data = love.filesystem.read(path)
            if not data then error("Could not open file " .. tostring(path), 2) end
            name = path
        end
        local fd = { _data = data }
        function fd:getString() return data end
        function fd:getSize() return #data end
        function fd:getFilename() return name end
        function fd:getPointer() return data end  -- the ffi shim (psp_ffi.lua) accepts a Lua string as a pointer
        function fd:type() return "FileData" end
        function fd:release() end
        return fd
    end
    love.image = love.image or {}
    love.image.newImageData = function(a, h)
        if type(a) == "string" or (type(a) == "table" and a.getString) then   -- path or FileData
            local p = type(a) == "string" and (love.filesystem.getInfo(a) and resolve(a)) or nil
            if not p then error("Could not open file " .. tostring(a), 2) end
            local tex, w, ht = N.image_load(p)
            if not tex then error("Could not decode image " .. p .. ": " .. tostring(w), 2) end
            return setmetatable({ _tex = tex, w = w, h = ht }, love.graphics._ImageData)
        end
        return setmetatable({ w = a, h = h }, love.graphics._ImageData)      -- blank: size only
    end
    love.window.minimize = noop
    love.mouse.isCursorSupported = function() return false end
    love.keyboard.getKeyFromScancode = function(sc) return sc end
    love.keyboard.getScancodeFromKey = function(k) return k end
    -- the PSP pad is always a known gamepad: report a mapping so games skip their "unsupported device" setup
    love.joystick.getGamepadMappingString = function(guid) return tostring(guid) .. ",PSP,a:b0,b:b1,x:b2,y:b3,back:b4,start:b5,leftshoulder:b6,rightshoulder:b7,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1," end
    love.joystick.setGamepadMapping = function() return true end
    love.joystick.loadGamepadMappings = noop
    love.joystick.saveGamepadMappings = function() return "" end
    love.audio.newQueueableSource = function() return setmetatable({ _stub = true }, Stub) end
    -- love.data.encode/decode: base64 and hex
    love.data.encode = function(_, fmt, data) if fmt == "hex" then return (data:gsub(".", function(c) return ("%02x"):format(c:byte()) end)) end return N.b64encode(data) end
    love.data.decode = function(_, fmt, data) if fmt == "hex" then return (data:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end)) end return N.b64decode(data) end
end

love.handlers = setmetatable({}, { __index = function(_, name)
    return function(...) local f = love[name]; if f then return f(...) end end
end })

love.quit = nil
function love.run_unused() end
