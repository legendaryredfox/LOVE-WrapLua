-- Shared graphics objects (FIX_PLAN T5.1): Canvas, Shader, SpriteBatch, Text.
--
-- core/objects.lua replaced four near-identical per-backend copies, so the same
-- suite has to hold on every backend now. The quad case is the reason the
-- shared module exists: the PSP, lpp-vita and PS3 copies dropped the quad in
-- SpriteBatch:_draw and blitted the whole sheet per sprite.

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
}

local MODES = { "OneLua", "PSP", "lpp-vita", "PS3" }

-- The native call each backend makes per unrotated, unquadded sprite.
local BLIT = {
    ["OneLua"]   = "image.blit",
    ["PSP"]      = "image.blit",
    ["lpp-vita"] = "Graphics.drawScaleImage",
    ["PS3"]      = "BlitToScreen",
}

-- The native call each backend makes per printed string.
local PRINT = {
    ["OneLua"]   = "screen.print",
    ["PSP"]      = "screen.print",
    ["lpp-vita"] = "Font.print",
    ["PS3"]      = "DrawText",
}

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
end

-- Records what SpriteBatch/Text hand to the backend's draw entry point.
local function capture_draws(fn)
    local real, calls = love.graphics.draw, {}
    love.graphics.draw = function(...) table.insert(calls, {...}) end
    local ok, err = pcall(fn)
    love.graphics.draw = real
    if not ok then error(err, 0) end
    return calls
end

