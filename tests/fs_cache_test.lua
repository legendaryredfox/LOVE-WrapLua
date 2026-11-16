-- love.filesystem metadata and listing cache: the shipped game directory is read-only so it is cached
-- for good, the save directory is cached until the wrapper itself changes it.

local T = dofile("tests/runner.lua")
dofile("tests/mock_platform.lua")

local ROOT = "/tmp/lwl_fscache_" .. tostring(os.time()) .. "/"
local DATA, SAVE = ROOT .. "data/", ROOT .. "save/"
os.execute("mkdir -p " .. DATA .. "game/sub " .. SAVE)
local function put(path, body) local f = io.open(path, "wb"); f:write(body); f:close() end
put(DATA .. "game/shipped.txt", "shipped")
put(DATA .. "game/sub/a.lua", "return 1")
put(DATA .. "game/sub/b.lua", "return 2")

lv1lua.dataloc = DATA
local existsCalls, listCalls, openCalls = 0, 0, 0
lv1lua.fileio = {
    list = function(dir)
        listCalls = listCalls + 1
        local out = {}
        local p = io.popen('ls "' .. dir .. '" 2>/dev/null')
        for line in p:lines() do out[#out + 1] = line end
        p:close()
        return out
    end,
}
dofile("LOVE-WrapLua/filesystem.lua")
lv1lua.saveloc = SAVE
lv1lua.fileio.open = function(path, mode) openCalls = openCalls + 1; return io.open(path, mode) end
function lv1lua.exists(file)
    existsCalls = existsCalls + 1
    local f = io.open(file, "r")
    if f then f:close(); return true end
    return false
end

local function calls() return existsCalls, listCalls, openCalls end

T.describe("filesystem cache: metadata", function()
    T.it("a shipped file is stat-ed once however often it is asked", function()
        local info = love.filesystem.getInfo("shipped.txt")
        T.eq(info.type, "file"); T.eq(info.size, 7)
        local e, _, o = calls()
        for _ = 1, 5 do
            love.filesystem.getInfo("shipped.txt")
            love.filesystem.isFile("shipped.txt")
            love.filesystem.isDirectory("shipped.txt")
        end
        local e2, _, o2 = calls()
        T.eq(e2, e); T.eq(o2, o)
    end)

    T.it("read does not look the path up again after getInfo", function()
        local e = calls()
        T.eq(love.filesystem.read("shipped.txt"), "shipped")
        T.eq((calls()), e)
    end)

    T.it("a missing name is remembered as missing", function()
        T.eq(love.filesystem.getInfo("nope.txt"), nil)
        local e = calls()
        T.eq(love.filesystem.getInfo("nope.txt"), nil)
        T.eq((calls()), e)
    end)

    T.it("a write shows up at once, and the size follows an append", function()
        T.eq(love.filesystem.getInfo("save.txt"), nil)
        love.filesystem.write("save.txt", "abc")
        T.eq(love.filesystem.getInfo("save.txt").size, 3)
        love.filesystem.append("save.txt", "de")
        T.eq(love.filesystem.getInfo("save.txt").size, 5)
    end)

    T.it("remove makes the name disappear", function()
        T.ok(love.filesystem.getInfo("save.txt"))
        os.remove(SAVE .. "save.txt")
        love.filesystem.remove("save.txt")
        T.eq(love.filesystem.getInfo("save.txt"), nil)
    end)

    T.it("a save file written through a File handle shows up after close", function()
        T.eq(love.filesystem.getInfo("handle.txt"), nil)
        local f = love.filesystem.newFile("handle.txt", "w")
        f:write("12345678")
        f:close()
        T.eq(love.filesystem.getInfo("handle.txt").size, 8)
    end)

    T.it("a save write does not drop the shipped entries", function()
        love.filesystem.getInfo("shipped.txt")
        local e = calls()
        love.filesystem.write("other.txt", "x")
        love.filesystem.getInfo("shipped.txt")
        -- the save path is asked again, the game path is not
        T.eq((calls()) - e, 1)
    end)

    T.it("a save file shadows the shipped one once written", function()
        T.eq(love.filesystem.read("shipped.txt"), "shipped")
        love.filesystem.write("shipped.txt", "saved")
        T.eq(love.filesystem.read("shipped.txt"), "saved")
        T.eq(love.filesystem.getRealDirectory("shipped.txt"), SAVE)
    end)

    T.it("setIdentity starts from a clean save cache", function()
        local old = lv1lua.saveloc
        T.eq(love.filesystem.getInfo("late.txt"), nil)
        put(old .. "late.txt", "x")
        love.filesystem.setIdentity("other-game")
        lv1lua.saveloc = old
        T.ok(love.filesystem.getInfo("late.txt"))
    end)
end)

T.describe("filesystem cache: listings", function()
    T.it("a directory is listed natively once", function()
        local first = love.filesystem.getDirectoryItems("sub")
        T.eq(#first, 2)
        local _, l = calls()
        love.filesystem.getDirectoryItems("sub")
        love.filesystem.getDirectoryItems("sub")
        local _, l2 = calls()
        T.eq(l2, l)
    end)

    T.it("each call gets its own table", function()
        local a = love.filesystem.getDirectoryItems("sub")
        a[#a + 1] = "junk"
        T.eq(#love.filesystem.getDirectoryItems("sub"), 2)
    end)

    T.it("a new save file appears in a listing already seen", function()
        os.execute("mkdir -p " .. SAVE .. "sub")
        love.filesystem.createDirectory("sub")
        T.eq(#love.filesystem.getDirectoryItems("sub"), 2)
        love.filesystem.write("sub/c.lua", "return 3")
        local items = love.filesystem.getDirectoryItems("sub")
        T.eq(#items, 3); T.eq(items[3], "c.lua")
    end)
end)

os.execute("rm -rf " .. ROOT)
io.write("\n=== filesystem cache ===\n")
return T.summary()
