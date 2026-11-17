-- Reference numbers for tests/bench/frame_cost.lua --check (VM instructions per synthetic frame).
-- Update deliberately, with the reason in the commit message, after a real improvement.
return {
    ["PSP"]      = { instr = 99462 },
    ["OneLua"]   = { instr = 95884 },
    ["lpp-vita"] = { instr = 97142 },
    ["PS3"]      = { instr = 158232 },
}
