-- The packaging step that turns a game's .ogg and .wav files into stereo .mp3 (tools/lovepsp.lua convert), run
-- against a stand-in ffmpeg that records its arguments and writes the output file.

local T = dofile("tests/runner.lua")
local interpreter = (arg and arg[-1]) or "lua"

local scratch = os.tmpname()
os.remove(scratch)
local function sh(cmd) return os.execute(cmd) end
local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

sh("mkdir -p '" .. scratch .. "/bin' '" .. scratch .. "/game/sfx'")
local shim = io.open(scratch .. "/bin/ffmpeg", "w")
shim:write("#!/bin/sh\necho \"$@\" >> '" .. scratch .. "/args.txt'\nfor last; do :; done\necho mp3 > \"$last\"\n")
shim:close()
sh("chmod +x '" .. scratch .. "/bin/ffmpeg'")
for _, name in ipairs({ "music.ogg", "sfx/hit.WAV", "pic.png" }) do
    local f = io.open(scratch .. "/game/" .. name, "wb"); f:write("x"); f:close()
end

local ran = sh("PATH='" .. scratch .. "/bin':\"$PATH\" " .. interpreter .. " tools/lovepsp.lua convert '" .. scratch .. "/game' >/dev/null 2>&1")
local args = read(scratch .. "/args.txt") or ""

T.describe("audio conversion for the native PSP backend", function()
    T.it("the command succeeds", function() T.ok(ran == 0 or ran == true, "convert failed") end)
    T.it("every .ogg and .wav becomes an .mp3 beside it", function()
        T.ok(read(scratch .. "/game/music.mp3") ~= nil, "music.mp3 missing")
        T.ok(read(scratch .. "/game/sfx/hit.mp3") ~= nil, "sfx/hit.mp3 missing")
    end)
    T.it("the originals are removed from the package, other files stay", function()
        T.ok(read(scratch .. "/game/music.ogg") == nil, "music.ogg kept")
        T.ok(read(scratch .. "/game/sfx/hit.WAV") == nil, "hit.WAV kept")
        T.ok(read(scratch .. "/game/pic.png") ~= nil, "pic.png removed")
    end)
    T.it("ffmpeg gets stereo, libmp3lame and 128k", function()
        T.ok(args:find("-ac 2", 1, true), args)
        T.ok(args:find("libmp3lame", 1, true), args)
        T.ok(args:find("-b:a 128k", 1, true), args)
    end)
end)

sh("rm -rf '" .. scratch .. "'")
io.write("\n=== lovepsp audio conversion ===\n")
return T.summary()
