-- usage: tests/backend/run.sh api <names.txt>   (names like love.window.toPixels, one per line)
-- Lists the love.* functions a game references that the PSP backend does not define.
bit = { band = function() return 0 end }
native = dofile(os.getenv("TESTDIR") .. "/mock_native.lua")
PSP_CONFIG = { identity = "t", title = "T", os = "TestOS", font = "default.ttf" }
dofile("love_psp.lua")
local missing = {}
for name in io.lines(os.getenv("API_NAMES")) do
    local mod, fn = name:match("^love%.(%w+)%.(%w+)$")
    if mod and not (love[mod] and love[mod][fn] ~= nil) then missing[#missing + 1] = name end
end
table.sort(missing)
io.write(#missing, " missing\n"); for _, m in ipairs(missing) do io.write("  ", m, "\n") end
