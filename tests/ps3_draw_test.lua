-- PS3 first-class graphics (FIX_PLAN T6.6).
-- Verifies that the PS3 backend now draws textured quads via tiny3D instead of
-- the old BlitToScreen stub, that the transform stack works, that setColor
-- tints through VertexColor, that quads carry non-trivial UV, that print
-- reaches gfx.FontDrawString, and that filled primitives call gfx.SetPolygon.

local T = dofile("tests/runner.lua")

local function fresh()
    __MODE = "PS3"
    dofile("tests/setup.lua")
    dofile("LOVE-WrapLua/PS3/graphics.lua")
    love.graphics.reset()
    __rec.reset()
end

fresh()

-- ── Image draw emits a textured quad ─────────────────────────────
T.describe("PS3 textured quad draw", function()
    T.it("draw(img) calls gfx.SetTexture + gfx.SetPolygon + gfx.End", function()
        fresh()
        local img = love.graphics.newImage("sprite.png")
        love.graphics.draw(img, 10, 20)
        T.eq(__rec.count("gfx.SetTexture"),     1)
        T.eq(__rec.count("gfx.SetPolygon"),     1)
        T.eq(__rec.count("gfx.End"),            1)
        T.eq(__rec.count("gfx.VertexPosition"), 4)
        T.eq(__rec.count("gfx.VertexTexture"),  4)
        T.eq(__rec.count("gfx.VertexColor"),    4)
    end)

    T.it("draw(img) no longer calls BlitToScreen", function()
        fresh()
        local img = love.graphics.newImage("sprite.png")
        love.graphics.draw(img, 0, 0)
        T.eq(__rec.count("BlitToScreen"), 0)
    end)

    T.it("white setColor passes (1,1,1,1) to VertexColor", function()
        fresh()
        love.graphics.setColor(1, 1, 1, 1)
        local img = love.graphics.newImage("sprite.png")
        love.graphics.draw(img, 0, 0)
        local vc = __rec.last("gfx.VertexColor")
        T.ok(vc, "VertexColor must be logged")
        -- args = { r, g, b, a } (1-indexed)
        T.near(vc.args[1], 1)
        T.near(vc.args[2], 1)
        T.near(vc.args[3], 1)
        T.near(vc.args[4], 1)
    end)

    T.it("red setColor passes (1,0,0,1) to VertexColor", function()
        fresh()
        love.graphics.setColor(1, 0, 0, 1)
        local img = love.graphics.newImage("sprite.png")
        love.graphics.draw(img, 0, 0)
        local vc = __rec.last("gfx.VertexColor")
        T.near(vc.args[1], 1)  -- r
        T.near(vc.args[2], 0)  -- g
        T.near(vc.args[3], 0)  -- b
        T.near(vc.args[4], 1)  -- a
    end)
end)

