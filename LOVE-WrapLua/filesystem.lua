lv1lua.core = lv1lua.core or {}
-- Files go through the core/fileio.lua seam (lpp-3ds has no io.open).
local function fileio() return lv1lua.fileio or {} end
local function open(path, mode) return (fileio().open or io.open)(path, mode) end

-- Registry of newFile handles that are currently open. Weak-keyed so a forgotten
-- handle cannot leak (its io finalizer still flushes it), while any handle the
-- game is still holding at quit gets an explicit close. write /
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

-- The save directory follows the identity where the console keeps per-title
-- data (Vita, 3DS), as LOVE's does; the PSP and PS3 builds keep one folder
-- beside the game, which a single-game install does not need to split.
local function saveDirectory(identity)
    if lv1lua.isPSP then return "ms0:/PSP/GAME/LOVE-WrapLua/savedata/" end
    if lv1lua.mode == "PS3" then return lv1lua.dataloc .. "savedata/" end
    -- Not under dataloc: a 3DS CIA runs from romfs:/, which is read-only.
    if lv1lua.mode == "3DS" then return "/3ds/data/" .. identity .. "/" end
    return "ux0:/data/" .. identity .. "/savedata/"
end

local function makeSaveDirectory()
    if lv1lua.mode == "OneLua" then
        if not files.exists(lv1lua.saveloc) then files.mkdir(lv1lua.saveloc) end
    elseif lv1lua.mode == "lpp-vita" then
        if not System.doesDirExist(lv1lua.saveloc) then
            System.createDirectory("ux0:/data/" .. lv1lua.loveconf.identity)
            System.createDirectory(lv1lua.saveloc)
        end
    elseif fileio().mkdir then
        if lv1lua.mode == "3DS" then fileio().mkdir("/3ds/data/") end
        fileio().mkdir(lv1lua.saveloc)
    end
end

lv1lua.saveloc = saveDirectory(lv1lua.loveconf.identity)
makeSaveDirectory()

-- ── Paths, stat and listing ──────────────────────────────────────
-- A game-relative name lives in one of two places: the writable save directory
-- (checked first, so a saved file shadows the shipped one, as LOVE does) or the
-- read-only game directory.
local function savePath(file) return lv1lua.saveloc .. file end
local function gamePath(file) return lv1lua.dataloc .. "game/" .. file end

-- Each native stat or listing costs about 11 ms on OneLua in PPSSPP, so answers are kept. The game
-- directory is read-only and its answers last for good; the save directory changes only through this
-- module, which drops every save answer whenever it writes, removes or creates something.
local gameMeta, saveMeta, gameLists, saveLists = {}, {}, {}, {}

local function dropSaveCache()
    if next(saveMeta) or next(saveLists) then saveMeta, saveLists = {}, {} end
end
lv1lua.core.dropFilesystemCache = dropSaveCache

local function meta(path, inSave)
    local m = inSave and saveMeta or gameMeta
    local e = m[path]
    if not e then
        e = { exists = lv1lua.exists(path) and true or false }
        m[path] = e
    end
    return e
end

local mountsFront, mountsBack = {}, {}

