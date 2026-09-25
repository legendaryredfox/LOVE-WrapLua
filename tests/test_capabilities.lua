-- Capability table: honest getSupported/getSystemLimits (T4.5) plus the
-- emulator / renderer-sensitivity metadata (T8.4).
--
-- The docs (README dev target matrix, Implemented.md caveats) are written from
-- this table, so a drift here is a drift in the documentation too.

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
}

local MODES = { "OneLua", "PSP", "lpp-vita", "PS3" }

local FLAGS = { "blendmode", "framebufferread", "texturefilter", "savepersistence" }

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
end

-- ── shared shape (every backend) ─────────────────────────────────
for _, mode in ipairs(MODES) do
    load_backend(mode)

    T.describe("capabilities ["..mode.."]", function()
        T.it("names the emulator it is tested on", function()
            T.istype(love._backend.emulator, "string")
            T.ok(#love._backend.emulator > 0, "emulator name should not be empty")
        end)

        T.it("declares a support tier", function()
            T.inrange(love._backend.tier, 1, 3)
        end)

        T.it("answers every renderer-sensitivity flag with a boolean", function()
            local rs = love._backend.rendersensitive
            T.istype(rs, "table")
            for _, flag in ipairs(FLAGS) do
                T.istype(rs[flag], "boolean")
            end
        end)

        T.it("never advertises canvas or shader", function()
            T.nok(love.graphics.getSupported().canvas)
            T.nok(love.graphics.getSupported().shader)
        end)

        -- Since T6.5 blending is real where the SDK exposes it (PSP, PS3) and
        -- still a stub on both Vita backends, so the flag has to agree with the
        -- mode list rather than being false everywhere.
        T.it("the blend feature flag matches the mode list", function()
            local blend = love._backend.blend
            T.istype(blend, "table")
            T.eq(love._backend.features.blendmode, blend.native)
            if not blend.native then
                T.nok(blend.modes.add, "a backend with no blend call supports alpha only")
            end
        end)
    end)
end

-- ── per-backend specifics ────────────────────────────────────────
load_backend("OneLua")
T.describe("capabilities [OneLua specifics]", function()
    T.it("flags the Vita3K blend, readback and save problems", function()
        T.eq(love._backend.emulator, "Vita3K")
        T.ok(love._backend.rendersensitive.blendmode)
        T.ok(love._backend.rendersensitive.framebufferread)
        T.ok(love._backend.rendersensitive.savepersistence)
    end)
end)

load_backend("PSP")
T.describe("capabilities [PSP specifics]", function()
    T.it("flags the PPSSPP texel-bleed problem", function()
        T.eq(love._backend.emulator, "PPSSPP")
        T.ok(love._backend.rendersensitive.texturefilter)
    end)

    T.it("requires power-of-two textures", function()
        T.ok(love.graphics.getSystemLimits().texturesize == 512)
        T.ok(love._backend.limits.potonly)
    end)
end)

load_backend("lpp-vita")
T.describe("capabilities [lpp-vita specifics]", function()
    T.it("allows NPOT up to 1024 and shares the Vita3K caveats", function()
        T.ok(love.graphics.getSupported().fullnpot)
        T.eq(love.graphics.getSystemLimits().texturesize, 1024)
        T.eq(love._backend.emulator, "Vita3K")
        T.ok(love._backend.rendersensitive.blendmode)
    end)
end)

load_backend("PS3")
T.describe("capabilities [PS3 specifics]", function()
    T.it("is the experimental tier (T8.5)", function()
        T.eq(love._backend.tier, 3)
    end)

    T.it("treats every renderer-sensitive area as unconfirmed", function()
        for _, flag in ipairs(FLAGS) do
            T.ok(love._backend.rendersensitive[flag], flag.." should be flagged on PS3")
        end
    end)

    T.it("claims no primitives or quad draw", function()
        T.nok(love._backend.features.primitives)
        T.nok(love._backend.features.quaddraw)
    end)
end)

-- getSupported hands out copies, so a game cannot poison the shared table.
load_backend("OneLua")
T.describe("capabilities [isolation]", function()
    T.it("getSupported returns a fresh copy each call", function()
        local a = love.graphics.getSupported()
        a.canvas = true
        T.nok(love.graphics.getSupported().canvas)
    end)
end)

io.write("\n=== capabilities ===\n")
return T.summary()
