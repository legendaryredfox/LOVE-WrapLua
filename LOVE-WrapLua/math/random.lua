-- love.math: randomness.
--
-- The generator is L'Ecuyer's combined multiple recursive generator: two
-- Lehmer streams with different prime moduli, combined by subtraction.
--
--   s1 = s1 * 40014 mod 2147483563
--   s2 = s2 * 40692 mod 2147483399
--   z  = (s1 - s2) mod (m1 - 1)
--
-- Why this one:
--   * Every intermediate product stays below 2^53 (the largest is about
--     8.6e13), so it is exact in a double and gives the *same* sequence on
--     Lua 5.1, 5.3, 5.4 and LuaJIT. The previous LCG multiplied a 32-bit state
--     by 1103515245, which overflows a double's exact range and silently
--     produced a different stream per Lua version (#11).
--   * It needs no bitwise operators, which the console SDKs' Lua 5.1 lacks.
--   * It has two independent state words, so LÖVE's setSeed(low, high) can
--     actually use both instead of dropping the second.
--   * Period is about 2.3e18, against 2^32 for the old LCG.

local M1, M2 = 2147483563, 2147483399
local A1, A2 = 40014, 40692

local function _normaliseSeed(seed, modulus)
    seed = math.floor(math.abs(tonumber(seed) or 0))
    -- 0 is a fixed point of a Lehmer stream, so it must never be a seed.
    return (seed % (modulus - 1)) + 1
end

-- Builds the state pair. A missing second seed is derived from the first, so a
-- single-seed call is still fully deterministic.
local function _seedState(seed1, seed2)
    seed1 = tonumber(seed1) or os.time()
    if seed2 == nil then
        -- Offset the first seed by a prime so the two streams do not start in
        -- lockstep (which would make z small for the first few draws).
        seed2 = math.floor(seed1) + 131071
    end
    return _normaliseSeed(seed1, M1), _normaliseSeed(seed2, M2)
end

-- One generator instance. Everything below is built on top of this.
local function _newState(seed1, seed2)
    local s = {}
    s.s1, s.s2 = _seedState(seed1, seed2)
    return s
end

-- Advances the state and returns a float in [0, 1).
local function _nextFloat(s)
    s.s1 = (s.s1 * A1) % M1
    s.s2 = (s.s2 * A2) % M2
    local z = (s.s1 - s.s2) % (M1 - 1)
    return z / (M1 - 1)
end

-- LÖVE's three call forms: random(), random(max), random(min, max).
local function _next(s, a, b)
    local r = _nextFloat(s)
    if not a then return r end
    if not b then a, b = 1, a end
    return math.floor(r * (b - a + 1)) + a
end

local function _normal(s, stddev, mean)
    stddev = stddev or 1
    mean   = mean   or 0
    -- Box-Muller transform.
    local u1 = _nextFloat(s)
    local u2 = _nextFloat(s)
    if u1 == 0 then u1 = 1e-10 end
    local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
    return z * stddev + mean
end

-- ── the global generator (love.math.*) ───────────────────────────
-- LÖVE keeps one built-in generator behind love.math.random; it is independent
-- of Lua's own math.random, whose algorithm differs between Lua versions.
local _global = _newState(os.time())

function love.math.setRandomSeed(seed, seed2)
    _global.s1, _global.s2 = _seedState(seed, seed2)
    -- Keep Lua's RNG in step for any game code that calls math.random directly.
    math.randomseed(math.floor(tonumber(seed) or 0))
end

function love.math.getRandomSeed()
    return _global.s1, _global.s2
end

function love.math.random(a, b)
    return _next(_global, a, b)
end

function love.math.randomNormal(stddev, mean)
    return _normal(_global, stddev, mean)
end

-- ── RandomGenerator objects ──────────────────────────────────────
function love.math.newRandomGenerator(seed1, seed2)
    local s = _newState(seed1, seed2)
    local rng = {}

    function rng:setSeed(s1, s2)
        s.s1, s.s2 = _seedState(s1, s2)
    end

    function rng:getSeed()
        return s.s1, s.s2
    end

    function rng:random(a, b)
        return _next(s, a, b)
    end

    function rng:randomNormal(stddev, mean)
        return _normal(s, stddev, mean)
    end

    -- Both state words have to survive a round-trip, so the state is a pair.
    function rng:getState()
        return s.s1 .. "," .. s.s2
    end

    function rng:setState(str)
        local a, b = tostring(str):match("^(%-?%d+),(%-?%d+)$")
        if a then
            -- Restore verbatim (a saved state is already in range); only guard
            -- against the zero fixed point.
            s.s1 = tonumber(a) % M1
            s.s2 = tonumber(b) % M2
            if s.s1 == 0 then s.s1 = 1 end
            if s.s2 == 0 then s.s2 = 1 end
        else
            -- Older saves stored a single number.
            local n = tonumber(str)
            if n then s.s1, s.s2 = _seedState(n) end
        end
    end

    return rng
end
