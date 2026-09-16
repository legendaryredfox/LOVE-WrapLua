-- OneLua graphics: primitive shapes.
--
-- Only rectangles and filled circles are native; everything else is built from
-- line segments here.

local stack = lv1lua.gfx.transform

function love.graphics.rectangle(mode, x, y, w, h, rx, ry)
    stack:updateTransform()
    local t = stack.transform
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        local s = lv1lua.gfx.scale
        x=x*s; y=y*s; w=w*s; h=h*s
    end
    local W = w * t._scaleX
    local H = h * t._scaleY
    if mode == "fill" then
        draw.fillrect(x, y, W, H, lv1lua.current.color)
    elseif mode == "line" then
        draw.rect(x, y, W, H, lv1lua.current.color)
    end
end

function love.graphics.line(...)
    local coords
    if type(select(1,...)) == "table" then coords = select(1,...)
    else coords = {...} end
    for i = 1, #coords - 2, 2 do
        draw.line(coords[i], coords[i+1], coords[i+2], coords[i+3], lv1lua.current.color)
    end
end

function love.graphics.circle(mode, x, y, radius, segments)
    stack:updateTransform()
    segments = segments or 32
    local r = radius * stack.transform._scaleX
    if mode == "fill" then
        draw.circle(x, y, r, lv1lua.current.color, segments)
    else
        -- No native circle outline: approximate with line segments.
        local pts = {}
        for i = 0, segments do
            local a = i / segments * math.pi * 2
            pts[#pts+1] = x + r * math.cos(a)
            pts[#pts+1] = y + r * math.sin(a)
        end
        love.graphics.polygon("line", pts)
    end
end

function love.graphics.ellipse(mode, x, y, rx, ry, segments)
    ry = ry or rx
    segments = segments or 32
    local pts = {}
    for i = 0, segments do
        local a = i / segments * math.pi * 2
        pts[#pts+1] = x + rx * math.cos(a)
        pts[#pts+1] = y + ry * math.sin(a)
    end
    love.graphics.polygon(mode, pts)
end

local function fillSpan(x, y, w, color) draw.fillrect(x, y, w, 1, color) end

function love.graphics.polygon(mode, vertices, ...)
    local v = type(vertices) == "table" and vertices or {vertices, ...}
    if #v < 4 then return end
    if mode == "fill" then
        -- Scanline fill through the shared even-odd rasteriser, correct for
        -- convex and concave polygons alike.
        lv1lua.core.fillPolygon(v, fillSpan, lv1lua.current.color)
    else
        for i = 1, #v - 2, 2 do
            draw.line(v[i], v[i+1], v[i+2], v[i+3], lv1lua.current.color)
        end
        draw.line(v[#v-1], v[#v], v[1], v[2], lv1lua.current.color)  -- close
    end
end

function love.graphics.arc(mode, arctype, x, y, radius, angle1, angle2, segments)
    -- Old LÖVE signature: arc(mode, x, y, radius, angle1, angle2, segments)
    if type(arctype) == "number" then
        segments = angle2; angle2 = angle1; angle1 = radius
        radius   = arctype; y = x; x = mode
        arctype  = "pie"; mode = "line"
    end
    arctype  = arctype  or "pie"
    segments = segments or 12
    local pts = {}
    if arctype == "pie" then
        pts[#pts+1] = x; pts[#pts+1] = y
    end
    for i = 0, segments do
        local a = angle1 + (angle2 - angle1) * i / segments
        pts[#pts+1] = x + radius * math.cos(a)
        pts[#pts+1] = y + radius * math.sin(a)
    end
    if arctype == "closed" then
        pts[#pts+1] = pts[1]; pts[#pts+1] = pts[2]
    end
    love.graphics.polygon(mode, pts)
end

function love.graphics.points(...)
    local coords
    if type(select(1,...)) == "table" then coords = select(1,...)
    else coords = {...} end
    for i = 1, #coords - 1, 2 do
        draw.fillrect(coords[i], coords[i+1], 1, 1, lv1lua.current.color)
    end
end