-- ── Rotation moves vertices ───────────────────────────────────────
T.describe("PS3 image rotation", function()
    T.it("r=0 produces axis-aligned vertex positions", function()
        fresh()
        local img = love.graphics.newImage("sprite.png")
        love.graphics.draw(img, 100, 50, 0)
        local verts = __rec.all("gfx.VertexPosition")
        T.eq(#verts, 4)
        -- Top two corners (1 and 2) share the same Y value
        local y1 = verts[1].args[2]
        local y2 = verts[2].args[2]
        T.near(y1, y2, 1e-6)
    end)

    T.it("r=pi/4 produces non-axis-aligned vertices", function()
        fresh()
        local img = love.graphics.newImage("sprite.png")
        love.graphics.draw(img, 100, 50, math.pi / 4)
        local verts = __rec.all("gfx.VertexPosition")
        T.eq(#verts, 4)
        -- Top-left and top-right X must differ for a rotated quad
        local x1 = verts[1].args[1]
        local x2 = verts[2].args[1]
        T.ok(math.abs(x2 - x1) > 1, "rotated corners must differ in X")
    end)
end)

-- ── Quad sub-rect produces non-trivial UV ─────────────────────────
T.describe("PS3 quad UV mapping", function()
    T.it("whole-image draw uses UV (0,0)-(1,1)", function()
        fresh()
        local img = love.graphics.newImage("sheet.png")
        love.graphics.draw(img, 0, 0)
        local uvs = __rec.all("gfx.VertexTexture")
        T.eq(#uvs, 4)
        -- args = { u, v }; TL = (0,0), BR = (1,1)
        T.near(uvs[1].args[1], 0); T.near(uvs[1].args[2], 0)  -- TL
        T.near(uvs[3].args[1], 1); T.near(uvs[3].args[2], 1)  -- BR
    end)

    T.it("quad draw uses sub-rect UV", function()
        fresh()
        local img  = love.graphics.newImage("sheet.png")
        local quad = love.graphics.newQuad(16, 0, 16, 16, 64, 64)
        love.graphics.draw(img, quad, 0, 0)
        local uvs = __rec.all("gfx.VertexTexture")
        T.eq(#uvs, 4)
        T.near(uvs[1].args[1], 16/64)  -- u0 = 0.25
        T.near(uvs[2].args[1], 32/64)  -- u1 = 0.5
    end)
end)

-- ── Transform stack shifts vertex positions ───────────────────────
T.describe("PS3 quad size and mirroring", function()
    local function xs()
        local v = __rec.all("gfx.VertexPosition")
        return v[1].args[1], v[2].args[1]
    end

    T.it("a quad is drawn at the quad's size, not the sheet's", function()
        fresh()
        local img = love.graphics.newImage("sprite.png")
        local w = img:getWidth()
        local q = love.graphics.newQuad(0, 0, w / 4, w / 4, img)
        __rec.reset()
        love.graphics.draw(img, q, 0, 0)
        local x1, x2 = xs()
        T.near((x2 - x1) / lv1lua.gfx.scale, w / 4, 1e-9)
    end)

    T.it("sx = -1 mirrors the texture and grows left from the anchor", function()
        fresh()
        local img = love.graphics.newImage("sprite.png")
        local w = img:getWidth()
        __rec.reset()
        love.graphics.draw(img, 100, 0, 0, -1, 1)
        local x1, x2 = xs()
        local s = lv1lua.gfx.scale
        T.near(x1, (100 - w) * s, 1e-9)
        T.near(x2, 100 * s, 1e-9)
        local uv = __rec.all("gfx.VertexTexture")
        T.eq(uv[1].args[1], 1)
        T.eq(uv[2].args[1], 0)
    end)

    T.it("a mirrored quad keeps its sub-rect UV, swapped", function()
        fresh()
        local img = love.graphics.newImage("sprite.png")
        local w = img:getWidth()
        local q = love.graphics.newQuad(0, 0, w / 2, w / 2, img)
        __rec.reset()
        love.graphics.draw(img, q, 0, 0, 0, -1, 1)
        local uv = __rec.all("gfx.VertexTexture")
        T.near(uv[1].args[1], 0.5, 1e-9)
        T.near(uv[2].args[1], 0, 1e-9)
    end)
end)

T.describe("PS3 transform stack in draw", function()
    T.it("translate(50,0) shifts all vertex X positions by 50*scale", function()
        fresh()
        local img = love.graphics.newImage("sprite.png")
        love.graphics.draw(img, 0, 0)
        local base = __rec.last("gfx.VertexPosition").args[1]
        fresh()
        love.graphics.translate(50, 0)
        local img2 = love.graphics.newImage("sprite.png")
        love.graphics.draw(img2, 0, 0)
        local shifted = __rec.last("gfx.VertexPosition").args[1]
        T.near(shifted - base, 50 * lv1lua.gfx.scale, 1e-4)
    end)

    T.it("push/pop isolates transform", function()
        fresh()
        local img = love.graphics.newImage("sprite.png")
        love.graphics.draw(img, 0, 0)
        local baseX = __rec.last("gfx.VertexPosition").args[1]
        __rec.reset()
        love.graphics.push()
        love.graphics.translate(999, 0)
        love.graphics.pop()
        love.graphics.draw(img, 0, 0)
        local afterX = __rec.last("gfx.VertexPosition").args[1]
        T.near(afterX, baseX, 1e-4)
    end)

    T.it("transformPoint matches the draw anchor screen position", function()
        fresh()
        local img = love.graphics.newImage("sprite.png")
        love.graphics.translate(40, 0)
        local tx = love.graphics.transformPoint(10, 0)
        love.graphics.draw(img, 10, 0)
        -- TL vertex x = anchorX = tx * gscale (ox=0 so px == anchorX)
        local vp1 = __rec.all("gfx.VertexPosition")[1]
        T.near(vp1.args[1], tx * lv1lua.gfx.scale, 1e-4)
    end)
end)

-- ── Print uses gfx.FontDrawString ────────────────────────────────
T.describe("PS3 text rendering", function()
    T.it("print() calls gfx.FontDrawString, not DrawText", function()
        fresh()
        love.graphics.print("hello", 10, 20)
        T.eq(__rec.count("gfx.FontDrawString"), 1)
        T.eq(__rec.count("DrawText"),           0)
    end)

    T.it("print() calls gfx.FontSetColors with current color", function()
        fresh()
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.print("green", 0, 0)
        local fc = __rec.last("gfx.FontSetColors")
        T.ok(fc, "FontSetColors must be called")
        -- args = { r, g, b, a }
        T.near(fc.args[1], 0)   -- r
        T.near(fc.args[2], 1)   -- g
        T.near(fc.args[3], 0)   -- b
        T.near(fc.args[4], 1)   -- a
    end)
end)

-- ── Primitives call gfx.SetPolygon ───────────────────────────────
T.describe("PS3 filled primitives", function()
    T.it("rectangle fill emits a gfx.SetPolygon call", function()
        fresh()
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.rectangle("fill", 10, 10, 50, 30)
        T.eq(__rec.count("gfx.SetPolygon"),     1)
        T.eq(__rec.count("gfx.End"),            1)
        T.eq(__rec.count("gfx.VertexPosition"), 4)
    end)

    T.it("rectangle line emits four SetPolygon calls (four edges)", function()
        fresh()
        love.graphics.rectangle("line", 0, 0, 40, 20)
        T.eq(__rec.count("gfx.SetPolygon"), 4)
    end)

    T.it("line emits one SetPolygon call", function()
        fresh()
        love.graphics.line(0, 0, 100, 100)
        T.eq(__rec.count("gfx.SetPolygon"), 1)
    end)
end)

io.write("\n=== PS3 first-class graphics (T6.6) ===\n")
return T.summary()