for _, mode in ipairs(MODES) do
    load_backend(mode)

    T.describe("objects ["..mode.."]", function()
        -- ── Canvas ───────────────────────────────────────────────
        T.it("newCanvas defaults to the screen size", function()
            local c = love.graphics.newCanvas()
            T.eq(c:getWidth(),  lv1lua.screenWidth)
            T.eq(c:getHeight(), lv1lua.screenHeight)
        end)

        T.it("setCanvas / getCanvas round-trip", function()
            local c = love.graphics.newCanvas(64, 64)
            love.graphics.setCanvas(c)
            T.ok(love.graphics.getCanvas() == c)
            love.graphics.setCanvas(nil)
            T.ok(love.graphics.getCanvas() == nil)
        end)

        T.it("renderTo runs the function (drawing to the screen)", function()
            local c, ran = love.graphics.newCanvas(8, 8), false
            c:renderTo(function() ran = true end)
            T.ok(ran, "renderTo should still call the function")
        end)

        -- ── Shader ───────────────────────────────────────────────
        T.it("newShader returns an inert object", function()
            local s = love.graphics.newShader("code")
            s:send("x", 1)
            T.nok(s:hasUniform("x"))
        end)

        -- ── SpriteBatch ──────────────────────────────────────────
        T.it("add / getCount / clear track the queue", function()
            local sb = love.graphics.newSpriteBatch(love.graphics.newImage("s.png"), 100)
            T.eq(sb:getCount(), 0)
            T.eq(sb:add(0, 0), 1)
            sb:add(10, 10)
            T.eq(sb:getCount(), 2)
            sb:clear()
            T.eq(sb:getCount(), 0)
        end)

        T.it("getImage returns the source image", function()
            local img = love.graphics.newImage("s.png")
            T.ok(love.graphics.newSpriteBatch(img, 10):getImage() == img)
        end)

        T.it("set replaces a queued sprite in place", function()
            local sb = love.graphics.newSpriteBatch(love.graphics.newImage("s.png"), 10)
            local id = sb:add(0, 0)
            sb:set(id, 40, 50)
            local calls = capture_draws(function() sb:_draw(0, 0) end)
            T.eq(#calls, 1)
            T.eq(calls[1][2], 40)
            T.eq(calls[1][3], 50)
        end)

        -- The regression the per-backend copies had: a quad added to a batch
        -- has to reach draw as a quad, on every backend.
        T.it("a quad added to the batch is drawn as a quad", function()
            local img  = love.graphics.newImage("s.png")
            local quad = love.graphics.newQuad(16, 32, 16, 16, 64, 64)
            local sb   = love.graphics.newSpriteBatch(img, 10)
            sb:add(quad, 5, 7)
            local calls = capture_draws(function() sb:_draw(100, 200) end)
            T.eq(#calls, 1)
            T.ok(calls[1][2] == quad, "the quad should be passed through to draw")
            T.eq(calls[1][3], 105)  -- sprite x plus batch x
            T.eq(calls[1][4], 207)
        end)

        -- love.graphics.draw(batch) has to reach the object's replay on every
        -- backend: PSP and PS3 used to fall through to the native blit with a
        -- plain Lua table (PS3 errored on setRectPos).
        T.it("drawing the batch blits one sprite per entry", function()
            local sb = love.graphics.newSpriteBatch(love.graphics.newImage("s.png"), 10)
            sb:add(0, 0)
            sb:add(10, 10)
            __rec.reset()
            love.graphics.draw(sb, 0, 0)
            T.eq(__rec.count(BLIT[mode]), 2)
        end)

        T.it("drawing a Text object prints each batch", function()
            local txt = love.graphics.newText(love.graphics.newFont(nil, 14))
            txt:add("one", 0, 0)
            txt:add("two", 0, 20)
            __rec.reset()
            love.graphics.draw(txt, 0, 0)
            T.ok(__rec.count(PRINT[mode]) >= 2, "each queued string should print")
        end)

        -- ── Text ─────────────────────────────────────────────────
        T.it("newText measures with the given font", function()
            local fnt = love.graphics.newFont(nil, 14)
            local txt = love.graphics.newText(fnt, "hello")
            T.ok(txt:getFont() == fnt)
            T.ok(txt:getWidth()  > 0, "width should be positive")
            T.ok(txt:getHeight() > 0, "height should be positive")
        end)

        T.it("clear resets the dimensions", function()
            local txt = love.graphics.newText(love.graphics.newFont(nil, 14), "hello")
            txt:clear()
            T.eq(txt:getWidth(), 0)
            T.eq(txt:getHeight(), 0)
        end)

        T.it("set replaces, add appends", function()
            local txt = love.graphics.newText(love.graphics.newFont(nil, 14))
            txt:set("one")
            T.eq(txt:add("two", 10, 20), 2)
            txt:set("three")
            T.eq(txt:add("four", 0, 0), 2)
        end)

        T.it("newTextBatch is an alias for newText", function()
            T.ok(love.graphics.newTextBatch == love.graphics.newText)
        end)

        T.it("_draw restores the previously active font", function()
            local before = love.graphics.getFont()
            local txt = love.graphics.newText(love.graphics.newFont(nil, 20), "hi")
            txt:_draw(0, 0)
            T.ok(love.graphics.getFont() == before, "font should be restored after drawing")
        end)
    end)
end

-- Native-level check: on lpp-vita a batched quad must reach the native
-- sub-rect draw, not a whole-sheet blit.
load_backend("lpp-vita")
T.describe("objects [lpp-vita native quad]", function()
    T.it("a batched quad blits the quad's source rect", function()
        local img  = love.graphics.newImage("s.png")
        local quad = love.graphics.newQuad(16, 32, 16, 16, 64, 64)
        local sb   = love.graphics.newSpriteBatch(img, 10)
        sb:add(quad, 0, 0)
        __rec.reset()
        love.graphics.draw(sb, 0, 0)
        local c = __rec.last("Graphics.drawImageExtended")
        T.ok(c ~= nil, "should use the extended (sub-rect) draw")
        T.eq(c.args[4], 16)  -- st_x
        T.eq(c.args[5], 32)  -- st_y
        T.eq(c.args[6], 16)  -- width
        T.eq(c.args[7], 16)  -- height
    end)
end)

io.write("\n=== graphics objects ===\n")
return T.summary()
