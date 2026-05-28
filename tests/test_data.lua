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
T.describe("love.data.hash", function()
    T.it("md5 returns 16 bytes", function()
        local h = love.data.hash("md5", "test")
        T.eq(#h, 16)
    end)

    T.it("sha256 returns 32 bytes", function()
        local h = love.data.hash("sha256", "test")
        T.eq(#h, 32)
    end)
end)

-- ── compress / decompress (pass-through stubs) ───────────────────
T.describe("love.data.compress/decompress", function()
    T.it("compress returns original data", function()
        local data = "some raw data"
        T.eq(love.data.compress("string", "zlib", data), data)
    end)

    T.it("decompress returns original data", function()
        local data = "some raw data"
        T.eq(love.data.decompress("string", "zlib", data), data)
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
