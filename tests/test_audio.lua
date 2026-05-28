local T = dofile("tests/runner.lua")
dofile("tests/mock_platform.lua")
dofile("LOVE-WrapLua/OneLua/audio.lua")

-- ── newSource ────────────────────────────────────────────────────
T.describe("love.audio.newSource", function()
    T.it("returns an object with required methods", function()
        local src = love.audio.newSource("music.ogg", "stream")
        local required = {
            "play","stop","pause","resume",
            "getVolume","setVolume","setLooping",
            "isPlaying","isLooping","isStopped","isPaused",
            "clone","seek","tell","getDuration","getType",
        }
        for _, m in ipairs(required) do
            T.ok(src[m], "should have method: " .. m)
        end
    end)

    T.it("getType returns the sourcetype argument", function()
        local s = love.audio.newSource("sfx.mp3", "static")
        T.eq(s:getType(), "static")
    end)

    T.it("getType defaults to 'static' when omitted", function()
        local s = love.audio.newSource("sfx.mp3")
        T.eq(s:getType(), "static")
    end)

    T.it("tell always returns 0", function()
        local s = love.audio.newSource("sfx.mp3", "static")
        T.eq(s:tell(), 0)
    end)

    T.it("getDuration always returns 0", function()
        local s = love.audio.newSource("sfx.mp3", "static")
        T.eq(s:getDuration(), 0)
    end)
end)

-- ── extension conversion ─────────────────────────────────────────
T.describe("love.audio file extension conversion (via newSource)", function()
    -- We verify that newSource does not crash for each supported extension.
    -- The mock sound.load accepts any path.
    local exts = { "ogg", "wav", "wma", "m4a", "3gp", "mp3" }
    for _, ext in ipairs(exts) do
        T.it("newSource works for ." .. ext, function()
            local s = love.audio.newSource("test." .. ext, "static")
            T.ok(s ~= nil)
        end)
    end
end)

-- ── play / stop ───────────────────────────────────────────────────
T.describe("love.audio.play / stop", function()
    T.it("play sets channel; stop clears it", function()
        local s = love.audio.newSource("sfx.mp3", "static")
        love.audio.play(s)
        love.audio.stop(s)
        -- After stop, source is no longer playing
        T.nok(s:isPlaying())
    end)

    T.it("stop with no argument stops all channels without crash", function()
        local a = love.audio.newSource("a.mp3", "static")
        local b = love.audio.newSource("b.mp3", "stream")
        love.audio.play(a)
        love.audio.play(b)
        love.audio.stop()  -- should not crash
    end)
end)

-- ── volume ───────────────────────────────────────────────────────
T.describe("love.audio.getVolume / setVolume", function()
    T.it("default master volume is 1.0", function()
        T.near(love.audio.getVolume(), 1.0)
    end)

    T.it("setVolume updates master volume", function()
        love.audio.setVolume(0.5)
        T.near(love.audio.getVolume(), 0.5)
        love.audio.setVolume(1.0)  -- restore
    end)
end)

-- ── Source:setVolume / getVolume ──────────────────────────────────
T.describe("Source:setVolume / getVolume", function()
    T.it("getVolume returns value delegated from sound.vol", function()
        local s = love.audio.newSource("v.mp3", "static")
        -- mock sound.vol returns 100 (= 1.0 after /100)
        T.near(s:getVolume(), 1.0)
    end)

    T.it("setVolume stores and reflects the volume", function()
        local s = love.audio.newSource("v.mp3", "static")
        s:setVolume(0.3)
        T.near(s._volume, 0.3)
    end)
end)

-- ── looping ──────────────────────────────────────────────────────
T.describe("Source:setLooping / isLooping", function()
    T.it("isLooping defaults to false", function()
        local s = love.audio.newSource("l.mp3", "static")
        T.nok(s:isLooping())
    end)

    T.it("setLooping(true) sets _looping flag", function()
        local s = love.audio.newSource("l.mp3", "static")
        s:setLooping(true)
        T.ok(s._looping)
    end)
end)

-- ── isStopped ────────────────────────────────────────────────────
T.describe("Source:isStopped", function()
    T.it("returns true when not playing", function()
        local s = love.audio.newSource("s.mp3", "static")
        T.ok(s:isStopped())
    end)
end)

-- ── clone ────────────────────────────────────────────────────────
T.describe("Source:clone", function()
    T.it("returns a new source object", function()
        local orig  = love.audio.newSource("c.mp3", "static")
        local clone = orig:clone()
        T.ok(clone ~= orig, "clone should be a different object")
        T.ok(clone.play, "clone should have play method")
    end)
end)

-- ── getActiveSourceCount ─────────────────────────────────────────
T.describe("love.audio.getActiveSourceCount", function()
    T.it("returns 0 with no active sources", function()
        love.audio.stop()  -- ensure nothing playing
        T.eq(love.audio.getActiveSourceCount(), 0)
    end)
end)

-- ── isEffectsSupported ───────────────────────────────────────────
T.describe("love.audio.isEffectsSupported", function()
    T.it("returns false", function()
        T.nok(love.audio.isEffectsSupported())
    end)
end)

-- ── pause / resume ───────────────────────────────────────────────
T.describe("love.audio.pause / resume", function()
    T.it("pause with a source does not crash", function()
        local s = love.audio.newSource("p.mp3", "static")
        love.audio.pause(s)
    end)

    T.it("resume with a source does not crash", function()
        local s = love.audio.newSource("p.mp3", "static")
        love.audio.resume(s)
    end)

    T.it("pause with no argument pauses all channels", function()
        love.audio.pause()  -- should not crash
    end)
end)

io.write("\n=== love.audio (OneLua) ===\n")
return T.summary()
