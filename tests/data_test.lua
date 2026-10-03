local T = dofile("tests/runner.lua")
dofile("tests/mock_platform.lua")
dofile("LOVE-WrapLua/data.lua")

-- ── encode / decode ──────────────────────────────────────────────
T.describe("love.data.encode/decode base64", function()
    T.it("encode produces non-empty string", function()
        local enc = love.data.encode("string", "base64", "hello")
        T.istype(enc, "string")
        T.ok(#enc > 0)
    end)

    T.it("roundtrip decode(encode(s)) == s", function()
        local s   = "Hello, World!"
        local enc = love.data.encode("string", "base64", s)
        local dec = love.data.decode("string", "base64", enc)
        T.eq(dec, s)
    end)

    T.it("roundtrip with binary-ish data", function()
        local s   = "abc\0\1\2\255"
        local enc = love.data.encode("string", "base64", s)
        local dec = love.data.decode("string", "base64", enc)
        T.eq(dec, s)
    end)

    T.it("empty string encodes to empty / padding only", function()
        local enc = love.data.encode("string", "base64", "")
        T.ok(enc == "" or enc == "==", "empty base64")
    end)
end)

T.describe("love.data.encode/decode hex", function()
    T.it("encode produces lowercase hex digits", function()
        local enc = love.data.encode("string", "hex", "AB")
        T.eq(enc, "4142")
    end)

    T.it("roundtrip decode(encode(s)) == s", function()
        local s   = "Test string 123"
        local enc = love.data.encode("string", "hex", s)
        local dec = love.data.decode("string", "hex", enc)
        T.eq(dec, s)
    end)
end)

-- ── hash ─────────────────────────────────────────────────────────
-- Digest is raw bytes (LÖVE contract); hex the result to compare vectors.
local function hex(s) return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end)) end

T.describe("love.data.hash", function()
    T.it("md5 returns 16 bytes", function()
        T.eq(#love.data.hash("md5", "test"), 16)
    end)

    T.it("sha256 returns 32 bytes", function()
        T.eq(#love.data.hash("sha256", "test"), 32)
    end)

    T.it("md5 matches known vector", function()
        T.eq(hex(love.data.hash("md5", "")), "d41d8cd98f00b204e9800998ecf8427e")
    end)

    T.it("sha1 matches known vector", function()
        T.eq(hex(love.data.hash("sha1", "abc")), "a9993e364706816aba3e25717850c26c9cd0d89d")
    end)

    T.it("sha256 matches known vector", function()
        T.eq(hex(love.data.hash("sha256", "abc")),
             "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    end)

    T.it("unsupported hash errors", function()
        T.ok(not pcall(love.data.hash, "crc32", "x"))
    end)
end)

-- ── compress / decompress (real DEFLATE/zlib via LibDeflate) ─────
T.describe("love.data.compress/decompress", function()
    local raw = string.rep("The quick brown fox. ", 40)  -- compressible

    T.it("deflate round-trips and shrinks", function()
        local c = love.data.compress("string", "deflate", raw)
        T.ok(#c < #raw, "compressed shorter")
        T.eq(love.data.decompress("string", "deflate", c), raw)
    end)

    T.it("zlib round-trips", function()
        local c = love.data.compress("string", "zlib", raw)
        T.eq(love.data.decompress("string", "zlib", c), raw)
    end)

    T.it("round-trips binary data", function()
        local bin = "abc\0\1\2\255\254\0end"
        local c   = love.data.compress("string", "deflate", bin)
        T.eq(love.data.decompress("string", "deflate", c), bin)
    end)

    T.it("data container yields ByteData", function()
        local c = love.data.compress("data", "deflate", raw)
        T.eq(c:getString(), love.data.compress("string", "deflate", raw))
    end)
end)

-- ── ByteData ─────────────────────────────────────────────────────
T.describe("love.data.newByteData", function()
    T.it("from integer creates zero-filled string of that size", function()
        local bd = love.data.newByteData(8)
        T.eq(bd:getSize(), 8)
        T.eq(bd:getString(), string.rep("\0", 8))
    end)

    T.it("from string stores the string", function()
        local bd = love.data.newByteData("hello")
        T.eq(bd:getString(), "hello")
        T.eq(bd:getSize(), 5)
    end)
end)

-- ── newDataView ──────────────────────────────────────────────────
T.describe("love.data.newDataView", function()
    T.it("slices the source data by offset and size", function()
        local bd  = love.data.newByteData("abcdefgh")
        local dv  = love.data.newDataView(bd, 2, 3)  -- offset 2, size 3 → "cde"
        T.eq(dv:getString(), "cde")
    end)
end)

-- ── pack / unpack ────────────────────────────────────────────────
T.describe("love.data.pack/unpack", function()
    T.it("pack/unpack roundtrip for simple format", function()
        if not string.pack then return end   -- Lua 5.1/5.2 guard
        local packed = love.data.pack(">I4", 12345)
        local val    = love.data.unpack(">I4", packed, 1)
        T.eq(val, 12345)
    end)
end)

-- ── getSize ──────────────────────────────────────────────────────
T.describe("love.data.getSize", function()
    T.it("returns #string for string argument", function()
        T.eq(love.data.getSize("hello"), 5)
    end)

    T.it("delegates to ByteData:getSize()", function()
        local bd = love.data.newByteData("test")
        T.eq(love.data.getSize(bd), 4)
    end)
end)

io.write("\n=== love.data ===\n")
return T.summary()
