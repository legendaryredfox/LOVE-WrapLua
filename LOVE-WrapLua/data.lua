love.data = {}

-- Base64 alphabet
local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function b64enc(s)
    return ((s:gsub('.', function(c)
        local r, b = '', c:byte()
        for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i,i) == '1' and 2^(6-i) or 0) end
        return B64:sub(c+1, c+1)
    end) .. ({ '', '==', '=' })[#s % 3 + 1])
end

local function b64dec(s)
    s = s:gsub('[^' .. B64 .. '=]', '')
    return (s:gsub('.', function(c)
        if c == '=' then return '' end
        local r, f = '', (B64:find(c) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

local function hexenc(s)
    return s:gsub('.', function(c) return string.format('%02x', c:byte()) end)
end

local function hexdec(s)
    return s:gsub('..', function(h) return string.char(tonumber(h, 16)) end)
end

function love.data.encode(containerType, format, data, linelength)
    if format == 'base64' then return b64enc(data) end
    if format == 'hex'    then return hexenc(data) end
    return data
end

function love.data.decode(containerType, format, data)
    if format == 'base64' then return b64dec(data) end
    if format == 'hex'    then return hexdec(data) end
    return data
end

function love.data.hash(hashfunc, data)
    -- Full cryptographic hashes require C bindings not available here.
    -- Return a zeroed string of the expected length as a placeholder.
    local lens = { md5=16, sha1=20, sha224=28, sha256=32, sha384=48, sha512=64 }
    return string.rep('\0', lens[hashfunc] or 32)
end

function love.data.compress(containerType, format, rawstring, level)
    -- No compression library available; pass-through.
    return rawstring
end

function love.data.decompress(containerType, format, data)
    return data
end

-- ByteData object
local ByteData = {}
ByteData.__index = ByteData

function love.data.newByteData(size_or_data)
    local bd = setmetatable({}, ByteData)
    if type(size_or_data) == 'number' then
        bd._data = string.rep('\0', size_or_data)
    else
        bd._data = tostring(size_or_data)
    end
    return bd
end

function ByteData:getString()    return self._data end
function ByteData:getSize()      return #self._data end
function ByteData:getPointer()   return nil end  -- no FFI on consoles

function love.data.newDataView(data, offset, size)
    local s = type(data) == 'string' and data or data:getString()
    return love.data.newByteData(s:sub(offset + 1, offset + size))
end

function love.data.pack(fmt, ...)
    if string.pack then return string.pack(fmt, ...) end
    return ''
end

function love.data.unpack(fmt, data, pos)
    if string.unpack then return string.unpack(fmt, data, pos) end
    return nil
end

function love.data.getSize(data)
    if type(data) == 'string'        then return #data end
    if data and data.getSize         then return data:getSize() end
    return 0
end
