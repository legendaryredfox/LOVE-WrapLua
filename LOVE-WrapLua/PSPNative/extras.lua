-- API the native backend gains from the wrapper's shared modules and from small additions of its own, loaded
-- after love_psp.lua and shared.lua:
--   SpriteBatch, ParticleSystem (with size, colour and spin curves)    shared core/spritebatch.lua, core/particles.lua
--   points, arc, line style, line join, point size, colour mask, depth mode, wireframe and friends, intersectScissor,
--   getStackDepth, getStats
--   love.filesystem.newFile and the File object, the path getters
--   love.event.wait, love.math.getRandomState / setRandomState
--   do-nothing answers for window, mouse, touch, audio effect, system and keyboard functions a game may probe

local N = native
local g = love.graphics
local noop = function() end

-- ── shared draw objects ──────────────────────────────────────────
lv1lua.load("LOVE-WrapLua/core/drawobject.lua")
lv1lua.load("LOVE-WrapLua/core/spritebatch.lua")
lv1lua.load("LOVE-WrapLua/core/particles.lua")

-- ── graphics state kept for the getters ──────────────────────────
local st = {
    lineStyle = "smooth", lineJoin = "miter", pointSize = 1, wireframe = false, depthMode = "always",
    depthWrite = false, cullMode = "none", winding = "ccw", mask = { true, true, true, true },
}
function g.setLineStyle(s)
    if s ~= "smooth" and s ~= "rough" then error("Invalid line style: " .. tostring(s), 2) end
    st.lineStyle = s
end
function g.getLineStyle() return st.lineStyle end
function g.setLineJoin(j)
    if j ~= "none" and j ~= "miter" and j ~= "bevel" then error("Invalid line join: " .. tostring(j), 2) end
    st.lineJoin = j
end
function g.getLineJoin() return st.lineJoin end
function g.setPointSize(size) st.pointSize = size or 1 end
function g.getPointSize() return st.pointSize end
function g.setWireframe(b) st.wireframe = b and true or false end
function g.isWireframe() return st.wireframe end
function g.setColorMask(r, gr, b, a)
    if r == nil then st.mask = { true, true, true, true } else st.mask = { r and true or false, gr and true or false, b and true or false, a and true or false } end
end
function g.getColorMask() return st.mask[1], st.mask[2], st.mask[3], st.mask[4] end
function g.setDepthMode(mode, write) st.depthMode = mode or "always"; st.depthWrite = write and true or false end
function g.getDepthMode() return st.depthMode, st.depthWrite end
function g.setMeshCullMode(m) st.cullMode = m or "none" end
function g.getMeshCullMode() return st.cullMode end
function g.setFrontFaceWinding(w) st.winding = w or "ccw" end
function g.getFrontFaceWinding() return st.winding end
function g.discard() end
function g.validateShader() return true, "" end
function g.getCanvasFormats() return { normal = true } end
function g.getImageFormats() return { normal = true } end
function g.getTextureTypes() return { ["2d"] = true, volume = false, array = false, cube = false } end

function g.getStackDepth() return N.stack_depth and N.stack_depth() or 0 end
function g.getStats()
    return { drawcalls = 0, drawcallsbatched = 0, canvasswitches = 0, texturememory = N.tex_mem and N.tex_mem() or 0,
             images = 0, canvases = 0, fonts = 0, shaderswitches = 0 }
end

-- intersectScissor(x, y, w, h): shrinks the active scissor to its overlap with the rectangle.
function g.intersectScissor(x, y, w, h)
    local cx, cy, cw, ch = g.getScissor()
    if not cx then return g.setScissor(x, y, w, h) end
    local x1, y1 = math.max(x, cx), math.max(y, cy)
    local x2, y2 = math.min(x + w, cx + cw), math.min(y + h, cy + ch)
    g.setScissor(x1, y1, math.max(0, x2 - x1), math.max(0, y2 - y1))
end

