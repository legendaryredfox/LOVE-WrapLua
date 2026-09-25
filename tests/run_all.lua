-- Runs all unit tests and prints a combined summary.
-- Run from the project root: lua tests/run_all.lua

local test_files = {
    "tests/core_test.lua",
    "tests/bootstrap_test.lua",
    "tests/primitives_test.lua",
    "tests/quad_draw_test.lua",
    "tests/boot_modules_test.lua",
    "tests/review_fixes_test.lua",
    "tests/prim_transform_test.lua",
    "tests/math_test.lua",
    "tests/data_test.lua",
    "tests/thread_test.lua",
    "tests/window_test.lua",
    "tests/joystick_test.lua",
    "tests/system_test.lua",
    "tests/filesystem_test.lua",
    "tests/graphics_test.lua",
    "tests/capabilities_test.lua",
    "tests/objects_test.lua",
    "tests/state_test.lua",
    "tests/blend_test.lua",
    "tests/texture_limits_test.lua",
    "tests/quad_inset_test.lua",
    "tests/desanim8_test.lua",
    "tests/text_test.lua",
    "tests/font_test.lua",
    "tests/keyboard_test.lua",
    "tests/input_test.lua",
    "tests/timer_test.lua",
    "tests/timestep_test.lua",
    "tests/globals_test.lua",
    "tests/audio_test.lua",
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
