-- love.graphics transform surface (core/transformapi.lua) on every backend.
--
-- Nested push levels used to compose in the wrong order: the flatten step
-- multiplied the accumulated offset by each inner level's scale, so
-- `scale(2) push() translate(-10)` (the usual pixel-art camera) mapped x to
-- 2x - 10 instead of 2(x - 10). applyTransform also kept only a Transform's
-- translation and diagonal, dropping any rotation.

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
    ["3DS"]      = "LOVE-WrapLua/3DS/graphics.lua",
}

for _, mode in ipairs({ "PSP", "PS3", "OneLua", "lpp-vita", "3DS" }) do
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    dofile("LOVE-WrapLua/math.lua")
    local lg = love.graphics

    T.describe("transform surface [" .. mode .. "]", function()
        T.it("an outer scale applies to a nested translate", function()
            lg.origin()
            lg.scale(2)
            lg.push()
            lg.translate(-10, 0)
            T.eq((lg.transformPoint(15, 0)), 10)
            lg.pop()
            lg.origin()
        end)

        T.it("a nested scale leaves the outer translate alone", function()
            lg.origin()
            lg.translate(100, 0)
            lg.push()
            lg.scale(2)
            T.eq((lg.transformPoint(10, 0)), 120)
            lg.pop()
            lg.origin()
        end)

        T.it("inverseTransformPoint undoes a nested transform", function()
            lg.origin()
            lg.scale(2)
            lg.push()
            lg.translate(-10, 5)
            local x, y = lg.inverseTransformPoint(lg.transformPoint(7, 3))
            T.near(x, 7, 1e-9)
            T.near(y, 3, 1e-9)
            lg.pop()
            lg.origin()
        end)

        T.it("applyTransform keeps translation and scale", function()
            lg.origin()
            lg.applyTransform(love.math.newTransform(5, 6, 0, 2, 3))
            local x, y = lg.transformPoint(1, 1)
            T.near(x, 7, 1e-9)
            T.near(y, 9, 1e-9)
            lg.origin()
        end)

        T.it("applyTransform keeps rotation", function()
            lg.origin()
            lg.applyTransform(love.math.newTransform(0, 0, math.pi / 2))
            lv1lua.gfx.transform:updateTransform()
            T.near(lv1lua.gfx.transform.transform._rotation, math.pi / 2, 1e-9)
            lg.origin()
        end)
    end)
end

io.write("\n=== transform surface ===\n")
return T.summary()
