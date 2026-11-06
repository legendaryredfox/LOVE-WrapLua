-- Behaviour guards for the allocation-free hot paths: setColor (in place, memoised native
-- handles) and the pooled transform levels.

local T = dofile("tests/runner.lua")

for _, mode in ipairs({ "PSP", "OneLua", "lpp-vita", "PS3" }) do
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(({
        ["PSP"] = "LOVE-WrapLua/OneLua/graphics_psp.lua", ["OneLua"] = "LOVE-WrapLua/OneLua/graphics.lua",
        ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua", ["PS3"] = "LOVE-WrapLua/PS3/graphics.lua",
    })[mode])

    T.describe("hot paths [" .. mode .. "]", function()
        T.it("setColor round-trips through getColor, table or numbers", function()
            love.graphics.setColor(0.25, 0.5, 0.75, 0.5)
            local r, g, b, a = love.graphics.getColor()
            T.eq(r, 0.25); T.eq(g, 0.5); T.eq(b, 0.75); T.eq(a, 0.5)
            love.graphics.setColor({ 1, 0, 0 })
            r, g, b, a = love.graphics.getColor()
            T.eq(r, 1); T.eq(g, 0); T.eq(b, 0); T.eq(a, 1)
        end)

        T.it("setColor does not hand out its internal tuple", function()
            love.graphics.setColor(0.1, 0.2, 0.3, 1)
            local r1 = love.graphics.getColor()
            love.graphics.setColor(0.9, 0.2, 0.3, 1)
            T.eq(r1, 0.1)                                     -- values returned earlier are plain numbers
        end)

        T.it("repeating a colour keeps the same native handle, a new one changes it", function()
            love.graphics.setColor(0.2, 0.4, 0.6, 1)
            local c1 = lv1lua.current.color
            love.graphics.setColor(0.2, 0.4, 0.6, 1)
            T.ok(lv1lua.current.color == c1)
            love.graphics.setColor(0.6, 0.4, 0.2, 1)
            if lv1lua.gfx.nativeColor then T.ok(lv1lua.current.color ~= c1) end
        end)

        T.it("a pushed level starts clean even when reused from the pool", function()
            love.graphics.origin()
            love.graphics.push()
            love.graphics.translate(10, 20); love.graphics.scale(3, 3)
            love.graphics.pop()
            love.graphics.push()
            local x, y = love.graphics.transformPoint(1, 1)
            T.eq(x, 1); T.eq(y, 1)                            -- no leftover offset or scale
            love.graphics.pop()
        end)

        T.it("push/pop pairs leave the stack depth unchanged", function()
            local d = #lv1lua.gfx.transform.stack
            for _ = 1, 50 do love.graphics.push(); love.graphics.translate(1, 1); love.graphics.pop() end
            T.eq(#lv1lua.gfx.transform.stack, d)
        end)
    end)
end

io.write("\n=== hot paths ===\n")
return T.summary()
