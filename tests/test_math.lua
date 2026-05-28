local T = dofile("tests/runner.lua")
dofile("tests/mock_platform.lua")
dofile("LOVE-WrapLua/math.lua")

-- ── love.math.random ─────────────────────────────────────────────
T.describe("love.math.random", function()
    T.it("no args returns float in [0,1)", function()
        local v = love.math.random()
        T.inrange(v, 0, 1)
    end)

    T.it("random(n) returns integer in [1,n]", function()
        local v = love.math.random(10)
        T.ok(v == math.floor(v), "should be integer")
        T.inrange(v, 1, 10)
    end)

    T.it("random(a,b) returns integer in [a,b]", function()
        local v = love.math.random(5, 15)
        T.ok(v == math.floor(v), "should be integer")
        T.inrange(v, 5, 15)
    end)

    T.it("setRandomSeed does not crash", function()
        love.math.setRandomSeed(42)
        local v = love.math.random()
        T.istype(v, "number")
    end)
end)

-- ── love.math.randomNormal ───────────────────────────────────────
T.describe("love.math.randomNormal", function()
    T.it("returns a number", function()
        T.istype(love.math.randomNormal(), "number")
    end)

    T.it("mean parameter shifts output on average", function()
        love.math.setRandomSeed(1)
        local sum = 0
        for _ = 1, 200 do sum = sum + love.math.randomNormal(1, 100) end
        -- average should be near 100
        T.inrange(sum / 200, 90, 110)
    end)
end)

-- ── love.math.noise ──────────────────────────────────────────────
T.describe("love.math.noise", function()
    T.it("1D noise returns value in [0,1]", function()
        T.inrange(love.math.noise(0.5), 0, 1)
    end)

    T.it("2D noise returns value in [0,1]", function()
        T.inrange(love.math.noise(1.2, 3.4), 0, 1)
    end)

    T.it("3D noise returns value in [0,1]", function()
        T.inrange(love.math.noise(1.2, 3.4, 5.6), 0, 1)
    end)

    T.it("same inputs produce same output", function()
        local a = love.math.noise(7.7, 2.1)
        local b = love.math.noise(7.7, 2.1)
        T.eq(a, b)
    end)

    T.it("different inputs generally produce different output", function()
        local a = love.math.noise(0.1, 0.1)
        local b = love.math.noise(10.1, 10.1)
        T.ok(a ~= b, "noise should differ for far-apart inputs")
    end)
end)

