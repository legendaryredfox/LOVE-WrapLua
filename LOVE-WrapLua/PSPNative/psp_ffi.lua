-- Minimal pure-Lua shim of LuaJIT's `ffi` for the PSP backend (Lua 5.1 PUC has no FFI).
-- Covers what LÖVE games commonly use for serialisation and small C structs:
--   ffi.new("uint8_t[?]", n) / ("int16_t[1]", v) / struct ctype; ffi.cast("uint8_t*", data);
--   ffi.copy, ffi.string, ffi.sizeof, ffi.istype, ffi.typeof, ffi.cdef (typedef struct), ffi.metatype,
--   ffi.fill, ffi.os / ffi.arch; plus `jit` and `table.new/clear` stubs.
-- Arrays are byte-backed (little endian) so copy/string/pointer arithmetic behave like C.
-- Struct instances are plain tables with named fields (no byte layout; `ffi.copy` on them is unsupported).
local floor, abs, huge = math.floor, math.abs, math.huge
local char, concat, unpack = string.char, table.concat, unpack

local ffi = { os = "Other", arch = "mips" }

-- scalar types: size, kind (u = unsigned int, s = signed int, f = float)
local scalars = {
    int8_t = { 1, "s" }, uint8_t = { 1, "u" }, int16_t = { 2, "s" }, uint16_t = { 2, "u" },
    int32_t = { 4, "s" }, uint32_t = { 4, "u" }, float = { 4, "f" }, double = { 8, "f" },
    char = { 1, "s" }, ["unsigned char"] = { 1, "u" }, ["signed char"] = { 1, "s" },
    short = { 2, "s" }, ["unsigned short"] = { 2, "u" }, int = { 4, "s" }, ["unsigned int"] = { 4, "u" },
    long = { 4, "s" }, ["unsigned long"] = { 4, "u" }, bool = { 1, "u" },
}
local function norm(name) return (name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")) end

local function pow2(n) return 2 ^ n end

-- encode a scalar to little-endian bytes appended to t at index i
local function put(t, i, v, size, kind)
    if kind == "f" then
        local ebits, mbits = size == 4 and 8 or 11, size == 4 and 23 or 52
        local bias = pow2(ebits - 1) - 1
        local sign = 0
        if v < 0 or (v == 0 and 1 / v < 0) then sign = 1; v = -v end
        local e, m
        if v ~= v then e, m = pow2(ebits) - 1, pow2(mbits - 1)
        elseif v == huge then e, m = pow2(ebits) - 1, 0
        elseif v == 0 then e, m = 0, 0
        else
            local fr, ex = math.frexp(v)  -- v = fr * 2^ex, fr in [0.5,1)
            e = ex - 1 + bias
            if e <= 0 then m = floor(v / pow2(1 - bias) * pow2(mbits)); e = 0       -- subnormal
            elseif e >= pow2(ebits) - 1 then e, m = pow2(ebits) - 1, 0
            else m = floor((fr * 2 - 1) * pow2(mbits) + 0.5) end
            if m >= pow2(mbits) then m = 0; e = e + 1 end
        end
        -- bit array, LSB first: mantissa, exponent, sign
        local bits, n = {}, 0
        for _ = 1, mbits do bits[n] = m % 2; m = floor(m / 2); n = n + 1 end
        for _ = 1, ebits do bits[n] = e % 2; e = floor(e / 2); n = n + 1 end
        bits[n] = sign
        for k = 0, size - 1 do
            local b, w = 0, 1
            for j = 0, 7 do b = b + bits[k * 8 + j] * w; w = w * 2 end
            t[i + k] = b
        end
        return
    end
    v = floor(v)
    local range = pow2(size * 8)
    v = v % range
    for k = 0, size - 1 do t[i + k] = v % 256; v = floor(v / 256) end
end

local function get(t, i, size, kind)
    if kind == "f" then
        local ebits, mbits = size == 4 and 8 or 11, size == 4 and 23 or 52
        local bias = pow2(ebits - 1) - 1
        local sign = floor((t[i + size - 1] or 0) / 128)
        local mant, expv = 0, 0
        for k = 0, size - 1 do
            local by = t[i + k] or 0
            for bit = 0, 7 do
                local pos = k * 8 + bit
                local x = by % 2; by = floor(by / 2)
                if pos < mbits then mant = mant + x * pow2(pos)
                elseif pos < mbits + ebits then expv = expv + x * pow2(pos - mbits) end
            end
        end
        local v
        if expv == pow2(ebits) - 1 then v = (mant == 0) and huge or (0 / 0)
        elseif expv == 0 then v = mant / pow2(mbits) * pow2(1 - bias)
        else v = (1 + mant / pow2(mbits)) * pow2(expv - bias) end
        return sign == 1 and -v or v
    end
    local v = 0
    for k = size - 1, 0, -1 do v = v * 256 + (t[i + k] or 0) end
    if kind == "s" then
        local half = pow2(size * 8 - 1)
        if v >= half then v = v - half * 2 end
    end
    return v
end

-- ------------------------------------------------------------------ ctypes
local ctypes = {}       -- name -> struct ctype
local CT = {}; CT.__index = CT
local function parse(decl)
    decl = norm(decl)
    local base, n = decl:match("^(.-)%s*%[(%??%d*)%]$")
    if base then return norm(base), (n == "?" and "?" or tonumber(n)) end
    local ptr = decl:match("^(.-)%s*%*$")
    if ptr then return norm(ptr), "*" end
    return decl, nil
end

-- Arrays and pointer views are {b = byte table, o = byte offset}; kind/size live in a per-type metatable,
-- so each object carries only two hash fields (serialisers allocate one per value read).
local classes = {}
local function class(name)
    local c = classes[name]
    if c then return c end
    local sc = scalars[name]
    if not sc then error("ffi shim: unsupported type '" .. tostring(name) .. "'", 3) end
    local sz, kind = sc[1], sc[2]
    c = { __ctname = name, __sz = sz, __kind = kind }
    c.__index = function(t, k)
        if type(k) ~= "number" then return nil end
        local b, o = t.b, t.o + k * sz
        if sz == 1 and kind ~= "s" then return b[o + 1] end
        return get(b, o + 1, sz, kind)
    end
    c.__newindex = function(t, k, v)
        if type(k) ~= "number" then rawset(t, k, v); return end
        local b, o = t.b, t.o + k * sz
        if sz == 1 then b[o + 1] = floor(v) % 256 else put(b, o + 1, v, sz, kind) end
    end
    c.__add = function(t, n)
        return setmetatable({ b = t.b, o = t.o + n * sz }, c)
    end
    classes[name] = c
    return c
end
local function bytes_of(a) return a.b, a.o end

-- Big arrays are lazy: no pre-filled zeros (they read as 0 until written), and ffi.copy/cast of a big Lua string
-- into an empty array just keeps the string and reads bytes from it on demand (a 4 MB map would otherwise
-- cost 32 MB of byte tables on the PSP).
local LAZY_MIN = 1024
local zero_mt = { __index = function() return 0 end }
local byte = string.byte
local function newarray(name, n)
    local c = class(name)
    local size = c.__sz * n
    local b = {}
    if size >= LAZY_MIN then setmetatable(b, zero_mt)
    else for i = 1, size do b[i] = 0 end end
    return setmetatable({ b = b, o = 0 }, c)
end
local function string_backed(str)
    return setmetatable({}, { __index = function(_, i) return byte(str, i) or 0 end })
end

local function struct_instance(ct, ...)
    local inst = {}
    local args = { ... }
    if type(args[1]) == "table" and #args == 1 then
        for i, f in ipairs(ct.fields) do inst[f] = args[1][f] or args[1][i] or 0 end
    else
        for i, f in ipairs(ct.fields) do inst[f] = args[i] or 0 end
    end
    return setmetatable(inst, ct.mt)
end

function ffi.cdef(src)
    src = src:gsub("//[^\n]*", ""):gsub("/%*.-%*/", "")
    for body, name in src:gmatch("typedef%s+struct%s*[%w_]*%s*(%b{})%s*([%w_]+)%s*;") do
        local fields = {}
        for decl in body:sub(2, -2):gmatch("[^;]+") do
            decl = decl:gsub("^%s+", ""):gsub("%s+$", "")
            if decl ~= "" then
                local fname = decl:match("([%w_]+)%s*$")
                fields[#fields + 1] = fname
            end
        end
        local ct = setmetatable({ name = name, fields = fields, struct = true }, CT)
        ct.mt = { __index = function(t, k) if k == "__isGCTile" then return true end end, __ct = ct }
        ctypes[name] = ct
    end
end
function CT.__call(ct, ...) return struct_instance(ct, ...) end

function ffi.metatype(name, mt)
    local ct = ctypes[name] or error("ffi shim: unknown struct '" .. tostring(name) .. "'", 2)
    local base = ct.mt.__index
    local user = mt and mt.__index
    local inst = { __index = function(t, k)
        if type(user) == "table" and user[k] ~= nil then return user[k] end
        if type(user) == "function" then local r = user(t, k); if r ~= nil then return r end end
        return base(t, k)
    end, __ct = ct }
    if mt then for k, v in pairs(mt) do if k ~= "__index" then inst[k] = v end end end
    ct.mt = inst
    return ct
end

function ffi.typeof(name)
    if type(name) ~= "string" then return name end
    return ctypes[norm(name)] or setmetatable({ name = name }, CT)
end

function ffi.new(ct, ...)
    if type(ct) == "table" and ct.struct then return struct_instance(ct, ...) end
    local decl = type(ct) == "table" and ct.name or ct
    local base, n = parse(decl)
    if ctypes[base] and not n then return struct_instance(ctypes[base], ...) end
    local len, first = 1, ...
    if n == "?" then len = (...); first = select(2, ...) elseif type(n) == "number" then len = n end
    local a = newarray(base, len)
    if first ~= nil then
        if n == nil or n == 1 or (type(first) == "number") then a[0] = first end
    end
    if n == nil then return a[0] end  -- scalar: ffi.new("int", v)
    return a
end

local function tobytes(src, len)
    if type(src) == "string" then
        local b = {}
        for i = 1, len do b[i] = src:byte(i) or 0 end
        return b, 0
    end
    return bytes_of(src)
end

function ffi.cast(ct, v)
    if type(v) == "string" then
        local base = parse(type(ct) == "table" and ct.name or ct)
        local a = newarray("uint8_t", #v)
        a.b = string_backed(v)
        return a
    end
    return v
end
function ffi.copy(dst, src, len)
    len = len or (type(src) == "string" and #src + 1)
    if type(src) == "string" and len >= LAZY_MIN and dst.o == 0 and getmetatable(dst.b) == zero_mt and next(dst.b) == nil then
        dst.b = string_backed(len == #src and src or src:sub(1, len))   -- whole-buffer fill: keep the string
        return
    end
    local sb, so = tobytes(src, len)
    local db, do_ = bytes_of(dst)
    if sb == db and so < do_ then for i = len, 1, -1 do db[do_ + i] = sb[so + i] end  -- overlapping, copy backwards
    else for i = 1, len do db[do_ + i] = sb[so + i] end end
end
function ffi.fill(dst, len, c)
    c = c or 0
    local b, o = bytes_of(dst)
    for i = 1, len do b[o + i] = c end
end
function ffi.string(p, len)
    if type(p) == "string" then return len and p:sub(1, len) or p end
    len = len or 0
    local parts = {}
    local b, o = bytes_of(p)
    for i = 1, len, 1024 do
        local j = math.min(i + 1023, len)
        local tmp = {}
        for k = i, j do tmp[k - i + 1] = b[o + k] end    -- indexed read: b may be lazy or string-backed
        parts[#parts + 1] = char(unpack(tmp))
    end
    return concat(parts)
end
function ffi.sizeof(ct, n)
    local decl = type(ct) == "table" and (ct.name or "") or ct
    if type(ct) == "table" and ct.struct then return #ct.fields * 4 end
    local base, k = parse(decl)
    local sc = scalars[base]; if not sc then return nil end
    if k == "?" then k = n elseif not k then k = 1 elseif k == "*" then return 4 end
    return sc[1] * k
end
function ffi.istype(ct, obj)
    if type(ct) == "string" then ct = ctypes[norm(ct)] end
    if type(ct) == "table" and ct.struct then
        local mt = getmetatable(obj)
        return mt ~= nil and mt.__ct == ct
    end
    return false
end
function ffi.gc(obj) return obj end
function ffi.errno() return 0 end
ffi.C = setmetatable({}, { __index = function(_, k) error("ffi shim: C function '" .. tostring(k) .. "' unavailable", 2) end })

-- ------------------------------------------------------------------ jit / table extras
if not rawget(_G, "jit") then
    local noop = function() end
    jit = { version = "LuaJIT shim", version_num = 20100, os = "Other", arch = "mips", on = noop, off = noop, flush = noop,
        status = function() return false end, opt = { start = noop }, util = {} }
    package.loaded.jit = jit; package.loaded["jit.opt"] = jit.opt
end
if not table.clear then function table.clear(t) for k in pairs(t) do t[k] = nil end end end
if not table.new then function table.new() return {} end end
package.loaded["table.clear"] = table.clear; package.loaded["table.new"] = table.new
package.loaded.ffi = ffi
return ffi
