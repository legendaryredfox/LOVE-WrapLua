-- love.data.pack / unpack for Lua 5.1 and LuaJIT, which have no string.pack. Same format language as Lua 5.3:
--   < > =   little, big, native (little) endian        b B   8-bit signed, unsigned
--   h H     16-bit                                      i[n] I[n]   n-byte integer, default 4
--   l L j J 64-bit                                      T     size_t (8)
--   f d n   float, double, double                       s[n]  string with an n-byte length prefix, default 8
--   z       zero-terminated string                      c<n>  fixed-size string
--   x       one zero byte                               ' '   ignored
-- Integers are exact up to the precision of a Lua number: 2^53 with doubles, 2^24 on the native PSP build, which
-- keeps single precision numbers. A wider value loses its low bits before it reaches this file.

local floor, abs, frexp, ldexp = math.floor, math.abs, math.frexp, math.ldexp
local char, byte, sub, concat = string.char, string.byte, string.sub, table.concat

local M = {}

local function intBytes(n, size, little)
    local t = {}
    local negative = n < 0
    if negative then n = -n end
    for i = 1, size do
        t[i] = n % 256
        n = floor(n / 256)
    end
    if negative then                            -- two's complement, byte by byte (exact for any size)
        local carry = 1
        for i = 1, size do
            local v = 255 - t[i] + carry
            if v > 255 then v = v - 256; carry = 1 else carry = 0 end
            t[i] = v
        end
    end
    for i = 1, size do t[i] = char(t[i]) end
    if not little then
        for i = 1, floor(size / 2) do t[i], t[size + 1 - i] = t[size + 1 - i], t[i] end
    end
    return concat(t)
end

local function readInt(s, pos, size, little, signed)
    local first = byte(s, little and (pos + size - 1) or pos)
    if signed and first >= 128 then               -- negative: the magnitude is the complement plus one
        local n = 0
        for i = 0, size - 1 do
            local b = byte(s, little and (pos + size - 1 - i) or (pos + i))
            n = n * 256 + (255 - b)
        end
        return -(n + 1)
    end
    local n = 0
    for i = 0, size - 1 do
        local b = byte(s, little and (pos + size - 1 - i) or (pos + i))
        n = n * 256 + b
    end
    return n
end

-- IEEE 754 binary32 / binary64 from a Lua number.
local function floatBytes(x, size, little)
    local ebits, mbits = 8, 23
    if size == 8 then ebits, mbits = 11, 52 end
    local bias = 2 ^ (ebits - 1) - 1
    local sign = 0
    if x < 0 or (x == 0 and 1 / x < 0) then sign = 1; x = -x end
    local e, m
    if x ~= x then e, m = 2 ^ ebits - 1, 2 ^ (mbits - 1)
    elseif x == math.huge then e, m = 2 ^ ebits - 1, 0
    elseif x == 0 then e, m = 0, 0
    else
        local fr, ex = frexp(x)            -- x = fr * 2^ex, 0.5 <= fr < 1
        e = ex - 1 + bias
        if e >= 2 ^ ebits - 1 then e, m = 2 ^ ebits - 1, 0
        elseif e <= 0 then                  -- subnormal
            m = floor(x / 2 ^ (1 - bias - mbits) + 0.5)
            e = 0
            if m >= 2 ^ mbits then e, m = 1, m - 2 ^ mbits end
        else
            m = floor((fr * 2 - 1) * 2 ^ mbits + 0.5)
            if m >= 2 ^ mbits then m = 0; e = e + 1 end
        end
    end
    local bits = sign * 2 ^ (ebits + mbits) + e * 2 ^ mbits + m
    -- bits is exact in a double only up to 2^53, so build the bytes from the three fields instead
    local t = {}
    local mant = m
    local nb = size
    for i = 1, nb do t[i] = 0 end
    local function put(value, bitpos, width)
        for k = 0, width - 1 do
            local bit = floor(value / 2 ^ k) % 2
            if bit == 1 then
                local p = bitpos + k
                local bi = floor(p / 8) + 1
                t[bi] = t[bi] + 2 ^ (p % 8)
            end
        end
    end
    put(mant, 0, mbits)
    put(e, mbits, ebits)
    put(sign, mbits + ebits, 1)
    local out = {}
    for i = 1, nb do out[i] = char(t[i]) end
    if not little then
        for i = 1, floor(nb / 2) do out[i], out[nb + 1 - i] = out[nb + 1 - i], out[i] end
    end
    return concat(out)
end

local function readFloat(s, pos, size, little)
    local ebits, mbits = 8, 23
    if size == 8 then ebits, mbits = 11, 52 end
    local bias = 2 ^ (ebits - 1) - 1
    local bytes = {}
    for i = 1, size do bytes[i] = byte(s, pos + i - 1) end
    if not little then
        for i = 1, floor(size / 2) do bytes[i], bytes[size + 1 - i] = bytes[size + 1 - i], bytes[i] end
    end
    local function field(bitpos, width)
        local v = 0
        for k = width - 1, 0, -1 do
            local p = bitpos + k
            local bit = floor(bytes[floor(p / 8) + 1] / 2 ^ (p % 8)) % 2
            v = v * 2 + bit
        end
        return v
    end
    local m, e, sign = field(0, mbits), field(mbits, ebits), field(mbits + ebits, 1)
    local x
    if e == 2 ^ ebits - 1 then
        x = (m == 0) and math.huge or (0 / 0)
    elseif e == 0 then
        x = m * 2 ^ (1 - bias - mbits)
    else
        x = (1 + m / 2 ^ mbits) * 2 ^ (e - bias)
    end
    if sign == 1 then x = -x end
    return x
