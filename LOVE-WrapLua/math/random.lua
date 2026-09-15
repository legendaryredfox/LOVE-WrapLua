-- love.math: randomness.

function love.math.setRandomSeed(seed)
    math.randomseed(seed)
end

function love.math.random(a, b)
    if a == nil then return math.random() end
    if b == nil then return math.random(a) end
    return math.random(a, b)
end

function love.math.randomNormal(stddev, mean)
    stddev = stddev or 1
    mean   = mean   or 0
    -- Box-Muller transform
    local u1 = math.random()
    local u2 = math.random()
    if u1 == 0 then u1 = 1e-10 end
    local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
    return z * stddev + mean
end

-- Known limitation: this LCG overflows a double past 2^53 and ignores seed2.
-- Replacing it with a 53-bit-safe generator is FIX_PLAN T3.4.
function love.math.newRandomGenerator(seed1, seed2)
    local rng = {}
    local state = seed1 or os.time()
    function rng:setSeed(s1, s2) state = s1 end
    function rng:random(a, b)
        state = (state * 1103515245 + 12345) % (2^32)
        local r = state / (2^32)
        if not a then return r end
        if not b then return math.floor(r * a) + 1 end
        return math.floor(r * (b - a + 1)) + a
    end
    function rng:randomNormal(stddev, mean)
        return love.math.randomNormal(stddev, mean)
    end
    function rng:getState()  return tostring(state) end
    function rng:setState(s) state = tonumber(s) or state end
    return rng
end
