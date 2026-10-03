-- lpp-3ds file adapter for core/fileio.lua.
--
-- The player rebinds io.open / io.read / io.write / io.close to
-- System.openFile(path, FREAD | FWRITE | FCREATE) and friends, which work on
-- an integer handle with explicit offsets. This wraps them in the small file
-- object the shared modules expect.
--
-- Native quirks handled here:
--   FCREATE opens with FS_OPEN_CREATE | FS_OPEN_WRITE, which does not truncate,
--     so "w" deletes the old file first.
--   System.readFile(h, offset, size) always returns `size` bytes, so reads are
--     clamped to the file size.
--   System.doesFileExist opens the path as a file, so it is false for a
--     directory; directories are found by listing the parent.
--   loadfile goes through the standard C fopen, which the player does not set
--     up for SD paths (it patches dofile for the same reason), so chunks are
--     read through the adapter and compiled from the string.

local fileio = {}
lv1lua.fileio = fileio

local File = {}
File.__index = File

function File:read(fmt)
    if not self.h then return nil end
    local left = self.size - self.pos
    local n
    if fmt == nil or fmt == "*a" or fmt == "a" then
        n = left
    elseif type(fmt) == "number" then
        if left <= 0 then return nil end
        n = math.min(fmt, left)
    else
        error("lpp-3ds file adapter: unsupported read format " .. tostring(fmt), 2)
    end
    if n <= 0 then return "" end
    local data = System.readFile(self.h, self.pos, n)
    self.pos = self.pos + n
    return data
end

function File:write(...)
    if not self.h then return nil, "file is closed" end
    for i = 1, select("#", ...) do
        local s = tostring((select(i, ...)))
        if #s > 0 then
            System.writeFile(self.h, self.pos, s, #s)
            self.pos = self.pos + #s
            if self.pos > self.size then self.size = self.pos end
        end
    end
    return self
end

function File:seek(whence, offset)
    whence, offset = whence or "cur", offset or 0
    local base = (whence == "set" and 0) or (whence == "end" and self.size) or self.pos
    local pos = base + offset
    if pos < 0 then return nil, "invalid seek" end
    self.pos = pos
    return pos
end

function File:close()
    if self.h then System.closeFile(self.h); self.h = nil end
    return true
end

local function splitParent(path)
    local trimmed = string.gsub(path, "/+$", "")
    local parent, name = string.match(trimmed, "^(.*/)([^/]+)$")
    return parent, name
end

function fileio.isDir(path)
    local parent, name = splitParent(path)
    if not parent then return false end
    for _, entry in ipairs(System.listDirectory(parent) or {}) do
        if entry.name == name then return entry.directory and true or false end
    end
    return false
end

function fileio.exists(path)
    return System.doesFileExist(path) or fileio.isDir(path)
end

function fileio.list(dir)
    local out = {}
    for _, entry in ipairs(System.listDirectory(dir) or {}) do
        out[#out + 1] = entry.name
    end
    return out
end

function fileio.mkdir(path)
    if not fileio.isDir(path) then System.createDirectory(path) end
    return true
end

function fileio.remove(path)
    if fileio.isDir(path) then System.deleteDirectory(path) else System.deleteFile(path) end
    return true
end

function fileio.open(path, mode)
    local kind = string.sub(mode or "r", 1, 1)
    local exists = System.doesFileExist(path)
    local native
    if kind == "r" then
        if not exists then return nil, path .. ": No such file or directory" end
        native = FREAD
    elseif kind == "w" then
        if exists then System.deleteFile(path) end
        native = FCREATE
    elseif kind == "a" then
        native = exists and FWRITE or FCREATE
    else
        return nil, "unsupported mode " .. tostring(mode)
    end

    local ok, h = pcall(System.openFile, path, native)
    if not ok then return nil, tostring(h) end
    local f = setmetatable({ h = h, pos = 0, size = System.getFileSize(h) }, File)
    if kind == "a" then f.pos = f.size end
    return f
end

function fileio.loadfile(path)
    local f, err = fileio.open(path, "r")
    if not f then return nil, err end
    local src = f:read("*a")
    f:close()
    return (loadstring or load)(src, "@" .. path)
end
