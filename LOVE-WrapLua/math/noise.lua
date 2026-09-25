-- love.math.noise: Perlin gradient noise, pure Lua.
--
-- Loads after math/random.lua, whose generator is used to shuffle the
-- permutation table. That matters twice over: it keeps the shuffle off the
-- global RNG (loading this file used to call math.randomseed(12345), silently
-- resetting the game's random stream), and it makes the table identical on
-- every Lua version, since Lua's own math.random algorithm is not.

local PERM_SIZE = 256

local _perm = {}
do
    -- Fixed seed: the permutation must be the same on every run and platform.
    local rng = love.math.newRandomGenerator(12345, 67890)
    local p = {}
    for i = 0, PERM_SIZE - 1 do p[i] = i end
    -- Fisher-Yates.
    for i = PERM_SIZE - 1, 1, -1 do
        local j = rng:random(i + 1) - 1
        p[i], p[j] = p[j], p[i]
    end
    -- Doubled, so the lookups below can index up to 511 without wrapping.
    for i = 0, (PERM_SIZE * 2) - 1 do _perm[i] = p[i % PERM_SIZE] end
end

local function _fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end
local function _lerp(t, a, b) return a + t * (b - a) end

local function _grad3(h, x, y, z)
    h = h % 16
    local u = h < 8 and x or y
    local v = h < 4 and y or (h == 12 or h == 14) and x or z
    return ((h % 2 == 0) and u or -u) + ((h < 16 and h % 4 < 2) and v or -v)
end

-- Perlin's 32 four-dimensional gradients: every vector with one zero component
-- and three of +/-1.
local GRAD4 = {
    { 0, 1, 1, 1}, { 0, 1, 1,-1}, { 0, 1,-1, 1}, { 0, 1,-1,-1},
    { 0,-1, 1, 1}, { 0,-1, 1,-1}, { 0,-1,-1, 1}, { 0,-1,-1,-1},
    { 1, 0, 1, 1}, { 1, 0, 1,-1}, { 1, 0,-1, 1}, { 1, 0,-1,-1},
    {-1, 0, 1, 1}, {-1, 0, 1,-1}, {-1, 0,-1, 1}, {-1, 0,-1,-1},
    { 1, 1, 0, 1}, { 1, 1, 0,-1}, { 1,-1, 0, 1}, { 1,-1, 0,-1},
    {-1, 1, 0, 1}, {-1, 1, 0,-1}, {-1,-1, 0, 1}, {-1,-1, 0,-1},
    { 1, 1, 1, 0}, { 1, 1,-1, 0}, { 1,-1, 1, 0}, { 1,-1,-1, 0},
    {-1, 1, 1, 0}, {-1, 1,-1, 0}, {-1,-1, 1, 0}, {-1,-1,-1, 0},
}

local function _grad4(h, x, y, z, w)
    local g = GRAD4[(h % 32) + 1]
    return g[1]*x + g[2]*y + g[3]*z + g[4]*w
end

local function _noise3(x, y, z)
    local X = math.floor(x) % PERM_SIZE
    local Y = math.floor(y) % PERM_SIZE
    local Z = math.floor(z) % PERM_SIZE
    x = x - math.floor(x)
    y = y - math.floor(y)
    z = z - math.floor(z)
    local u, v, t_ = _fade(x), _fade(y), _fade(z)
    local A  = _perm[X]   + Y
    local AA = _perm[A]   + Z
    local AB = _perm[A+1] + Z
    local B  = _perm[X+1] + Y
    local BA = _perm[B]   + Z
    local BB = _perm[B+1] + Z
    return _lerp(t_,
        _lerp(v,
            _lerp(u, _grad3(_perm[AA],   x,   y,   z),
                     _grad3(_perm[BA],   x-1, y,   z)),
            _lerp(u, _grad3(_perm[AB],   x,   y-1, z),
                     _grad3(_perm[BB],   x-1, y-1, z))),
        _lerp(v,
            _lerp(u, _grad3(_perm[AA+1], x,   y,   z-1),
                     _grad3(_perm[BA+1], x-1, y,   z-1)),
            _lerp(u, _grad3(_perm[AB+1], x,   y-1, z-1),
                     _grad3(_perm[BB+1], x-1, y-1, z-1))))
end

-- Four-dimensional Perlin: interpolate the 16 lattice corners. Written as a
-- loop over the corners rather than 15 nested lerps, which on a PSP is both
-- readable and no slower than the unrolled form.
local function _noise4(x, y, z, w)
    local X = math.floor(x) % PERM_SIZE
    local Y = math.floor(y) % PERM_SIZE
    local Z = math.floor(z) % PERM_SIZE
    local W = math.floor(w) % PERM_SIZE
    local fx = x - math.floor(x)
    local fy = y - math.floor(y)
    local fz = z - math.floor(z)
    local fw = w - math.floor(w)
    local u, v, s, t = _fade(fx), _fade(fy), _fade(fz), _fade(fw)

    -- Gradient contribution of one corner of the unit hypercube.
    local function corner(dx, dy, dz, dw)
        local h = _perm[(_perm[(_perm[(_perm[(X+dx) % PERM_SIZE]
                   + Y+dy) % PERM_SIZE] + Z+dz) % PERM_SIZE] + W+dw) % PERM_SIZE]
        return _grad4(h, fx-dx, fy-dy, fz-dz, fw-dw)
    end

    -- Collapse w, then z, then y, then x.
    local function alongW(dx, dy, dz)
        return _lerp(t, corner(dx,dy,dz,0), corner(dx,dy,dz,1))
    end
    local function alongZ(dx, dy)
        return _lerp(s, alongW(dx,dy,0), alongW(dx,dy,1))
    end
    local function alongY(dx)
        return _lerp(v, alongZ(dx,0), alongZ(dx,1))
    end
    return _lerp(u, alongY(0), alongY(1))
end

-- LOVE accepts 1 to 4 dimensions and returns 0..1.
function love.math.noise(x, y, z, w)
    if w ~= nil then
        return (_noise4(x, y or 0, z or 0, w) + 1) * 0.5
    end
    return (_noise3(x, y or 0, z or 0) + 1) * 0.5
end