end

-- Parses one format item at `i`; returns kind, size, next index.
local function item(fmt, i)
    local c = sub(fmt, i, i)
    local function number(from, default)
        local j = from
        while sub(fmt, j, j):match("%d") do j = j + 1 end
        if j == from then return default, from end
        return tonumber(sub(fmt, from, j - 1)), j
    end
    if c == "b" then return "int", 1, true, i + 1 elseif c == "B" then return "int", 1, false, i + 1
    elseif c == "h" then return "int", 2, true, i + 1 elseif c == "H" then return "int", 2, false, i + 1
    elseif c == "l" or c == "j" then return "int", 8, true, i + 1
    elseif c == "L" or c == "J" or c == "T" then return "int", 8, false, i + 1
    elseif c == "i" then local n, j = number(i + 1, 4); return "int", n, true, j
    elseif c == "I" then local n, j = number(i + 1, 4); return "int", n, false, j
    elseif c == "f" then return "float", 4, true, i + 1
    elseif c == "d" or c == "n" then return "float", 8, true, i + 1
    elseif c == "s" then local n, j = number(i + 1, 8); return "string", n, true, j
    elseif c == "z" then return "zstring", 0, true, i + 1
    elseif c == "x" then return "pad", 1, true, i + 1
    elseif c == "c" then local n, j = number(i + 1, nil)
        if not n then error("missing size for format option 'c'", 3) end
        return "fixed", n, true, j
    end
    error("invalid format option '" .. c .. "'", 3)
end

function M.pack(fmt, ...)
    local args, argi = { ... }, 0
    local out, little, i = {}, true, 1
    local function nextArg()
        argi = argi + 1
        if args[argi] == nil then error("bad argument #" .. (argi + 1) .. " to 'pack' (no value)", 3) end
        return args[argi]
    end
    while i <= #fmt do
        local c = sub(fmt, i, i)
        if c == "<" or c == "=" then little = true; i = i + 1
        elseif c == ">" then little = false; i = i + 1
        elseif c == " " or c == "!" then i = i + 1
        else
            local kind, size, signed, nxt = item(fmt, i)
            if kind == "int" then
                local n = nextArg()
                if type(n) ~= "number" then error("bad argument to 'pack' (number expected)", 2) end
                out[#out + 1] = intBytes(floor(n), size, little)
            elseif kind == "float" then
                out[#out + 1] = floatBytes(nextArg(), size, little)
            elseif kind == "string" then
                local s = tostring(nextArg())
                out[#out + 1] = intBytes(#s, size, little)
                out[#out + 1] = s
            elseif kind == "zstring" then
                out[#out + 1] = tostring(nextArg()) .. "\0"
            elseif kind == "fixed" then
                local s = tostring(nextArg())
                if #s > size then error("string longer than given size", 2) end
                out[#out + 1] = s .. string.rep("\0", size - #s)
            elseif kind == "pad" then
                out[#out + 1] = "\0"
            end
            i = nxt
        end
    end
    return concat(out)
end

function M.unpack(fmt, data, pos)
    pos = pos or 1
    local res, little, i = {}, true, 1
    local function need(n)
        if pos + n - 1 > #data then error("data string too short", 3) end
    end
    while i <= #fmt do
        local c = sub(fmt, i, i)
        if c == "<" or c == "=" then little = true; i = i + 1
        elseif c == ">" then little = false; i = i + 1
        elseif c == " " or c == "!" then i = i + 1
        else
            local kind, size, signed, nxt = item(fmt, i)
            if kind == "int" then
                need(size); res[#res + 1] = readInt(data, pos, size, little, signed); pos = pos + size
            elseif kind == "float" then
                need(size); res[#res + 1] = readFloat(data, pos, size, little); pos = pos + size
            elseif kind == "string" then
                need(size)
                local len = readInt(data, pos, size, little, false); pos = pos + size
                need(len); res[#res + 1] = sub(data, pos, pos + len - 1); pos = pos + len
            elseif kind == "zstring" then
                local z = data:find("\0", pos, true)
                if not z then error("unfinished string for format 'z'", 2) end
                res[#res + 1] = sub(data, pos, z - 1); pos = z + 1
            elseif kind == "fixed" then
                need(size); res[#res + 1] = sub(data, pos, pos + size - 1); pos = pos + size
            elseif kind == "pad" then
                need(1); pos = pos + 1
            end
            i = nxt
        end
    end
    res[#res + 1] = pos
    return (table.unpack or unpack)(res)
end

return M
