-- love.math and love.data from the shared Lua modules, on the console build. Logs SHARED lines.
local function check(name, cond) PSP_LOG("SHARED " .. (cond and "ok   " or "FAIL ") .. name) end

function love.load()
    PSP_LOG(string.format("SHARED heap after boot %.0f KB", collectgarbage("count")))
    local n = love.math.noise(1.5, 2.5)
    check("noise", n >= 0 and n <= 1)
    check("triangulate", #love.math.triangulate({ 0, 0, 10, 0, 10, 10, 0, 10 }) == 2)
    local t = love.math.newTransform(5, 6, 0, 2, 3)
    local x, y = t:transformPoint(1, 1)
    check("transform", x == 7 and y == 9)
    local s = love.data.pack("string", "<i4 >d z", -9, 2.5, "ok")
    local a, b, c = love.data.unpack("<i4 >d z", s)
    check("pack/unpack", a == -9 and b == 2.5 and c == "ok")
    -- single precision numbers: hash must refuse with a clear message and not take the game down
    local ok, err = pcall(love.data.hash, "md5", "abc")
    check("hash refuses on single precision: " .. tostring(err):sub(1, 60), not ok and tostring(err):find("53%-bit") ~= nil)
    check("zlib", love.data.decompress("string", "zlib", love.data.compress("string", "zlib", "abcabc")) == "abcabc")
    check("base64", love.data.decode("string", "base64", love.data.encode("string", "base64", "hello")) == "hello")
    love.math.setRandomSeed(42)
    local r1 = love.math.random(1, 100)
    love.math.setRandomSeed(42)
    check("random", r1 == love.math.random(1, 100))
    PSP_LOG("SHARED done")
    love.event.quit()
end
