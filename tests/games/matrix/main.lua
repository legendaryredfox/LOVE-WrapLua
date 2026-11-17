-- Checks the C matrix stack against hand-computed answers on the console and logs MATRIX ok / MATRIX FAIL lines.
local g = love.graphics
local function near(a, b) return math.abs(a - b) < 1e-3 end
local fails = 0
local function check(name, cond)
    if not cond then fails = fails + 1 end
    PSP_LOG("MATRIX " .. (cond and "ok   " or "FAIL ") .. name)
end

function love.load()
    g.origin(); g.shear(0.5, 0.25)
    local x, y = g.transformPoint(4, 8)
    check("shear", near(x, 8) and near(y, 9))
    g.origin(); g.rotate(math.pi / 2); g.translate(10, 0)
    x, y = g.transformPoint(0, 0)
    check("rotate then translate", near(x, 0) and near(y, 10))
    g.origin(); g.translate(10, 20); g.scale(2, 3); g.rotate(0.4); g.shear(0.5, 0.2)
    local sx, sy = g.transformPoint(7, -3)
    x, y = g.inverseTransformPoint(sx, sy)
    check("inverse", near(x, 7) and near(y, -3))
    g.origin(); g.translate(5, 6); g.push(); g.scale(2); g.pop()
    x, y = g.transformPoint(1, 1)
    check("push pop", near(x, 6) and near(y, 7))
    g.origin()
    PSP_LOG("MATRIX done fails=" .. fails)
    love.event.quit()
end
