-- Half-texel quad inset (FIX_PLAN T8.2).
--
-- With the inset on, a quad's source rect shrinks by half a texel per side so
-- linear filtering stops bleeding the neighbouring frame at a boundary. Off by
-- default. Asserted against the source-rect arguments each backend records.

local T = dofile("tests/runner.lua")

local GFX = {
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
}

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
end

-- ── lpp-vita: st_x/st_y/w/h in drawImageExtended ──────────────────
load_backend("lpp-vita")

T.describe("quad inset [lpp-vita]", function()
    T.it("getTextureInset defaults to 0", function()
        T.eq(love.graphics.getTextureInset(), 0)
    end)

    T.it("inset 0 leaves the source rect exact", function()
        love.graphics.setTextureInset(0)
        local img  = love.graphics.newImage("s.png")
        local quad = love.graphics.newQuad(0, 0, 16, 16, 64, 64)
        __rec.reset()
        love.graphics.draw(img, quad, 0, 0)
        local c = __rec.last("Graphics.drawImageExtended")
        T.ok(c ~= nil, "should record an extended draw")
        T.eq(c.args[4], 0)   -- st_x
        T.eq(c.args[5], 0)   -- st_y
        T.eq(c.args[6], 16)  -- w
        T.eq(c.args[7], 16)  -- h
    end)

    T.it("inset 0.5 shrinks the source rect by half a texel per side", function()
        love.graphics.setTextureInset(0.5)
        local img  = love.graphics.newImage("s.png")
        local quad = love.graphics.newQuad(0, 16, 16, 16, 64, 64)
        __rec.reset()
        love.graphics.draw(img, quad, 0, 0)
        local c = __rec.last("Graphics.drawImageExtended")
        T.near(c.args[4], 0.5)   -- st_x inset
        T.near(c.args[5], 16.5)  -- st_y inset
        T.near(c.args[6], 15)    -- w - 1
        T.near(c.args[7], 15)    -- h - 1
    end)

    T.it("adjacent vertical frames no longer share a boundary", function()
        love.graphics.setTextureInset(0.5)
        local img = love.graphics.newImage("s.png")
        local top = love.graphics.newQuad(0, 0,  16, 16, 64, 64)
        local bot = love.graphics.newQuad(0, 16, 16, 16, 64, 64)
        __rec.reset()
        love.graphics.draw(img, top, 0, 0)
        love.graphics.draw(img, bot, 0, 0)
        local calls = __rec.all("Graphics.drawImageExtended")
        T.eq(#calls, 2)
        local topBottom = calls[1].args[5] + calls[1].args[7]  -- st_y + h
        local botTop    = calls[2].args[5]                     -- st_y
        T.ok(botTop > topBottom, "there should be a gap between the two frames")
    end)

    love.graphics.setTextureInset(0)  -- leave state clean for later suites
end)

-- ── PSP: source rect in image.blit (qx,qy,qw,qh) ──────────────────
load_backend("PSP")

T.describe("quad inset [PSP]", function()
    T.it("inset 0.5 shrinks the blit source rect", function()
        love.graphics.setTextureInset(0.5)
        local img  = love.graphics.newImage("s.png")
        local quad = love.graphics.newQuad(0, 0, 16, 16, 64, 64)
        __rec.reset()
        love.graphics.draw(img, quad, 0, 0)
        local c = __rec.last("image.blit")
        T.ok(c ~= nil, "should record a blit")
        T.near(c.args[4], 0.5)   -- qx
        T.near(c.args[5], 0.5)   -- qy
        T.near(c.args[6], 15)    -- qw - 1
        T.near(c.args[7], 15)    -- qh - 1
    end)

    T.it("inset 0 leaves the blit source rect exact", function()
        love.graphics.setTextureInset(0)
        local img  = love.graphics.newImage("s.png")
        local quad = love.graphics.newQuad(0, 0, 16, 16, 64, 64)
        __rec.reset()
        love.graphics.draw(img, quad, 0, 0)
        local c = __rec.last("image.blit")
        T.eq(c.args[4], 0)
        T.eq(c.args[6], 16)
    end)
end)

io.write("\n=== quad inset (T8.2) ===\n")
return T.summary()
