-- love.math: polygon and curve helpers.

function love.math.isConvex(vertices)
    local n = #vertices / 2
    if n < 3 then return false end
    -- Convex iff every consecutive cross product has the same sign.
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

-- Ear clipping: repeatedly snip off a corner that contains no other vertex.
function love.math.triangulate(polygon)
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

    -- Bail out rather than spin forever on a degenerate polygon.
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

-- De Casteljau evaluation; no subdivision caching, so render() is O(2^depth).
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
