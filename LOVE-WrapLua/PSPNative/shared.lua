-- Loads the pure-Lua modules the wrapper shares with every backend (love.math, love.data) over the native
-- backend, and keeps the C engine's fast paths where it has one:
--   love.math.random / setRandomSeed   the C library's generator (one call), not the Lua L'Ecuyer in math/random.lua
--   love.data.encode / decode          base64 through native.b64encode / b64decode
--   love.data.compress / decompress    zlib through native.deflate / inflate
-- Everything else (noise, triangulate, bezier, Transform, RandomGenerator, colour helpers, hash, pack, unpack,
-- ByteData, gzip and raw deflate) is the shared Lua. The files sit under LOVE-WrapLua/ next to the EBOOT.

local N = native

lv1lua = lv1lua or {}
lv1lua.mode = lv1lua.mode or "PSPNative"
lv1lua.dataloc = lv1lua.dataloc or ""
lv1lua.screenWidth, lv1lua.screenHeight = 480, 272
dofile(lv1lua.dataloc .. "LOVE-WrapLua/core/loader.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/util.lua")

-- ── love.math ────────────────────────────────────────────────────
local nativeRandom, nativeSeed = math.random, math.randomseed
love.math = {}
lv1lua.load("LOVE-WrapLua/math.lua")
love.math.random, love.math.setRandomSeed = nativeRandom, nativeSeed

-- ── love.data ────────────────────────────────────────────────────
local old = love.data or {}
lv1lua.load("LOVE-WrapLua/data.lua")
local data = love.data
local sharedEncode, sharedDecode = data.encode, data.decode
local sharedCompress, sharedDecompress = data.compress, data.decompress

local function hex(s) return (s:gsub(".", function(c) return ("%02x"):format(c:byte()) end)) end
local function unhex(s) return (s:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end)) end

function data.encode(containerType, format, raw, linelength)
    if containerType == "string" and linelength == nil then
        if format == "base64" then return N.b64encode(raw) end
        if format == "hex" then return hex(raw) end
    end
    return sharedEncode(containerType, format, raw, linelength)
end

function data.decode(containerType, format, raw)
    if containerType == "string" then
        if format == "base64" then return N.b64decode(raw) end
        if format == "hex" then return unhex(raw) end
    end
    return sharedDecode(containerType, format, raw)
end

function data.compress(containerType, format, raw, level)
    if containerType == "string" and (format == "zlib" or format == nil) and type(raw) == "string" then
        return N.deflate(raw)
    end
    return sharedCompress(containerType, format, raw, level)
end

function data.decompress(containerType, format, raw)
    if containerType == "string" and (format == "zlib" or format == nil) and type(raw) == "string" then
        return N.inflate(raw)
    end
    return sharedDecompress(containerType, format, raw)
end

-- The EBOOT is built with single precision Lua numbers (24 exact bits, the fast build), and sha2.lua needs 53.
-- Until the engine gets its own hash functions, love.data.hash says so instead of failing inside the library.
local EXACT53 = ((2 ^ 52 + 1) - 2 ^ 52) == 1

-- sha2.lua picks its FFI code path when it sees `jit` and a loadable `ffi`. The backend ships an ffi shim for
-- games written for LuaJIT, and that shim has no int64_t, so the hash library is loaded with both hidden and
-- falls back to its pure Lua path. The choice is made once, on load.
local hashLoaded = false
local sharedHash = data.hash
function data.hash(hashFunction, raw)
    if not EXACT53 then
        error("love.data.hash needs 53-bit Lua numbers; this build uses single precision (lua tools/lovepsp.lua build --double)", 2)
    end
    if hashLoaded then return sharedHash(hashFunction, raw) end
    local savedJit, savedLoaded, savedPreload = jit, package.loaded.ffi, package.preload.ffi
    jit, package.loaded.ffi, package.preload.ffi = nil, nil, nil
    local ok, result = pcall(sharedHash, hashFunction, raw)
    jit, package.loaded.ffi, package.preload.ffi = savedJit, savedLoaded, savedPreload
    hashLoaded = true
    if not ok then error(result, 0) end
    return result
end

package.loaded["love.math"] = love.math
package.loaded["love.data"] = love.data
