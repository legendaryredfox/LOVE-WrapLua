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

-- ── Vendored pure-Lua crypto / compression ───────────────────────
-- sha2.lua (MIT) and LibDeflate.lua (zlib) are loaded lazily and cached: a
-- game that never hashes or compresses pays no parse cost, and both libraries
-- are pure Lua and slow on-device, so callers should cache their own results.
local _sha, _deflate
local function sha()
    _sha = _sha or lv1lua.loadOnce('LOVE-WrapLua/vendor/sha2.lua')
    return _sha
end
local function deflate()
    _deflate = _deflate or lv1lua.loadOnce('LOVE-WrapLua/vendor/LibDeflate.lua')
    return _deflate
end

-- Coerce a ByteData/string argument down to a plain Lua string.
local function tostr(v)
    if type(v) == 'string' then return v end
    if type(v) == 'table' and v.getString then return v:getString() end
    return tostring(v)
end

local HASH = {
    md5 = 'md5', sha1 = 'sha1', sha224 = 'sha224',
    sha256 = 'sha256', sha384 = 'sha384', sha512 = 'sha512',
}

-- love.data.hash(hashFunction, data) → raw-byte digest (LÖVE returns the raw
-- message digest, not hex). sha2.lua emits lowercase hex, so unhex it.
function love.data.hash(hashfunc, data)
    local fn = HASH[hashfunc]
    if not fn then
        error("love.data.hash: unsupported hash '" .. tostring(hashfunc) .. "'", 2)
    end
    return hexdec(sha()[fn](tostr(data)))
end

local _warnedFmt = {}
local function warnFmt(format)
    if _warnedFmt[format] then return end
    _warnedFmt[format] = true
    if lv1lua.util and lv1lua.util.warn then
        lv1lua.util.warn("love.data.compress: format '" .. tostring(format)
            .. "' has no encoder on this backend; using 'deflate'")
    end
end

-- Boxes a result string as a ByteData when the caller asked for a 'data'
-- container, matching LÖVE's return-type contract; otherwise returns the string.
local function box(containerType, s)
    if containerType == 'data' then return love.data.newByteData(s) end
    return s
end

-- love.data.compress(container, format, rawstring, level)
-- Real DEFLATE/zlib via LibDeflate. LÖVE's 'gzip' and 'lz4' formats have no
-- encoder here; they fall back to 'deflate' (round-trips within this wrapper,
-- but is not byte-compatible with those two desktop formats — see vendor notes).
function love.data.compress(containerType, format, rawstring, level)
    format = format or 'deflate'
    local D, cfg = deflate(), nil
    if type(level) == 'number' and level >= 1 and level <= 9 then
        cfg = { level = level }
    end
    if format == 'zlib' then
        return box(containerType, D:CompressZlib(tostr(rawstring), cfg))
    end
    if format ~= 'deflate' then warnFmt(format) end
    return box(containerType, D:CompressDeflate(tostr(rawstring), cfg))
end

-- love.data.decompress(container, format, data). `format` must match what
-- compress produced ('zlib' or 'deflate'/'gzip'/'lz4' → deflate here).
function love.data.decompress(containerType, format, data)
    local D = deflate()
    local raw = tostr(data)
    local out = (format == 'zlib') and D:DecompressZlib(raw)
                                    or  D:DecompressDeflate(raw)
    return box(containerType, out or '')
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
