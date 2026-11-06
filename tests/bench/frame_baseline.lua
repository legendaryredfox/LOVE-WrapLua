-- Reference numbers for tests/bench/frame_cost.lua --check (VM instructions per synthetic frame).
-- Update deliberately, with the reason in the commit message, after a real improvement.
return {
    ["PSP"]      = { instr = 122511 },
    ["OneLua"]   = { instr = 102129 },
    ["lpp-vita"] = { instr = 115025 },
    ["PS3"]      = { instr = 195159 },
}
