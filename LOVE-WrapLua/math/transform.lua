-- love.math.newTransform: 2D affine transform object.
--
-- The matrix is stored row-major as a flat 3x3 (`_m`); LÖVE's get/setMatrix
-- speak the 16-element column-major form, so those two convert.

local _unpack = table.unpack or unpack

local Transform = {}
Transform.__index = Transform

function love.math.newTransform(x, y, angle, sx, sy, ox, oy, kx, ky)
    local t = setmetatable({}, Transform)
    t._m = {1,0,0, 0,1,0, 0,0,1}
    if x then t:setTransformation(x, y, angle, sx, sy, ox, oy, kx, ky) end
    return t
end

function Transform:setTransformation(x, y, angle, sx, sy, ox, oy, kx, ky)
    x   = x   or 0; y   = y   or 0
    angle = angle or 0
    sx  = sx  or 1; sy  = sy  or sx
    ox  = ox  or 0; oy  = oy  or 0
    kx  = kx  or 0; ky  = ky  or 0
    local c, s = math.cos(angle), math.sin(angle)
    -- Combine: translate * rotate * scale * shear * origin-offset
    self._m[1] = c * sx - ky * s * sy
    self._m[2] = s * sx + ky * c * sy
    self._m[3] = 0
    self._m[4] = kx * c * sx - s * sy
    self._m[5] = kx * s * sx + c * sy
    self._m[6] = 0
    self._m[7] = x - ox * self._m[1] - oy * self._m[4]
    self._m[8] = y - ox * self._m[2] - oy * self._m[5]
    self._m[9] = 1
    return self
end

function Transform:clone()
    local t = setmetatable({}, Transform)
    t._m = {_unpack(self._m)}
    return t
end

function Transform:reset()
    self._m = {1,0,0, 0,1,0, 0,0,1}
    return self
end

function Transform:translate(x, y)
    self._m[7] = self._m[7] + self._m[1]*x + self._m[4]*y
    self._m[8] = self._m[8] + self._m[2]*x + self._m[5]*y
    return self
end

function Transform:rotate(angle)
    local c, s = math.cos(angle), math.sin(angle)
    local m = self._m
    -- Cache the original columns: the second must use the OLD first, otherwise
    -- two successive rotates compose wrongly.
    local m1, m2, m4, m5 = m[1], m[2], m[4], m[5]
    m[1], m[2] = m1*c + m4*s, m2*c + m5*s
    m[4], m[5] = m4*c - m1*s, m5*c - m2*s
    return self
end

function Transform:scale(sx, sy)
    sy = sy or sx
    self._m[1] = self._m[1] * sx
    self._m[2] = self._m[2] * sx
    self._m[4] = self._m[4] * sy
    self._m[5] = self._m[5] * sy
    return self
end

function Transform:shear(kx, ky)
    local m = self._m
    -- Cache the original columns; each output column mixes the OLD other one.
    local m1, m2, m4, m5 = m[1], m[2], m[4], m[5]
    m[1], m[2] = m1 + m4*ky, m2 + m5*ky
    m[4], m[5] = m4 + m1*kx, m5 + m2*kx
    return self
end

function Transform:apply(other)
    local a, b = self._m, other._m
    self._m = {
        a[1]*b[1]+a[4]*b[2]+a[7]*b[3],
        a[2]*b[1]+a[5]*b[2]+a[8]*b[3],
        0,
        a[1]*b[4]+a[4]*b[5]+a[7]*b[6],
        a[2]*b[4]+a[5]*b[5]+a[8]*b[6],
        0,
        a[1]*b[7]+a[4]*b[8]+a[7]*b[9],
        a[2]*b[7]+a[5]*b[8]+a[8]*b[9],
        1,
    }
    return self
end

function Transform:transformPoint(x, y)
    local m = self._m
    return m[1]*x + m[4]*y + m[7], m[2]*x + m[5]*y + m[8]
end

function Transform:inverseTransformPoint(x, y)
    local m = self._m
    local det = m[1]*m[5] - m[2]*m[4]
    if det == 0 then return x, y end
    local ix = (m[5]*(x-m[7]) - m[4]*(y-m[8])) / det
    local iy = (m[1]*(y-m[8]) - m[2]*(x-m[7])) / det
    return ix, iy
end

function Transform:getMatrix()
    local m = self._m
    return m[1],m[2],0,0, m[4],m[5],0,0, 0,0,1,0, m[7],m[8],0,1
end

function Transform:setMatrix(...)
    -- Accepts the 16-element column-major matrix LÖVE uses.
    local v = {...}
    self._m[1] = v[1]  or 1
    self._m[2] = v[2]  or 0
    self._m[4] = v[5]  or 0
    self._m[5] = v[6]  or 1
    self._m[7] = v[13] or 0
    self._m[8] = v[14] or 0
    return self
end

function Transform:isAffine2DTransform() return true end
