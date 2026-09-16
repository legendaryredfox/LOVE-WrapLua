-- PSP graphics: primitive shapes.
--
-- Native order here is the plain (x1, y1, x2, y2) of OneLua's draw.* calls,
-- unlike lpp-vita, which wants both x values first.

function love.graphics.rectangle(mode, x, y, w, h)
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        local s = lv1lua.gfx.scale
        x=x*s; y=y*s; w=w*s; h=h*s
    end
    if mode == "fill" then
        draw.fillrect(x, y, w, h, lv1lua.current.color)
    elseif mode == "line" then
        draw.rect(x, y, w, h, lv1lua.current.color)
    end
end

function love.graphics.line(...)
    local c = type(select(1,...)) == "table" and select(1,...) or {...}
    for i = 1, #c-2, 2 do
        draw.line(c[i], c[i+1], c[i+2], c[i+3], lv1lua.current.color)
    end
end

function love.graphics.circle(mode, x, y, radius, segments)
    if mode == "fill" then
        draw.circle(x, y, radius, lv1lua.current.color, segments or 32)
    else
        local r, s = radius, segments or 32
        for i = 0, s-1 do
            local a1, a2 = i/s*math.pi*2, (i+1)/s*math.pi*2
            draw.line(x+r*math.cos(a1), y+r*math.sin(a1),
                      x+r*math.cos(a2), y+r*math.sin(a2),
                      lv1lua.current.color)
        end
    end
end

function love.graphics.ellipse(mode, x, y, rx, ry, segments)
    ry = ry or rx; segments = segments or 32
    local pts = {}
    for i = 0, segments do
        local a = i/segments*math.pi*2
        pts[#pts+1] = x + rx*math.cos(a)
        pts[#pts+1] = y + ry*math.sin(a)
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
        for i = 1, #v-2, 2 do
            draw.line(v[i], v[i+1], v[i+2], v[i+3], lv1lua.current.color)
        end
        draw.line(v[#v-1], v[#v], v[1], v[2], lv1lua.current.color)  -- close
    end
end

function love.graphics.arc(mode, arctype, x, y, radius, angle1, angle2, segments)
    -- Old LÖVE signature: arc(mode, x, y, radius, angle1, angle2, segments)
    if type(arctype) == "number" then
        segments=angle2; angle2=angle1; angle1=radius
        radius=arctype; y=x; x=mode
        arctype="pie"; mode="line"
    end
    segments = segments or 12
    local pts = {}
    if (arctype or "pie") == "pie" then pts[1] = x; pts[2] = y end
    for i = 0, segments do
        local a = angle1 + (angle2-angle1)*i/segments
        pts[#pts+1] = x + radius*math.cos(a)
        pts[#pts+1] = y + radius*math.sin(a)
    end
    love.graphics.polygon(mode, pts)
end

function love.graphics.points(...)
    local c = type(select(1,...)) == "table" and select(1,...) or {...}
    for i = 1, #c-1, 2 do
        draw.fillrect(c[i], c[i+1], 1, 1, lv1lua.current.color)
    end
end
