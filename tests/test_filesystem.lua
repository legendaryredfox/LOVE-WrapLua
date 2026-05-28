local T = dofile("tests/runner.lua")
dofile("tests/mock_platform.lua")
dofile("LOVE-WrapLua/filesystem.lua")

-- After loading, redirect saveloc to a real temp dir and fix exists().
local TMPDIR = "/tmp/lwl_test_" .. tostring(os.time()) .. "/"
os.execute("mkdir -p " .. TMPDIR)

lv1lua.saveloc = TMPDIR
function lv1lua.exists(file)
    local f = io.open(file, "r")
    if f then f:close(); return true end
    return false
end

-- ── write / read ─────────────────────────────────────────────────
T.describe("love.filesystem.write / read", function()
    T.it("write creates a file that read returns", function()
        love.filesystem.write("unit_test.txt", "hello world")
        local content = love.filesystem.read("unit_test.txt")
        T.eq(content, "hello world")
    end)

    T.it("write with size argument truncates content", function()
        love.filesystem.write("trunc.txt", "abcdefgh", 4)
        local content = love.filesystem.read("trunc.txt")
        T.eq(content, "abcd")
    end)

    T.it("read with size argument returns only that many bytes", function()
        love.filesystem.write("sized.txt", "0123456789")
        local part = love.filesystem.read("sized.txt", 3)
        T.eq(part, "012")
    end)

    T.it("read returns nil for missing file", function()
        local content, err = love.filesystem.read("no_such_file_xyz.txt")
        T.ok(content == nil)
        T.istype(err, "string")
    end)
end)

-- ── append ───────────────────────────────────────────────────────
T.describe("love.filesystem.append", function()
    T.it("appends data to existing file", function()
        love.filesystem.write("append_test.txt", "line1")
        love.filesystem.append("append_test.txt", "line2")
        local content = love.filesystem.read("append_test.txt")
        T.ok(content:find("line1"), "original content preserved")
        T.ok(content:find("line2"), "appended content present")
    end)
end)

-- ── isFile ───────────────────────────────────────────────────────
T.describe("love.filesystem.isFile", function()
    T.it("returns true for a file we wrote", function()
        love.filesystem.write("check_exists.txt", "x")
        T.ok(love.filesystem.isFile("check_exists.txt"))
    end)

    T.it("returns false for a file that does not exist", function()
        T.nok(love.filesystem.isFile("__nonexistent_file__.txt"))
    end)
end)

-- ── lines ────────────────────────────────────────────────────────
T.describe("love.filesystem.lines", function()
    T.it("iterates lines of a written file", function()
        love.filesystem.write("lines_test.txt", "alpha\nbeta\ngamma")
        local lines = {}
        for line in love.filesystem.lines("lines_test.txt") do
            lines[#lines+1] = line
        end
        T.eq(lines[1], "alpha")
        T.eq(lines[2], "beta")
        T.eq(lines[3], "gamma")
    end)

    T.it("returns empty iterator for missing file", function()
        local count = 0
        for _ in love.filesystem.lines("missing_lines.txt") do count = count + 1 end
        T.eq(count, 0)
    end)
end)

-- ── newFileData ──────────────────────────────────────────────────
T.describe("love.filesystem.newFileData", function()
    T.it("getString returns the contents", function()
        local fd = love.filesystem.newFileData("payload", "data.bin")
        T.eq(fd:getString(), "payload")
    end)

    T.it("getSize returns byte length", function()
        local fd = love.filesystem.newFileData("12345", "n.bin")
        T.eq(fd:getSize(), 5)
    end)

    T.it("getFilename returns the name", function()
        local fd = love.filesystem.newFileData("", "myfile.dat")
        T.eq(fd:getFilename(), "myfile.dat")
    end)
end)

-- ── getIdentity / setIdentity ────────────────────────────────────
T.describe("love.filesystem.getIdentity / setIdentity", function()
    T.it("getIdentity returns current identity", function()
        lv1lua.loveconf.identity = "my_game"
        T.eq(love.filesystem.getIdentity(), "my_game")
    end)

    T.it("setIdentity updates loveconf.identity", function()
        love.filesystem.setIdentity("new_id")
        T.eq(lv1lua.loveconf.identity, "new_id")
    end)
end)

-- ── path helpers ─────────────────────────────────────────────────
T.describe("love.filesystem path helpers", function()
    T.it("getWorkingDirectory returns dataloc+game/", function()
        lv1lua.dataloc = ""
        T.eq(love.filesystem.getWorkingDirectory(), "game/")
    end)

    T.it("getUserDirectory returns saveloc", function()
        T.eq(love.filesystem.getUserDirectory(), lv1lua.saveloc)
    end)

    T.it("getSaveDirectory returns saveloc", function()
        T.eq(love.filesystem.getSaveDirectory(), lv1lua.saveloc)
    end)

    T.it("isFused returns true", function()
        T.ok(love.filesystem.isFused())
    end)

    T.it("mount returns false (stub)", function()
        T.nok(love.filesystem.mount("archive.zip", "/"))
    end)

    T.it("unmount returns false (stub)", function()
        T.nok(love.filesystem.unmount("archive.zip"))
    end)
end)

-- ── getInfo ──────────────────────────────────────────────────────
T.describe("love.filesystem.getInfo", function()
    T.it("returns nil for missing entry", function()
        T.ok(love.filesystem.getInfo("__ghost__.txt") == nil)
    end)

    T.it("returns a table with type/size/modtime for existing file", function()
        love.filesystem.write("info_test.txt", "data")
        local info = love.filesystem.getInfo("info_test.txt")
        T.istype(info, "table")
        T.istype(info.type, "string")
        T.istype(info.size, "number")
        T.istype(info.modtime, "number")
    end)
end)

-- ── newFile (constructor only) ───────────────────────────────────
T.describe("love.filesystem.newFile", function()
    T.it("creates a file object with expected methods", function()
        local f = love.filesystem.newFile("dummy.txt")
        T.ok(f.open,        "should have open")
        T.ok(f.read,        "should have read")
        T.ok(f.write,       "should have write")
        T.ok(f.close,       "should have close")
        T.ok(f.getFilename, "should have getFilename")
        T.eq(f:getFilename(), "dummy.txt")
    end)

    T.it("isOpen returns false before open() is called", function()
        local f = love.filesystem.newFile("dummy2.txt")
        T.nok(f:isOpen())
    end)

    T.it("open+read+close roundtrip", function()
        love.filesystem.write("newfile_rw.txt", "content here")
        local f = love.filesystem.newFile("newfile_rw.txt")
        T.ok(f:open("r"), "open should return true")
        local data = f:read()
        T.eq(data, "content here")
        f:close()
        T.nok(f:isOpen())
    end)
end)

-- Cleanup
os.execute("rm -rf " .. TMPDIR)

io.write("\n=== love.filesystem ===\n")
return T.summary()
