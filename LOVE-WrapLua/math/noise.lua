-- love.math.noise — Perlin gradient noise, pure Lua.
--
-- Known limitations: the 4th dimension (`w`) is ignored, and loading this file
-- reseeds the global RNG to build the permutation table. Both are FIX_PLAN
-- T4.1.

local _noisePerm = {}
do
    local p = {}
    for i = 0, 255 do p[i] = i end
    math.randomseed(12345)
    for i = 255, 1, -1 do
        local j = math.random(0, i)
        p[i], p[j] = p[j], p[i]
    end
    for i = 0, 511 do _noisePerm[i] = p[i % 256] end
end

local function _fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end
local function _lerp(t, a, b) return a + t * (b - a) end
local function _grad(h, x, y, z)
    h = h % 16
    local u = h < 8 and x or y
    local v = h < 4 and y or (h == 12 or h == 14) and x or z
    return ((h % 2 == 0) and u or -u) + ((h < 16 and h % 4 < 2) and v or -v)
end

function love.math.noise(x, y, z, w)
    y = y or 0; z = z or 0
    local X = math.floor(x) % 256
    local Y = math.floor(y) % 256
    local Z = math.floor(z) % 256
    x = x - math.floor(x)
    y = y - math.floor(y)
    z = z - math.floor(z)
    local u, v, t_ = _fade(x), _fade(y), _fade(z)
    local A  = _noisePerm[X]   + Y
    local AA = _noisePerm[A]   + Z
    local AB = _noisePerm[A+1] + Z
    local B  = _noisePerm[X+1] + Y
    local BA = _noisePerm[B]   + Z
    local BB = _noisePerm[B+1] + Z
    local result = _lerp(t_,
        _lerp(v,
            _lerp(u, _grad(_noisePerm[AA],   x,   y,   z),
                     _grad(_noisePerm[BA],   x-1, y,   z)),
            _lerp(u, _grad(_noisePerm[AB],   x,   y-1, z),
                     _grad(_noisePerm[BB],   x-1, y-1, z))),
        _lerp(v,
            _lerp(u, _grad(_noisePerm[AA+1], x,   y,   z-1),
                     _grad(_noisePerm[BA+1], x-1, y,   z-1)),
            _lerp(u, _grad(_noisePerm[AB+1], x,   y-1, z-1),
                     _grad(_noisePerm[BB+1], x-1, y-1, z-1))))
    return (result + 1) * 0.5  -- normalise to 0..1
end
