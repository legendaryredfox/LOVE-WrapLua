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
-- LOVE's signature is pack(container, format, ...) and unpack(format, data [, pos]). The Lua 5.1 implementation
-- (data/pack.lua) is exercised directly on every runtime, and compared with string.pack where that exists.
local P = dofile("LOVE-WrapLua/data/pack.lua")

T.describe("love.data.pack/unpack", function()
    T.it("pack and unpack round-trip through the LOVE signature", function()
        local packed = love.data.pack("string", ">I4", 12345)
        T.eq(#packed, 4)
        T.eq((love.data.unpack(">I4", packed, 1)), 12345)
    end)

    T.it("container 'data' gives a ByteData, and unpack accepts it", function()
        local d = love.data.pack("data", "<i2 z", -3, "hi")
        T.eq(d:getSize(), 5)
        local a, b, nxt = love.data.unpack("<i2 z", d)
        T.eq(a, -3); T.eq(b, "hi"); T.eq(nxt, 6)
    end)

    T.it("unpack starts at a 1-based position", function()
        local s = love.data.pack("string", "<B B B", 1, 2, 3)
        local v, nxt = love.data.unpack("<B", s, 2)
        T.eq(v, 2); T.eq(nxt, 3)
    end)
end)

T.describe("data/pack.lua (Lua 5.1 implementation)", function()
    local cases = {
        { "<i4", -123456 }, { ">I2", 513 }, { "<I3", 70000 }, { "b", -5 }, { "B", 250 }, { "<h", -2 },
        { "<i8", -1 }, { ">i8", -9007199254740991 }, { "<j", 123456789012 }, { ">l", -7 }, { "<I8", 2 ^ 40 },
        { "<f", 1.5 }, { ">f", -0.15625 }, { "<f", 0.1 }, { "<f", 3.4e38 }, { "<f", 1e-40 },
        { "<d", 3.14159 }, { ">d", -1e300 }, { "<d", 5e-324 }, { "<d", 0 }, { "<d", 1 / 3 },
        { "<s1", "hello" }, { "<z", "abc" }, { "c5", "ab" },
    }

    T.it("round-trips every format", function()
        for _, c in ipairs(cases) do
            local packed = P.pack(c[1], c[2])
            local back = P.unpack(c[1], packed)
            if type(c[2]) == "number" and c[1]:find("[fdn]") then
                T.ok(math.abs(back - c[2]) <= math.abs(c[2]) * (c[1]:find("f") and 1e-4 or 1e-12), c[1] .. " " .. c[2] .. " came back " .. back)
            elseif c[1]:find("^c") then
                T.eq(back, c[2] .. string.rep("\0", 5 - #c[2]), c[1])   -- a fixed field is zero padded
            else
                T.eq(back, c[2], c[1])
            end
        end
    end)

    T.it("matches string.pack byte for byte where the runtime has it", function()
        if not string.pack then return end
        for _, c in ipairs(cases) do
            T.eq(P.pack(c[1], c[2]), string.pack(c[1], c[2]), c[1] .. " " .. tostring(c[2]))
        end
    end)

    T.it("several items in one format, with an endianness switch", function()
        local s = P.pack("<i2 >I4 z", 7, 9, "q")
        T.eq(#s, 2 + 4 + 2)
        local a, b, c, nxt = P.unpack("<i2 >I4 z", s)
        T.eq(a, 7); T.eq(b, 9); T.eq(c, "q"); T.eq(nxt, #s + 1)
    end)

    T.it("an unknown option and a short string both raise", function()
        T.nok(pcall(P.pack, "q", 1))
        T.nok(pcall(P.unpack, "<I4", "ab"))
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

-- LOVE returns exactly one value from these; string.gsub's match count used
-- to leak out as a second one, which shifts every argument after it in a
-- call like print(love.data.encode(...), x) or table.insert(t, hash(...)).
T.describe("love.data single return values", function()
    T.it("encode / decode hex return one value", function()
        T.eq(select("#", love.data.encode("string", "hex", "ab")), 1)
        T.eq(select("#", love.data.decode("string", "hex", "6162")), 1)
    end)

    T.it("hash returns one value", function()
        T.eq(select("#", love.data.hash("md5", "x")), 1)
    end)

    T.it("the 'data' container gives a ByteData from encode / decode", function()
        local bd = love.data.encode("data", "base64", "hi")
        T.eq(bd:getString(), "aGk=")
        T.eq(love.data.decode("data", "base64", "aGk="):getString(), "hi")
    end)
end)

io.write("\n=== love.data ===\n")
return T.summary()
