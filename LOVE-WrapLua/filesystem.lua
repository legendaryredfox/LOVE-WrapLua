lv1lua.core = lv1lua.core or {}

-- Registry of newFile handles that are currently open. Weak-keyed so a forgotten
-- handle cannot leak (its io finalizer still flushes it), while any handle the
-- game is still holding at quit gets an explicit close (FIX_PLAN T8.3). write /
-- append already close immediately, so only long-lived newFile handles matter.
local _openFiles = setmetatable({}, { __mode = "k" })

-- Closes every still-open newFile handle. Called from love.event.quit before
-- lv1lua.running goes false, so a save is flushed instead of lost when the app
-- or emulator exits (Vita3K #3918 / #3659).
function lv1lua.core.closeOpenFiles()
    local pending = {}
    for f in pairs(_openFiles) do pending[#pending + 1] = f end
    for _, f in ipairs(pending) do f:close() end
end

if lv1lua.isPSP then
    lv1lua.saveloc = "ms0:/PSP/GAME/LOVE-WrapLua/savedata/"
elseif lv1lua.mode == "PS3" then
    lv1lua.saveloc = lv1lua.dataloc.."savedata/"
else
    lv1lua.saveloc = "ux0:/data/"..lv1lua.loveconf.identity.."/savedata/"
end

if lv1lua.mode == "OneLua" then
    if not files.exists(lv1lua.saveloc) then
        files.mkdir(lv1lua.saveloc)
    end
elseif lv1lua.mode == "lpp-vita" then
    if not System.doesDirExist(lv1lua.saveloc) then
        System.createDirectory("ux0:/data/"..lv1lua.loveconf.identity)
        System.createDirectory(lv1lua.saveloc)
    end
end

-- ── Paths, stat and listing (FIX_PLAN T6.3) ─────────────────────
-- A game-relative name lives in one of two places: the writable save directory
-- (checked first, so a saved file shadows the shipped one, as LOVE does) or the
-- read-only game directory.
local function savePath(file) return lv1lua.saveloc .. file end
local function gamePath(file) return lv1lua.dataloc .. "game/" .. file end

local function resolve(file)
    if lv1lua.exists(savePath(file)) then return savePath(file), true end
    if lv1lua.exists(gamePath(file)) then return gamePath(file), false end
    return nil
end

-- Directory test. Each SDK exposes a different subset, so the native call is
-- probed; the fallback is "it exists but cannot be opened as a byte stream",
-- which is what a directory looks like through the console io layers.
local function isDirPath(path)
    if lv1lua.mode == "lpp-vita" and type(System) == "table"
       and type(System.doesDirExist) == "function" then
        return System.doesDirExist(path) and true or false
    end
    if lv1lua.mode == "OneLua" and type(files) == "table"
       and type(files.isdir) == "function" then
        return files.isdir(path) and true or false
    end
    local f = io.open(path, "rb")
    -- A path that exists (the caller checked) but will not open is a directory
    -- on the console io layers.
    if not f then return true end
    -- Where it does open, a directory still refuses to be read: the read fails
    -- with an error, while an empty file just reports end of data.
    local byte, err = f:read(1)
    f:close()
    return byte == nil and err ~= nil
end

-- Byte size of a real file, or nil when it cannot be measured.
local function fileSize(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local ok, size = pcall(f.seek, f, "end")
    f:close()
    if ok and type(size) == "number" then return size end
    return nil
end

local function listNative(dir)
    if lv1lua.mode == "OneLua" and type(files) == "table" and files.list then
        return files.list(dir)
    end
    if lv1lua.mode == "lpp-vita" and type(System) == "table" and System.listDirectory then
        local out = {}
        for _, entry in ipairs(System.listDirectory(dir) or {}) do
            out[#out + 1] = (type(entry) == "table" and entry.name) or entry
        end
        return out
    end
    return nil
end

function love.filesystem.read(file, size)
    local path = resolve(file)
    if not path then return nil, "File not found: "..file end
    local f = io.open(path, "rb")
    if not f then return nil, "Cannot open "..path end
    local contents = size and f:read(size) or f:read("*a")
    f:close()
    return contents, contents and #contents or 0
end

function love.filesystem.write(file, data, size)
    local mode = lv1lua.mode == "PS3" and "w+" or "wb"
    local f = io.open(lv1lua.saveloc..file, mode)
    if not f then return false, "Cannot open for writing" end
    local content = size and string.sub(data, 1, size) or data
    local ok = f:write(content)
    f:close()
    return ok ~= nil, ok == nil and "Write error" or nil
end

function love.filesystem.append(file, data, size)
    local f = io.open(lv1lua.saveloc..file, "ab")
    if not f then return false, "Cannot open for appending" end
    local content = size and string.sub(data, 1, size) or data
    local ok = f:write(content)
    f:close()
    return ok ~= nil
end

function love.filesystem.isFile(file)
    local path = resolve(file)
    return path ~= nil and not isDirPath(path)
end

function love.filesystem.isDirectory(path)
    local full = resolve(path)
    return full ~= nil and isDirPath(full)
end

-- LOVE's getInfo. `size` is the real byte count for a file; `modtime` stays 0
-- because no SDK here exposes a file date, and inventing one would break the
-- "newer than" comparisons games use it for.
function love.filesystem.getInfo(file, filtertype)
    local path = resolve(file)
    if not path then return nil end

    local ftype = isDirPath(path) and "directory" or "file"
    if filtertype and filtertype ~= ftype then return nil end

    return { type    = ftype,
             size    = ftype == "file" and (fileSize(path) or 0) or 0,
             modtime = 0 }
end

function love.filesystem.load(file)
    return loadfile(resolve(file) or gamePath(file))
end

function love.filesystem.remove(file)
    if lv1lua.mode == "OneLua" then
        return files.delete(lv1lua.saveloc..file)
    elseif lv1lua.mode == "lpp-vita" then
        return System.deleteFile(lv1lua.saveloc..file)
    end
    return false
end

function love.filesystem.createDirectory(path)
    local full = lv1lua.saveloc..path
    if lv1lua.mode == "OneLua" then
        if not files.exists(full) then files.mkdir(full) end
        return true
    elseif lv1lua.mode == "lpp-vita" then
        if not System.doesDirExist(full) then System.createDirectory(full) end
        return true
    end
    return false
end

-- Both roots are listed and merged: a game writes into the save directory and
-- then expects to find those files next to the ones it shipped. Duplicates
-- collapse (the save copy shadows the shipped one, as in read), and the result
-- is sorted so a game that renders a file list gets a stable order.
function love.filesystem.getDirectoryItems(path)
    local seen, items = {}, {}
    for _, dir in ipairs({ gamePath(path), savePath(path) }) do
        for _, name in ipairs(listNative(dir) or {}) do
            if name ~= "" and name ~= "." and name ~= ".." and not seen[name] then
                seen[name] = true
                items[#items + 1] = name
            end
        end
    end
    table.sort(items)
    return items
end

function love.filesystem.lines(file)
    local content = love.filesystem.read(file)
    if not content then return function() end end
    local lines = {}
    for line in (content.."\n"):gmatch("([^\n]*)\n") do
        lines[#lines+1] = line
    end
    local i = 0
    return function()
        i = i + 1
        return lines[i]
    end
end

function love.filesystem.newFile(filename, mode)
    local file = { _name = filename, _mode = mode or "c" }
    function file:open(m)
        self._mode = m
        local luaMode = ({r="rb", w="wb", a="ab"})[m] or "rb"
        local path = lv1lua.saveloc..self._name
        if m == "r" and not lv1lua.exists(path) then
            path = lv1lua.dataloc.."game/"..self._name
        end
        self._handle = io.open(path, luaMode)
        if self._handle then _openFiles[self] = true end
        return self._handle ~= nil
    end
    function file:read(size)
        if not self._handle then return nil end
        return size and self._handle:read(size) or self._handle:read("*a")
    end
    function file:write(data) if self._handle then self._handle:write(data) end end
    function file:seek(pos)   if self._handle then self._handle:seek("set", pos) end end
    function file:tell()      return self._handle and self._handle:seek() or 0 end
    function file:close()
        if self._handle then self._handle:close(); self._handle = nil end
        _openFiles[self] = nil
    end
    function file:getSize()
        if not self._handle then return 0 end
        local cur = self._handle:seek()
        local sz  = self._handle:seek("end")
        self._handle:seek("set", cur)
        return sz
    end
    function file:isOpen()   return self._handle ~= nil end
    function file:getFilename() return self._name end
    function file:getMode()  return self._mode end
    return file
end

function love.filesystem.newFileData(contents, name)
    return { _contents = contents, _name = name,
        getString  = function(self) return self._contents end,
        getSize    = function(self) return #self._contents end,
        getFilename= function(self) return self._name end,
    }
end

function love.filesystem.mount(archive, mountpoint, appendToPath)
    return false  -- not supported
end

function love.filesystem.unmount(archive)
    return false
end

function love.filesystem.getIdentity()
    return lv1lua.loveconf.identity or "LOVE-WrapLua"
end

function love.filesystem.setIdentity(name)
    lv1lua.loveconf.identity = name
end

function love.filesystem.getWorkingDirectory()
    return lv1lua.dataloc.."game/"
end

function love.filesystem.getRealDirectory(file)
    local _, inSave = resolve(file)
    if inSave then return lv1lua.saveloc end
    return lv1lua.dataloc.."game/"
end

function love.filesystem.getSourceBaseDirectory()
    return lv1lua.dataloc
end

function love.filesystem.getUserDirectory()    return lv1lua.saveloc end
function love.filesystem.getSaveDirectory()    return lv1lua.saveloc end
function love.filesystem.getAppdataDirectory() return lv1lua.saveloc end

function love.filesystem.isFused()   return true  end
function love.filesystem.areSymlinksEnabled() return false end
function love.filesystem.setSymlinksEnabled() end