-- Path of `file` inside a mounted directory, or nil when the file is outside the mount point.
local function mountedPath(m, file)
    local point = m.point
    if point == "" then
        if file == "" then return m.root end
        return m.root .. "/" .. file
    end
    if file == point then return m.root end
    if file:sub(1, #point + 1) == point .. "/" then
        return m.root .. "/" .. file:sub(#point + 2)
    end
    return nil
end

local function resolveMounted(list, file)
    for i = 1, #list do
        local m = list[i]
        local path = mountedPath(m, file)
        if path and meta(path, m.inSave).exists then return path, m.inSave, m end
    end
end

local function resolve(file)
    local sp = savePath(file)
    if meta(sp, true).exists then return sp, true end
    local path, inSave, m = resolveMounted(mountsFront, file)
    if path then return path, inSave, m end
    local gp = gamePath(file)
    if meta(gp, false).exists then return gp, false end
    path, inSave, m = resolveMounted(mountsBack, file)
    if path then return path, inSave, m end
    return nil
end

-- Directory test. Each SDK exposes a different subset, so the native call is
-- probed; the fallback is "it exists but cannot be opened as a byte stream",
-- which is what a directory looks like through the console io layers.
local function probeDir(path)
    if fileio().isDir then return fileio().isDir(path) end
    if lv1lua.mode == "lpp-vita" and type(System) == "table"
       and type(System.doesDirExist) == "function" then
        return System.doesDirExist(path) and true or false
    end
    if lv1lua.mode == "OneLua" and type(files) == "table"
       and type(files.isdir) == "function" then
        return files.isdir(path) and true or false
    end
    local f = open(path, "rb")
    -- A path that exists (the caller checked) but will not open is a directory
    -- on the console io layers.
    if not f then return true end
    -- Where it does open, a directory still refuses to be read: the read fails
    -- with an error, while an empty file just reports end of data.
    local byte, err = f:read(1)
    f:close()
    return byte == nil and err ~= nil
end

-- `inSave` selects the cache the answer lives in; callers got it from resolve.
local function isDirPath(path, inSave)
    local e = meta(path, inSave)
    if e.dir == nil then e.dir = probeDir(path) and true or false end
    return e.dir
end

-- Byte size of a real file, or nil when it cannot be measured.
local function probeSize(path)
    local f = open(path, "rb")
    if not f then return nil end
    local ok, size = pcall(f.seek, f, "end")
    f:close()
    if ok and type(size) == "number" then return size end
    return nil
end

local function fileSize(path, inSave)
    local e = meta(path, inSave)
    if e.size == nil then e.size = probeSize(path) or false end
    return e.size or nil
end

local function listNative(dir)
    if fileio().list then return fileio().list(dir) end
    if lv1lua.mode == "OneLua" and type(files) == "table" and files.list then
        -- The SDK returns one table per entry ({ name, path, ext, size, ... }),
        -- not a list of names.
        local out = {}
        for _, entry in ipairs(files.list(dir) or {}) do
            out[#out + 1] = (type(entry) == "table" and entry.name) or entry
        end
        return out
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
    local f = open(path, "rb")
    if not f then return nil, "Cannot open "..path end
    local contents = size and f:read(size) or f:read("*a")
    f:close()
    return contents, contents and #contents or 0
end

function love.filesystem.write(file, data, size)
    local mode = lv1lua.mode == "PS3" and "w+" or "wb"
    dropSaveCache()
    local f = open(lv1lua.saveloc..file, mode)
    if not f then return false, "Cannot open for writing" end
    local content = size and string.sub(data, 1, size) or data
    local ok = f:write(content)
    f:close()
    return ok ~= nil, ok == nil and "Write error" or nil
end

function love.filesystem.append(file, data, size)
    dropSaveCache()
    local f = open(lv1lua.saveloc..file, "ab")
    if not f then return false, "Cannot open for appending" end
    local content = size and string.sub(data, 1, size) or data
    local ok = f:write(content)
    f:close()
    return ok ~= nil
end

function love.filesystem.isFile(file)
    local path, inSave = resolve(file)
    return path ~= nil and not isDirPath(path, inSave)
end

function love.filesystem.isDirectory(path)
    local full, inSave = resolve(path)
    return full ~= nil and isDirPath(full, inSave)
end

-- LOVE's getInfo. `size` is the real byte count for a file; `modtime` stays 0
-- because no SDK here exposes a file date, and inventing one would break the
-- "newer than" comparisons games use it for.
function love.filesystem.getInfo(file, filtertype)
    local path, inSave = resolve(file)
    if not path then return nil end

    local ftype = isDirPath(path, inSave) and "directory" or "file"
    if filtertype and filtertype ~= ftype then return nil end

    return { type    = ftype,
             size    = ftype == "file" and (fileSize(path, inSave) or 0) or 0,
             modtime = 0 }
end

function love.filesystem.load(file)
    return (fileio().loadfile or loadfile)(resolve(file) or gamePath(file))
end

function love.filesystem.remove(file)
    dropSaveCache()
    if lv1lua.mode == "OneLua" then
        return files.delete(lv1lua.saveloc..file)
    elseif lv1lua.mode == "lpp-vita" then
        return System.deleteFile(lv1lua.saveloc..file)
    elseif fileio().remove then
        return fileio().remove(lv1lua.saveloc..file)
    end
    return false
end

function love.filesystem.createDirectory(path)
    dropSaveCache()
    local full = lv1lua.saveloc..path
    if lv1lua.mode == "OneLua" then
        if not files.exists(full) then files.mkdir(full) end
        return true
    elseif lv1lua.mode == "lpp-vita" then
        if not System.doesDirExist(full) then System.createDirectory(full) end
        return true
    elseif fileio().mkdir then
        return fileio().mkdir(full)
    end
    return false
end

-- Both roots are listed and merged: a game writes into the save directory and
-- then expects to find those files next to the ones it shipped. Duplicates
-- collapse (the save copy shadows the shipped one, as in read), and the result
-- is sorted so a game that renders a file list gets a stable order.
local function listCached(path, inSave)
    local lists = inSave and saveLists or gameLists
    local key = "\0" .. path
    local list = lists[key]
    if not list then
        list = listNative(path) or {}
        lists[key] = list
    end
    return list
end

local function mountContribution(m, path, out)
    local point = m.point
    if point == "" or path == point or path:sub(1, #point + 1) == point .. "/" then
        local sub = point == "" and path or path:sub(#point + 2)
        local native = sub == "" and m.root or (m.root .. "/" .. sub)
        if meta(native, m.inSave).exists then
            out[#out + 1] = listCached(native, m.inSave)
        end
    elseif point ~= "" and (path == "" or point:sub(1, #path + 1) == path .. "/") then
        local rest = path == "" and point or point:sub(#path + 2)
        out[#out + 1] = { (rest:match("^[^/]+")) }
    end
end

function love.filesystem.getDirectoryItems(path)
    local game, save = gameLists[path], saveLists[path]
    if not game then
        game = listNative(gamePath(path)) or {}
        gameLists[path] = game
    end
    if not save then
        save = listNative(savePath(path)) or {}
        saveLists[path] = save
    end
    local sources = { game, save }
    for i = 1, #mountsFront do mountContribution(mountsFront[i], path, sources) end
    for i = 1, #mountsBack do mountContribution(mountsBack[i], path, sources) end
    local seen, items = {}, {}
    for _, dir in ipairs(sources) do
        for _, name in ipairs(dir) do
            if name ~= "" and name ~= "." and name ~= ".." and not seen[name] then
                seen[name] = true
                items[#items + 1] = name
            end
        end
    end
    table.sort(items)
    return items
end

-- LOVE yields each line without its terminator ("\n" or "\r\n") and no empty
-- line after a final newline.
function love.filesystem.lines(file)
    local content = love.filesystem.read(file)
    if not content then return function() end end
    if content:sub(-1) ~= "\n" then content = content .. "\n" end
    local lines = {}
    for line in content:gmatch("([^\n]*)\n") do
        lines[#lines+1] = (line:gsub("\r$", ""))
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
        if m ~= "r" then dropSaveCache() end
        self._handle = open(path, luaMode)
        if self._handle then _openFiles[self] = true end
        self._writes = m ~= "r"
        return self._handle ~= nil
    end
    function file:read(size)
        if not self._handle then return nil end
        return size and self._handle:read(size) or self._handle:read("*a")
    end
    function file:write(data)
        if self._handle then
            if self._writes then dropSaveCache() end
            self._handle:write(data)
        end
    end
    function file:seek(pos)   if self._handle then self._handle:seek("set", pos) end end
    function file:tell()      return self._handle and self._handle:seek() or 0 end
    function file:close()
        if self._handle then self._handle:close(); self._handle = nil end
        if self._writes then dropSaveCache() end
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
    -- LOVE opens the file straight away when a mode is given; "c" is closed.
    if mode and mode ~= "c" then file:open(mode) end
    return file
end

function love.filesystem.newFileData(contents, name)
    return { _contents = contents, _name = name,
        getString  = function(self) return self._contents end,
        getSize    = function(self) return #self._contents end,
        getFilename= function(self) return self._name end,
    }
end

local function normalisePoint(point)
    point = (point or "/"):gsub("\\", "/")
    point = point:gsub("^/+", ""):gsub("/+$", "")
    return point
end

local function removeMount(list, archive)
    local removed = false
    for i = #list, 1, -1 do
        if list[i].archive == archive then
            table.remove(list, i)
            removed = true
        end
    end
    return removed
end

-- Only directories can be mounted: no SDK here ships an archive reader. The directory is looked up
-- in the save folder, then in the game folder.
function love.filesystem.mount(archive, mountpoint, appendToPath)
    if type(archive) ~= "string" then
        error("Bad argument #1 to 'mount' (string expected)", 2)
    end
    local clean = archive:gsub("/+$", "")
    local root, inSave
    if meta(savePath(clean), true).exists then
        root, inSave = savePath(clean), true
    elseif meta(gamePath(clean), false).exists then
        root, inSave = gamePath(clean), false
    else
        return false
    end
    if not isDirPath(root, inSave) then return false end
    removeMount(mountsFront, archive)
    removeMount(mountsBack, archive)
    local entry = { archive = archive, root = root, inSave = inSave, point = normalisePoint(mountpoint) }
    if appendToPath then
        mountsBack[#mountsBack + 1] = entry
    else
        table.insert(mountsFront, 1, entry)
    end
    return true
end

function love.filesystem.unmount(archive)
    local a = removeMount(mountsFront, archive)
    local b = removeMount(mountsBack, archive)
    return a or b
end

function love.filesystem.getIdentity()
    return lv1lua.loveconf.identity or "LOVE-WrapLua"
end

function love.filesystem.setIdentity(name)
    lv1lua.loveconf.identity = name
    lv1lua.saveloc = saveDirectory(name)
    dropSaveCache()
    makeSaveDirectory()
end

function love.filesystem.getWorkingDirectory()
    return lv1lua.dataloc.."game/"
end

function love.filesystem.getRealDirectory(file)
    local _, inSave, m = resolve(file)
    if m then return m.root end
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
