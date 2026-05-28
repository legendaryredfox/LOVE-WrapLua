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

function love.filesystem.read(file, size)
    local path
    if lv1lua.exists(lv1lua.saveloc..file) then
        path = lv1lua.saveloc..file
    elseif lv1lua.exists(lv1lua.dataloc.."game/"..file) then
        path = lv1lua.dataloc.."game/"..file
    else
        return nil, "File not found: "..file
    end
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
    local ok = f:write(content.."\n")
    f:close()
    return ok ~= nil
end

function love.filesystem.isFile(file)
    return lv1lua.exists(lv1lua.saveloc..file)
        or lv1lua.exists(lv1lua.dataloc.."game/"..file)
end

function love.filesystem.isDirectory(path)
    if lv1lua.mode == "OneLua" then
        return files.exists(lv1lua.saveloc..path)
    elseif lv1lua.mode == "lpp-vita" then
        return System.doesDirExist(lv1lua.saveloc..path)
            or System.doesDirExist(lv1lua.dataloc.."game/"..path)
    end
    return false
end

function love.filesystem.getInfo(file, filtertype)
    local inSave = lv1lua.exists(lv1lua.saveloc..file)
    local inGame = lv1lua.exists(lv1lua.dataloc.."game/"..file)
    if not inSave and not inGame then return nil end
    -- Determine type (file vs directory) when possible
    local ftype = "file"
    if lv1lua.mode == "lpp-vita" then
        local fullpath = inSave and (lv1lua.saveloc..file) or (lv1lua.dataloc.."game/"..file)
        if System.doesDirExist(fullpath) then ftype = "directory" end
    end
    if filtertype and filtertype ~= ftype then return nil end
    return { type = ftype, size = 0, modtime = 0 }
end

function love.filesystem.load(file)
    local path
    if lv1lua.exists(lv1lua.saveloc..file) then
        path = lv1lua.saveloc..file
    else
        path = lv1lua.dataloc.."game/"..file
    end
    return loadfile(path)
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

function love.filesystem.getDirectoryItems(path)
    local items = {}
    if lv1lua.mode == "OneLua" then
        local list = files.list(lv1lua.dataloc.."game/"..path)
        if list then
            for _, entry in ipairs(list) do
                items[#items+1] = entry
            end
        end
    elseif lv1lua.mode == "lpp-vita" then
        local list = System.listDirectory(lv1lua.dataloc.."game/"..path)
        if list then
            for _, entry in ipairs(list) do
                items[#items+1] = entry.name or entry
            end
        end
    end
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
        return self._handle ~= nil
    end
    function file:read(size)
        if not self._handle then return nil end
        return size and self._handle:read(size) or self._handle:read("*a")
    end
    function file:write(data) if self._handle then self._handle:write(data) end end
    function file:seek(pos)   if self._handle then self._handle:seek("set", pos) end end
    function file:tell()      return self._handle and self._handle:seek() or 0 end
    function file:close()     if self._handle then self._handle:close(); self._handle = nil end end
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
    if lv1lua.exists(lv1lua.saveloc..file) then return lv1lua.saveloc end
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