-- ── love.math.newTransform ───────────────────────────────────────
T.describe("love.math.newTransform", function()
    T.it("identity transform does not change point", function()
        local tf = love.math.newTransform()
        local x, y = tf:transformPoint(5, 3)
        T.near(x, 5)
        T.near(y, 3)
    end)

    T.it("translate shifts point", function()
        local tf = love.math.newTransform(10, 20)
        local x, y = tf:transformPoint(0, 0)
        T.near(x, 10)
        T.near(y, 20)
    end)

    T.it("scale multiplies point", function()
        local tf = love.math.newTransform(0, 0, 0, 2, 3)
        local x, y = tf:transformPoint(4, 5)
        T.near(x, 8)
        T.near(y, 15)
    end)

    T.it("rotate 90° maps (1,0) to (0,1)", function()
        local tf = love.math.newTransform(0, 0, math.pi / 2)
        local x, y = tf:transformPoint(1, 0)
        T.near(x, 0, 1e-5)
        T.near(y, 1, 1e-5)
    end)

    T.it("inverseTransformPoint undoes transformPoint", function()
        local tf = love.math.newTransform(30, -10, 0, 2, 2)
        local px, py = 7, 13
        local tx, ty = tf:transformPoint(px, py)
        local ix, iy = tf:inverseTransformPoint(tx, ty)
        T.near(ix, px, 1e-5)
        T.near(iy, py, 1e-5)
    end)

    T.it("clone is independent", function()
        local tf  = love.math.newTransform(5, 5)
        local tf2 = tf:clone()
        tf2:translate(100, 100)
        local x1 = tf:transformPoint(0, 0)
        local x2 = tf2:transformPoint(0, 0)
        T.ok(x1 ~= x2, "clone mutations should not affect original")
    end)

    T.it("reset returns to identity", function()
        local tf = love.math.newTransform(50, 50)
        tf:reset()
        local x, y = tf:transformPoint(3, 4)
        T.near(x, 3)
        T.near(y, 4)
    end)

    T.it("getMatrix returns 16 numbers", function()
        local tf = love.math.newTransform()
        local m = { tf:getMatrix() }
        T.eq(#m, 16)
    end)
end)

-- ── love.math.newBezierCurve ─────────────────────────────────────
T.describe("love.math.newBezierCurve", function()
    T.it("evaluate at t=0 returns first control point", function()
        local b = love.math.newBezierCurve({0,0, 50,100, 100,0})
        local x, y = b:evaluate(0)
        T.near(x, 0)
        T.near(y, 0)
    end)

    T.it("evaluate at t=1 returns last control point", function()
        local b = love.math.newBezierCurve({0,0, 50,100, 100,0})
        local x, y = b:evaluate(1)
        T.near(x, 100)
        T.near(y, 0)
    end)

    T.it("render returns a table of coordinates", function()
        local b = love.math.newBezierCurve({0,0, 50,100, 100,0})
        local pts = b:render(2)
        T.ok(#pts >= 4, "should return multiple points")
        T.eq(#pts % 2, 0, "should be x,y pairs")
    end)
end)

-- ── love.math.newRandomGenerator ─────────────────────────────────
T.describe("love.math.newRandomGenerator", function()
    T.it("random() returns a float in [0,1)", function()
        local rng = love.math.newRandomGenerator(99)
        T.inrange(rng:random(), 0, 1)
    end)

    T.it("same seed produces same sequence", function()
        local r1 = love.math.newRandomGenerator(7)
        local r2 = love.math.newRandomGenerator(7)
        T.eq(r1:random(), r2:random())
    end)
end)

-- ── love.math.isConvex ───────────────────────────────────────────
T.describe("love.math.isConvex", function()
    T.it("square is convex", function()
        T.ok(love.math.isConvex({0,0, 1,0, 1,1, 0,1}))
    end)

    T.it("star (concave) returns false", function()
        -- Simple non-convex: a concave polygon
        T.nok(love.math.isConvex({0,0, 2,1, 1,0, 2,-1}))
    end)
end)

-- ── love.math.triangulate ────────────────────────────────────────
T.describe("love.math.triangulate", function()
    T.it("square yields 2 triangles", function()
        local tris = love.math.triangulate({0,0, 1,0, 1,1, 0,1})
        T.eq(#tris, 2)
    end)

    T.it("each triangle has 3 vertex pairs (6 numbers)", function()
        local tris = love.math.triangulate({0,0, 1,0, 1,1, 0,1})
        for _, tri in ipairs(tris) do
            T.eq(#tri, 6)
        end
    end)
end)

-- ── love.math.colorFromBytes / colorToBytes ───────────────────────
T.describe("love.math.colorFromBytes/colorToBytes", function()
    T.it("colorFromBytes(255,0,0) returns {1,0,0,1}", function()
        local r, g, b, a = love.math.colorFromBytes(255, 0, 0)
        T.near(r, 1); T.near(g, 0); T.near(b, 0)
    end)

    T.it("colorToBytes(1,0,0) returns {255,0,0,255}", function()
        local r, g, b, a = love.math.colorToBytes(1, 0, 0)
        T.eq(r, 255); T.eq(g, 0); T.eq(b, 0)
    end)

    T.it("roundtrip: colorToBytes(colorFromBytes(r,g,b)) == original", function()
        local r0, g0, b0 = 128, 64, 200
        local r, g, b = love.math.colorFromBytes(r0, g0, b0)
        local R, G, B = love.math.colorToBytes(r, g, b)
        T.eq(R, r0); T.eq(G, g0); T.eq(B, b0)
    end)
end)

-- ── love.math.gammaToLinear / linearToGamma ───────────────────────
T.describe("love.math.gammaToLinear/linearToGamma", function()
    T.it("gammaToLinear(1) == 1", function()
        T.near(love.math.gammaToLinear(1), 1)
    end)

    T.it("linearToGamma(1) == 1", function()
        T.near(love.math.linearToGamma(1), 1)
    end)

    T.it("roundtrip: linearToGamma(gammaToLinear(v)) ≈ v", function()
        local v = 0.5
        T.near(love.math.linearToGamma(love.math.gammaToLinear(v)), v, 1e-4)
    end)
end)

io.write("\n=== love.math ===\n")
return T.summary()
