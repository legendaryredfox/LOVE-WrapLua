function love.math.setRandomSeed(seed)
    math.randomseed(seed)
end

function love.math.random(a, b)
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

-- Simplex-style noise (smooth gradient noise, pure Lua)
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
    return (result + 1) * 0.5  -- normalize to 0..1
end

-- Transform object (2D affine transform)
local Transform = {}
Transform.__index = Transform

function love.math.newTransform(x, y, angle, sx, sy, ox, oy, kx, ky)
    local t = setmetatable({}, Transform)
    t._m = {1,0,0, 0,1,0, 0,0,1}  -- row-major 3x3
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
    t._m = {unpack(self._m)}
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
    m[1], m[2] = m[1]*c + m[4]*s, m[2]*c + m[5]*s
    m[4], m[5] = m[4]*c - m[1]*s, m[5]*c - m[2]*s
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
    m[1], m[2] = m[1] + m[4]*ky, m[2] + m[5]*ky
    m[4], m[5] = m[4] + m[1]*kx, m[5] + m[2]*kx
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
    -- accept 16-element column-major matrix (LÖVE convention)
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

-- Geometry helpers
function love.math.isConvex(vertices)
    local n = #vertices / 2
    if n < 3 then return false end
    local sign = 0
    for i = 1, n do
        local ax, ay = vertices[(i-1)*2+1], vertices[(i-1)*2+2]
        local bx, by = vertices[(i%n)*2+1], vertices[(i%n)*2+2]
        local cx, cy = vertices[((i+1)%n)*2+1], vertices[((i+1)%n)*2+2]
        local cross = (bx-ax)*(cy-ay) - (by-ay)*(cx-ax)
        if cross ~= 0 then
            if sign == 0 then sign = cross > 0 and 1 or -1
            elseif (cross > 0 and sign < 0) or (cross < 0 and sign > 0) then
                return false
            end
        end
    end
    return true
end

function love.math.triangulate(polygon)
    -- Simple ear-clipping triangulation
    local verts = {}
    for i = 1, #polygon, 2 do
        verts[#verts+1] = {polygon[i], polygon[i+1]}
    end
    local triangles = {}
    local idx = {}
    for i = 1, #verts do idx[i] = i end

    local function cross2d(ox, oy, ax, ay, bx, by)
        return (ax-ox)*(by-oy) - (ay-oy)*(bx-ox)
    end
    local function pointInTriangle(px,py, ax,ay, bx,by, cx,cy)
        local d1 = cross2d(px,py,ax,ay,bx,by)
        local d2 = cross2d(px,py,bx,by,cx,cy)
        local d3 = cross2d(px,py,cx,cy,ax,ay)
        local has_neg = (d1<0) or (d2<0) or (d3<0)
        local has_pos = (d1>0) or (d2>0) or (d3>0)
        return not (has_neg and has_pos)
    end

    local iters = 0
    while #idx > 3 do
        iters = iters + 1
        if iters > #idx * 3 then break end
        local n = #idx
        for i = 1, n do
            local prev = idx[((i-2) % n) + 1]
            local curr = idx[i]
            local next = idx[(i % n) + 1]
            local ax,ay = verts[prev][1], verts[prev][2]
            local bx,by = verts[curr][1], verts[curr][2]
            local cx,cy = verts[next][1], verts[next][2]
            if cross2d(ax,ay,bx,by,cx,cy) > 0 then
                local ear = true
                for j = 1, #idx do
                    local v = idx[j]
                    if v ~= prev and v ~= curr and v ~= next then
                        if pointInTriangle(verts[v][1],verts[v][2],ax,ay,bx,by,cx,cy) then
                            ear = false; break
                        end
                    end
                end
                if ear then
                    triangles[#triangles+1] = {ax,ay, bx,by, cx,cy}
                    table.remove(idx, i)
                    break
                end
            end
        end
    end
    if #idx == 3 then
        local a,b,c = verts[idx[1]], verts[idx[2]], verts[idx[3]]
        triangles[#triangles+1] = {a[1],a[2], b[1],b[2], c[1],c[2]}
    end
    return triangles
end

function love.math.newBezierCurve(...)
    local pts = type(select(1,...)) == 'table' and select(1,...) or {...}
    local curve = {}
    curve._pts = pts
    function curve:evaluate(t)
        local p = {}
        for i = 1, #self._pts do p[i] = self._pts[i] end
        local n = #p / 2
        for step = 1, n-1 do
            for i = 1, (n - step) * 2, 2 do
                p[i]   = p[i]   + t * (p[i+2] - p[i])
                p[i+1] = p[i+1] + t * (p[i+3] - p[i+1])
            end
        end
        return p[1], p[2]
    end
    function curve:render(depth)
        depth = depth or 5
        local res = {}
        local steps = 2^depth
        for i = 0, steps do
            local x, y = self:evaluate(i / steps)
            res[#res+1] = x; res[#res+1] = y
        end
        return res
    end
    function curve:getControlPoint(i)
        return self._pts[(i-1)*2+1], self._pts[(i-1)*2+2]
    end
    function curve:getControlPointCount()
        return #self._pts / 2
    end
    function curve:getDegree()
        return #self._pts / 2 - 1
    end
    return curve
end

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

function love.math.colorFromBytes(r, g, b, a)
    return r/255, g/255, b/255, (a or 255)/255
end

function love.math.colorToBytes(r, g, b, a)
    return math.floor(r*255+0.5), math.floor(g*255+0.5),
           math.floor(b*255+0.5), math.floor((a or 1)*255+0.5)
end

function love.math.gammaToLinear(r, g, b, a)
    local function f(v) return v <= 0.04045 and v/12.92 or ((v+0.055)/1.055)^2.4 end
    if type(r) == 'table' then
        return {f(r[1]), f(r[2]), f(r[3]), r[4] or 1}
    end
    return f(r), f(g), f(b), a
end

function love.math.linearToGamma(r, g, b, a)
    local function f(v) return v <= 0.0031308 and v*12.92 or 1.055*v^(1/2.4)-0.055 end
    if type(r) == 'table' then
        return {f(r[1]), f(r[2]), f(r[3]), r[4] or 1}
    end
    return f(r), f(g), f(b), a
end
