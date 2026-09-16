-- desAnim8 smoke suite (FIX_PLAN T9.1).
--
-- Runs the reworked library under every backend mock. The library must draw
-- only through love.graphics.draw(image, quad, ...), so the same code path
-- exercises the quad support on OneLua/Vita, PSP, lpp-vita and PS3. The checks
-- cover the anim8 lessons the rework must honour:
--   * frame advance on integer dt steps (#32)
--   * clone():flipH() renders independently (#44)
--   * play-once fires its callback exactly once (#48)
--   * the source image is never resized (#35 / our #6)

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
}

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
end

local function suite(mode)
    -- Library talks only to love.graphics, so it is loaded fresh against the
    -- backend that is currently active.
    local desAnim8 = dofile("game/libraries/desAnim8.lua")

    T.describe("desAnim8 [" .. mode .. "]", function()
        T.it("Grid slices a sheet into the expected frame count", function()
            local grid = desAnim8.newGrid(16, 16, 64, 16)
            local frames = grid('1-4', 1)
            T.eq(#frames, 4)
            local x, y, w, h = frames[2]:getViewport()
            T.eq(x, 16); T.eq(y, 0); T.eq(w, 16); T.eq(h, 16)
        end)

        T.it("advances one frame per integer dt step and loops", function()
            local grid = desAnim8.newGrid(16, 16, 64, 16)
            local anim = desAnim8.newAnimation(grid('1-4', 1), 1)
            T.eq(anim:getCurrentFrame(), 1)
            anim:update(1); T.eq(anim:getCurrentFrame(), 2)
            anim:update(1); T.eq(anim:getCurrentFrame(), 3)
            anim:update(1); T.eq(anim:getCurrentFrame(), 4)
            anim:update(1); T.eq(anim:getCurrentFrame(), 1)  -- wrapped
        end)

        T.it("clone():flipH() renders independently of the original", function()
            local grid = desAnim8.newGrid(16, 16, 64, 16)
            local anim = desAnim8.newAnimation(grid('1-4', 1), 1)
            local flipped = anim:clone():flipH()

            local _, _, _, _, osx = anim:getFrameInfo(0, 0)
            local _, _, _, _, fsx = flipped:getFrameInfo(0, 0)
            T.ok((osx or 1) > 0, "original is not flipped")
            T.ok(fsx < 0, "clone is horizontally flipped")
            -- Flipping the clone must not have touched the original.
            local _, _, _, _, osx2 = anim:getFrameInfo(0, 0)
            T.ok((osx2 or 1) > 0, "original stays unflipped after cloning")
        end)

        T.it("play-once fires its callback exactly once and stops at the end", function()
            local grid  = desAnim8.newGrid(16, 16, 64, 16)
            local calls = 0
            local anim  = desAnim8.newAnimation(grid('1-4', 1), 1,
                            { once = true, onComplete = function() calls = calls + 1 end })
            anim:update(3)   -- reaches the last frame, not yet past the end
            T.eq(calls, 0)
            anim:update(2)   -- crosses the end
            T.eq(calls, 1)
            T.eq(anim:getCurrentFrame(), 4)
            T.eq(anim.status, "paused")
            anim:update(10)  -- further updates must not fire again
            T.eq(calls, 1)
        end)

        T.it("gotoFrame / pause / resume behave", function()
            local grid = desAnim8.newGrid(16, 16, 64, 16)
            local anim = desAnim8.newAnimation(grid('1-4', 1), 1)
            anim:gotoFrame(3)
            T.eq(anim:getCurrentFrame(), 3)
            anim:pause()
            anim:update(5)
            T.eq(anim:getCurrentFrame(), 3)  -- frozen while paused
            anim:resume()
            anim:update(1)
            T.eq(anim:getCurrentFrame(), 4)
        end)

        T.it("drawing does not crash and never resizes the source", function()
            local img  = love.graphics.newImage("sheet.png")
            local grid = desAnim8.newGrid(16, 16, 64, 16)
            local anim = desAnim8.newAnimation(grid('1-4', 1), 1)
            __rec.reset()
            anim:draw(img, 10, 20)
            anim:clone():flipH():draw(img, 30, 40)
            T.eq(__rec.count("image.resize"), 0)
        end)

        T.it("the legacy desAnim8.new shim still animates and draws", function()
            local img  = love.graphics.newImage("sheet.png")
            local a    = desAnim8.new(img, 16, 16, 4, 1, 64, 16)
            T.eq(a:getCurrentFrame(), 1)
            a:update(1)
            T.eq(a:getCurrentFrame(), 2)
            __rec.reset()
            a:draw(10, 20)  -- no image argument: the shim supplies it
            T.eq(__rec.count("image.resize"), 0)
        end)
    end)
end

load_backend("OneLua");   suite("OneLua")
load_backend("PSP");      suite("PSP")
load_backend("lpp-vita"); suite("lpp-vita")
load_backend("PS3");      suite("PS3")

io.write("\n=== desAnim8 (multi-backend) ===\n")
return T.summary()
