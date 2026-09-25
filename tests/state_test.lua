-- Shared graphics state (FIX_PLAN T5.1): colour, clear, line style, blend mode,
-- default filter, stencil stubs.
--
-- core/state.lua replaced four per-backend copies that had drifted: only OneLua
-- tracked the blend mode, only OneLua honoured setDefaultFilter, and OneLua
-- returned native filter constants instead of LOVE's names. The same suite has
-- to hold everywhere now.

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
}

local MODES = { "OneLua", "PSP", "lpp-vita", "PS3" }

-- Backends whose clear reaches the framebuffer; on the others the frame loop
-- owns the clear/flip pair, so love.graphics.clear is a documented no-op.
local CLEARS = { ["OneLua"] = true, ["PSP"] = true }

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
end

for _, mode in ipairs(MODES) do
    load_backend(mode)

    T.describe("state ["..mode.."]", function()
        T.it("setColor / getColor round-trip in 0-1 floats", function()
            love.graphics.setColor(0.25, 0.5, 0.75, 0.5)
            local r, g, b, a = love.graphics.getColor()
            T.near(r, 0.25, 1e-9); T.near(g, 0.5, 1e-9)
            T.near(b, 0.75, 1e-9); T.near(a, 0.5, 1e-9)
        end)

        T.it("setColor accepts a table and defaults alpha to 1", function()
            love.graphics.setColor({0, 1, 0})
            local r, g, b, a = love.graphics.getColor()
            T.eq(r, 0); T.eq(g, 1); T.eq(b, 0); T.eq(a, 1)
        end)

        T.it("setBackgroundColor / getBackgroundColor round-trip", function()
            love.graphics.setBackgroundColor(0.1, 0.2, 0.3)
            local r, g, b, a = love.graphics.getBackgroundColor()
            T.near(r, 0.1, 1e-9); T.near(g, 0.2, 1e-9)
            T.near(b, 0.3, 1e-9); T.eq(a, 1)
        end)

        T.it("clear either wipes the screen or is a documented no-op", function()
            __rec.reset()
            love.graphics.clear(0, 0, 0, 1)
            local wiped = __rec.count("screen.clear")
            if CLEARS[mode] then
                T.eq(wiped, 1)
            else
                T.eq(wiped, 0)  -- the frame loop already cleared this frame
            end
        end)

        T.it("setLineWidth / getLineWidth round-trip", function()
            love.graphics.setLineWidth(4)
            T.eq(love.graphics.getLineWidth(), 4)
            love.graphics.setLineWidth()
            T.eq(love.graphics.getLineWidth(), 1)
        end)

        T.it("line style, join and point size answer LOVE defaults", function()
            love.graphics.setLineStyle("rough")
            T.eq(love.graphics.getLineStyle(), "smooth")
            love.graphics.setLineJoin("bevel")
            T.eq(love.graphics.getLineJoin(), "miter")
            love.graphics.setPointSize(8)
            T.eq(love.graphics.getPointSize(), 1)
        end)

        -- Blending is never applied (the platform default is all there is), but
        -- getBlendMode answers with what the game set, as LOVE does.
        T.it("blend mode is tracked and reported back", function()
            T.eq(love.graphics.getBlendMode(), "alpha")
            love.graphics.setBlendMode("add")
            local mode_, alphamode = love.graphics.getBlendMode()
            T.eq(mode_, "add")
            T.eq(alphamode, "alphamultiply")
            love.graphics.setBlendMode("alpha")
        end)

        T.it("getDefaultFilter returns LOVE names, not native constants", function()
            love.graphics.setDefaultFilter("nearest")
            local min, mag, aniso = love.graphics.getDefaultFilter()
            T.eq(min, "nearest")
            T.eq(mag, "nearest")   -- mag defaults to min, as in LOVE
            T.eq(aniso, 1)
            love.graphics.setDefaultFilter("linear", "nearest", 2)
            min, mag, aniso = love.graphics.getDefaultFilter()
            T.eq(min, "linear"); T.eq(mag, "nearest"); T.eq(aniso, 2)
            love.graphics.setDefaultFilter("linear")
        end)

        T.it("stencil calls the function and the test stubs answer", function()
            local called = false
            love.graphics.stencil(function() called = true end)
            T.ok(called, "stencil should run the function")
            love.graphics.setStencilTest("equal", 1)
            local compare, value = love.graphics.getStencilTest()
            T.eq(compare, "always"); T.eq(value, 0)
        end)
    end)
end

-- OneLua is the one backend that can set a texture filter, so the LOVE name has
-- to reach the native constant the draw path passes to image.setfilter.
load_backend("OneLua")
T.describe("state [OneLua native filter]", function()
    T.it("maps the LOVE filter name to the native constant", function()
        love.graphics.setDefaultFilter("nearest")
        T.eq(lv1lua.gfx.filter.min, __IMG_FILTER_POINT)
        T.eq(lv1lua.gfx.filter.mag, __IMG_FILTER_POINT)
        love.graphics.setDefaultFilter("linear")
        T.eq(lv1lua.gfx.filter.min, __IMG_FILTER_LINEAR)
    end)

    T.it("setColor reaches the native colour handle", function()
        love.graphics.setColor(1, 0, 0, 1)
        T.ok(lv1lua.current.color ~= nil, "a native colour should be built")
    end)
end)

io.write("\n=== graphics state ===\n")
return T.summary()
