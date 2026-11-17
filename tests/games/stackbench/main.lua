-- Where should the transform stack live on the native PSP backend? The same synthetic frame (the mix of
-- tests/bench/frame_cost.lua: 213 push/translate/scale/pop groups, 124 quad draws, 168 setColor, 54 polygon
-- fills, 45 prints) runs two ways and the mean frame time of each is logged:
--   "C":   love.graphics.push / translate / scale / pop go to the C engine, which applies the matrix.
--   "Lua": a software stack in this file keeps the levels and every draw is placed with the flattened result,
--          the C matrix is never touched (what core/transform.lua does on the other backends).
-- Package with a player.png next to this file and read psp_log.txt.

local g = love.graphics
local img, quad, font
local pts = { 0, 0, 10, 0, 12, 6, 6, 12, 0, 6 }

-- ── software stack (offset and scale per level, flattened outermost first) ──
local stack, free, dirty = {}, {}, true
local flat = { x = 0, y = 0, sx = 1, sy = 1 }
local function lpush()
    local n = #free
    local lv
    if n > 0 then lv = free[n]; free[n] = nil; lv.ox, lv.oy, lv.sx, lv.sy = 0, 0, 1, 1
    else lv = { ox = 0, oy = 0, sx = 1, sy = 1 } end
    stack[#stack + 1] = lv
    dirty = true
end
local function lpop()
    local n = #stack
    if n > 0 then free[#free + 1] = stack[n]; stack[n] = nil; dirty = true end
end
local function ltranslate(dx, dy)
    local t = stack[#stack]
    t.ox = t.ox + t.sx * dx
    t.oy = t.oy + t.sy * dy
    dirty = true
end
local function lscale(sx, sy)
    local t = stack[#stack]
    t.sx = t.sx * sx
    t.sy = t.sy * (sy or sx)
    dirty = true
end
local function lflatten()
    if not dirty then return end
    local x, y, sx, sy = 0, 0, 1, 1
    for i = 1, #stack do
        local t = stack[i]
        x = x + sx * t.ox
        y = y + sy * t.oy
        sx = sx * t.sx
        sy = sy * t.sy
    end
    flat.x, flat.y, flat.sx, flat.sy = x, y, sx, sy
    dirty = false
end
local mapped = {}
local function ldraw(i, x, y, r, sx, sy, ox, oy)
    lflatten()
    g.draw(img, quad, x * flat.sx + flat.x, y * flat.sy + flat.y, r, sx * flat.sx, sy * flat.sy, ox, oy)
end
local function lpoly()
    lflatten()
    local fx, fy, fsx, fsy = flat.x, flat.y, flat.sx, flat.sy
    for i = 1, #pts, 2 do mapped[i] = pts[i] * fsx + fx; mapped[i + 1] = pts[i + 1] * fsy + fy end
    g.polygon("fill", mapped)
end
local function lprint(s, x, y)
    lflatten()
    g.print(s, x * flat.sx + flat.x, y * flat.sy + flat.y)
end

local function frameC()
    for i = 1, 213 do g.push(); g.translate(i % 7, i % 5); g.scale(1.01, 1.01); g.pop() end
    for i = 1, 168 do g.setColor((i % 5) / 4, (i % 3) / 2, 0.5, 1) end
    g.push(); g.translate(20, 20); g.scale(1.5, 1.5)
    for i = 1, 124 do
        if i % 20 < 12 then g.draw(img, quad, i, 10)
        elseif i % 20 < 17 then g.draw(img, quad, i, 10, 0, 2, 2)
        else g.draw(img, quad, i, 10, 0.4, 1.5, 1.5, 8, 8) end
    end
    for _ = 1, 54 do g.polygon("fill", pts) end
    for i = 1, 45 do g.print("Score", i, 20) end
    g.pop()
end

local function frameL()
    for i = 1, 213 do lpush(); ltranslate(i % 7, i % 5); lscale(1.01, 1.01); lpop() end
    for i = 1, 168 do g.setColor((i % 5) / 4, (i % 3) / 2, 0.5, 1) end
    lpush(); ltranslate(20, 20); lscale(1.5, 1.5)
    for i = 1, 124 do
        if i % 20 < 12 then ldraw(img, i, 10, 0, 1, 1, 0, 0)
        elseif i % 20 < 17 then ldraw(img, i, 10, 0, 2, 2, 0, 0)
        else ldraw(img, i, 10, 0.4, 1.5, 1.5, 8, 8) end
    end
    for _ = 1, 54 do lpoly() end
    for i = 1, 45 do lprint("Score", i, 20) end
    lpop()
end

local variants = { { "C", frameC }, { "Lua", frameL } }
local vi, frames, warm, sample = 1, 0, 8, 40
local t0, sum = 0, 0

function love.load()
    img = g.newImage("player.png")
    quad = g.newQuad(0, 0, 16, 16, img:getWidth(), img:getHeight())
    font = g.newFont(12)
    g.setFont(font)
    lpush()
end

function love.update() end

function love.draw()
    local name, fn = variants[vi][1], variants[vi][2]
    local t = love.timer.getTime()
    fn()
    local dt = love.timer.getTime() - t
    frames = frames + 1
    if frames > warm then sum = sum + dt end
    if frames == warm + sample then
        PSP_LOG(string.format("STACKBENCH %s mean_draw_ms=%.2f", name, sum / sample * 1000))
        vi, frames, sum = vi + 1, 0, 0
        if vi > #variants then PSP_LOG("STACKBENCH done"); love.event.quit() end
    end
end