-- ── points ───────────────────────────────────────────────────────
-- points(x1, y1, x2, y2, ...), points({ x1, y1, x2, y2, ... }) or points({ {x, y, r, g, b, a}, ... }); each point
-- is a square of the current point size centred on the position.
function g.points(...)
    local first = ...
    local size = st.pointSize
    local half = size / 2
    local fill = N.fill_rect
    if type(first) ~= "table" then
        local n = select("#", ...)
        local t = { ... }
        for i = 1, n - 1, 2 do fill(t[i] - half, t[i + 1] - half, size, size) end
        return
    end
    if type(first[1]) == "table" then                       -- per-point colour
        local pr, pg, pb, pa = g.getColor()
        for i = 1, #first do
            local p = first[i]
            if p[3] then g.setColor(p[3], p[4], p[5], p[6] or 1) end
            fill(p[1] - half, p[2] - half, size, size)
        end
        g.setColor(pr, pg, pb, pa)
        return
    end
    for i = 1, #first - 1, 2 do fill(first[i] - half, first[i + 1] - half, size, size) end
end

-- ── arc ──────────────────────────────────────────────────────────
-- arc(drawmode, arctype, x, y, radius, angle1, angle2 [, segments]); arctype "pie" (default), "open", "closed".
-- A filled arc of more than half a turn is not convex, so it is drawn as a fan of triangles.
function g.arc(mode, arctype, x, y, radius, a1, a2, segments)
    if type(arctype) == "number" then                       -- arc(mode, x, y, radius, a1, a2 [, segments])
        arctype, x, y, radius, a1, a2, segments = "pie", arctype, x, y, radius, a1, a2
    end
    arctype = arctype or "pie"
    segments = segments or 20
    local pts = {}
    for i = 0, segments do
        local a = a1 + (a2 - a1) * i / segments
        pts[#pts + 1] = x + math.cos(a) * radius
        pts[#pts + 1] = y + math.sin(a) * radius
    end
    if mode == "fill" then
        local n = #pts / 2
        for i = 2, n - 1 do
            g.polygon("fill", { x, y, pts[2 * i - 1], pts[2 * i], pts[2 * i + 1], pts[2 * i + 2] })
        end
        return
    end
    if arctype == "pie" then table.insert(pts, 1, y); table.insert(pts, 1, x) end
    for i = 1, #pts - 3, 2 do g.line(pts[i], pts[i + 1], pts[i + 2], pts[i + 3]) end
    if arctype ~= "open" then g.line(pts[#pts - 1], pts[#pts], pts[1], pts[2]) end
end

-- ── love.filesystem.newFile and File ─────────────────────────────
local fs = love.filesystem
local File = {}; File.__index = File
local function open_path(path, mode)
    if mode == "r" then
        for _, prefix in ipairs({ fs.getSaveDirectory(), "game/" }) do
            local f = io.open(prefix .. path, "rb")
            if f then return f end
        end
        return nil
    end
    local dir = path:match("^(.*)/[^/]+$")
    if dir then fs.createDirectory(dir) end
    local f = io.open(fs.getSaveDirectory() .. path, mode == "a" and "ab" or "wb")
    if not f and mode == "a" then f = io.open(fs.getSaveDirectory() .. path, "wb") end
    return f
end
function fs.newFile(path, mode)
    local file = setmetatable({ _path = path, _mode = "c" }, File)
    if mode then
        local ok, err = file:open(mode)
        if not ok then return nil, err end
    end
    return file
end
function File:open(mode)
    if self._f then return false, "File is already open" end
    if mode ~= "r" and mode ~= "w" and mode ~= "a" then error("Invalid file mode: " .. tostring(mode), 2) end
    local f = open_path(self._path, mode)
    if not f then return false, "Could not open file " .. self._path end
    self._f, self._mode = f, mode
    return true
end
function File:close() if self._f then self._f:close(); self._f = nil; self._mode = "c" end return true end
function File:isOpen() return self._f ~= nil end
function File:getMode() return self._mode end
function File:getFilename() return self._path end
function File:getSize()
    if self._f then
        local here = self._f:seek("cur"); local size = self._f:seek("end"); self._f:seek("set", here); return size
    end
    local info = fs.getInfo(self._path)
    return info and info.size or 0
end
function File:read(a, b)
    if not self._f or self._mode ~= "r" then return nil, "File is not opened for reading" end
    if a == "data" then a = b end
    local data
    if a == nil or a == "all" then data = self._f:read("*a") else data = self._f:read(a) end
    data = data or ""
    return data, #data
end
function File:write(data, size)
    if not self._f or self._mode == "r" then return false, "File is not opened for writing" end
    if type(data) ~= "string" then data = data:getString() end
    if size then data = data:sub(1, size) end
    self._f:write(data)
    return true
end
function File:lines()
    if not self._f then return function() end end
    return function() return self._f:read("*l") end
end
function File:seek(pos) if self._f then return self._f:seek("set", pos) ~= nil end return false end
function File:tell() return self._f and self._f:seek("cur") or -1 end
function File:isEOF()
    if not self._f then return true end
    local here = self._f:seek("cur")
    return here >= self._f:seek("end") and (self._f:seek("set", here) or true)
end
function File:flush() if self._f then self._f:flush() end return true end
function File:setBuffer() return true end
function File:getBuffer() return "none", 0 end
function File:release() self:close(); return true end
function File:type() return "File" end
function File:typeOf(t) return t == "File" or t == "Object" end

fs.getSource = function() return "game/" end
fs.setSource = noop
fs.getUserDirectory = function() return fs.getSaveDirectory() end
fs.getAppdataDirectory = function() return fs.getSaveDirectory() end
fs.areSymlinksEnabled = function() return false end
fs.setSymlinksEnabled = noop
fs.getRequirePath = function() return "?.lua;?/init.lua" end
fs.setRequirePath = noop
fs.getCRequirePath = function() return "" end
fs.setCRequirePath = noop

-- ── event.wait ───────────────────────────────────────────────────
-- Blocks until an event arrives; with no input source other than the pad, that means polling the queue.
function love.event.wait()
    for _ = 1, 600 do
        love.event.pump()
        local name, a, b, c, d, e, f = love.event.poll()()
        if name then return name, a, b, c, d, e, f end
        if love.timer and love.timer.sleep then love.timer.sleep(0.016) end
    end
end

-- ── random state ─────────────────────────────────────────────────
-- The C generator's state cannot be read, and counting draws would put a Lua call in front of every
-- love.math.random, so the state is the seed: setRandomState restarts the sequence from the seed it names.
do
    local seed = 0
    local setseed = love.math.setRandomSeed
    function love.math.setRandomSeed(s, s2)
        seed = (tonumber(s) or 0) + (tonumber(s2) or 0) * 4294967296
        return setseed(seed)
    end
    function love.math.getRandomState() return tostring(seed) end
    function love.math.setRandomState(state)
        local s = tonumber(state)
        if not s then error("Invalid random state: " .. tostring(state), 2) end
        seed = s
        setseed(s)
    end
end

-- ── stubs a game may probe ───────────────────────────────────────
local w = love.window
for _, name in ipairs({ "close", "maximize", "restore", "requestAttention", "setPosition", "setDisplaySleepEnabled" }) do
    w[name] = w[name] or noop
end
w.getPosition = w.getPosition or function() return 0, 0, 1 end
w.hasMouseFocus = w.hasMouseFocus or function() return false end
w.isMaximized = w.isMaximized or function() return false end
w.isMinimized = w.isMinimized or function() return false end
w.isDisplaySleepEnabled = w.isDisplaySleepEnabled or function() return false end
w.getDisplayName = w.getDisplayName or function() return "PSP" end
w.getDisplayOrientation = w.getDisplayOrientation or function() return "landscape" end
w.getIcon = w.getIcon or function() return nil end

local m = love.mouse
m.setX = m.setX or noop
m.setY = m.setY or noop
m.getCursor = m.getCursor or function() return nil end
m.getSystemCursor = m.getSystemCursor or function() return {} end

love.touch = love.touch or {}
love.touch.getPressure = love.touch.getPressure or function() return 0 end

local a = love.audio
for _, name in ipairs({ "getActiveEffects", "setEffect", "setMixWithSystem" }) do a[name] = a[name] or noop end
a.getEffect = a.getEffect or function() return nil end
a.getDopplerScale = a.getDopplerScale or function() return 1 end
a.getMaxSceneEffects = a.getMaxSceneEffects or function() return 0 end
a.getOrientation = a.getOrientation or function() return 0, 0, -1, 0, 1, 0 end
a.getVelocity = a.getVelocity or function() return 0, 0, 0 end

love.system.vibrate = love.system.vibrate or noop
love.system.hasBackgroundMusic = love.system.hasBackgroundMusic or function() return false end
love.keyboard.hasScreenKeyboard = love.keyboard.hasScreenKeyboard or function() return false end
