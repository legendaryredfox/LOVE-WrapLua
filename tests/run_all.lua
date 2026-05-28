-- Runs all unit tests and prints a combined summary.
-- Run from the project root: lua tests/run_all.lua

local test_files = {
    "tests/test_math.lua",
    "tests/test_data.lua",
    "tests/test_thread.lua",
    "tests/test_window.lua",
    "tests/test_joystick.lua",
    "tests/test_filesystem.lua",
    "tests/test_graphics.lua",
    "tests/test_keyboard.lua",
    "tests/test_timer.lua",
    "tests/test_audio.lua",
}

local total_fail = 0

for _, path in ipairs(test_files) do
    local ok, result = pcall(dofile, path)
    if not ok then
        io.write(string.format("\n  ERROR loading %s:\n  %s\n", path, tostring(result)))
        total_fail = total_fail + 1
    else
        -- Each test file returns the number of failures from T.summary()
        total_fail = total_fail + (result or 0)
    end
end

io.write(string.rep("─", 50) .. "\n")
if total_fail == 0 then
    io.write("All tests passed.\n")
else
    io.write(string.format("%d test(s) failed.\n", total_fail))
end

os.exit(total_fail == 0 and 0 or 1)
