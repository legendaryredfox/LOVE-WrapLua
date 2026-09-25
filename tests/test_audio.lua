-- love.audio across the backends (FIX_PLAN T6.2).
--
-- One shared Source implementation (core/audio.lua) sits over each backend's
-- native hooks, so the same suite runs everywhere. What used to be stubbed in
-- three separate copies is asserted here: pause/resume state, a real timed
-- position from tell(), pitch, seek and getDuration for WAV.

local T = dofile("tests/runner.lua")

local AUDIO = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/audio.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/audio.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/audio.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/audio.lua",
}

-- A fake clock, so a timed playback position is testable without sleeping.
local clock = 0
local function setClock(t) clock = t end

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    love.timer = love.timer or {}
    love.timer.getTime = function() return clock end
    clock = 0
    dofile(AUDIO[mode])
    __rec.reset()
end

-- PS3 only has a background voice, so its playable sources are streams.
local function playable(mode)
    return mode == "PS3" and "stream" or "static"
end

local function shared_suite(mode)
    local kind = playable(mode)

    T.describe("love.audio [" .. mode .. "]", function()
        T.it("newSource returns a Source with the LOVE method set", function()
            local s = love.audio.newSource("music.mp3", "stream")
            for _, m in ipairs({"play","stop","pause","resume","getVolume","setVolume",
                                "setLooping","isLooping","isPlaying","isStopped",
                                "isPaused","clone","seek","tell","getDuration",
                                "getType","setPitch","getPitch","type","typeOf"}) do
                T.istype(s[m], "function")
            end
            T.eq(s:type(), "Source")
            T.ok(s:typeOf("Source"))
        end)

        T.it("getType reports the source type, defaulting to static", function()
            T.eq(love.audio.newSource("a.mp3", "stream"):getType(), "stream")
            T.eq(love.audio.newSource("a.mp3"):getType(), "static")
        end)

        T.it("play marks the source playing, stop clears it", function()
            local s = love.audio.newSource("p.mp3", kind)
            s:play()
            T.ok(s:isPlaying(), "should be playing after play()")
            s:stop()
            T.nok(s:isPlaying())
            T.ok(s:isStopped())
        end)

        T.it("pause and resume are distinguishable states", function()
            local s = love.audio.newSource("p.mp3", kind)
            s:play()
            s:pause()
            T.ok(s:isPaused(), "pause() must be visible to isPaused()")
            T.nok(s:isStopped(), "a paused source is not stopped")
            s:resume()
            T.nok(s:isPaused())
            T.ok(s:isPlaying())
            s:stop()
            T.nok(s:isPaused(), "stop clears the paused state")
        end)

        T.it("tell follows the clock while playing", function()
            local s = love.audio.newSource("p.mp3", kind)
            setClock(10)
            s:play()
            T.near(s:tell(), 0)
            setClock(12.5)
            T.near(s:tell(), 2.5)
        end)

        T.it("tell freezes while paused and continues on resume", function()
            local s = love.audio.newSource("p.mp3", kind)
            setClock(0)
            s:play()
            setClock(3)
            s:pause()
            setClock(9)
            T.near(s:tell(), 3, 1e-9)
            s:resume()
            setClock(10)
            T.near(s:tell(), 4, 1e-9)
        end)

        T.it("play from the start resets the position", function()
            local s = love.audio.newSource("p.mp3", kind)
            setClock(0)
            s:play()
            setClock(5)
            s:play()
            T.near(s:tell(), 0)
        end)

        T.it("seek moves the reported position", function()
            local s = love.audio.newSource("p.mp3", kind)
            setClock(0)
            s:play()
            s:seek(7)
            T.near(s:tell(), 7)
            setClock(2)
            T.near(s:tell(), 9)
        end)

        T.it("pitch scales the timed position", function()
            local s = love.audio.newSource("p.mp3", kind)
            setClock(0)
            s:play()
            s:setPitch(2)
            T.eq(s:getPitch(), 2)
            setClock(3)
            T.near(s:tell(), 6)
        end)

        T.it("pitch rejects zero and negatives", function()
            local s = love.audio.newSource("p.mp3", kind)
            s:setPitch(0)
            T.eq(s:getPitch(), 1)
            s:setPitch(-2)
            T.eq(s:getPitch(), 1)
        end)

        T.it("looping is tracked", function()
            local s = love.audio.newSource("l.mp3", kind)
            T.nok(s:isLooping())
            s:setLooping(true)
            T.ok(s:isLooping())
        end)

        T.it("source volume round-trips", function()
            local s = love.audio.newSource("v.mp3", kind)
            s:setVolume(0.25)
            T.near(s:getVolume(), 0.25, 1e-3)
        end)

        T.it("master volume round-trips and defaults to 1", function()
            T.near(love.audio.getVolume(), 1.0)
            love.audio.setVolume(0.5)
            T.near(love.audio.getVolume(), 0.5)
            love.audio.setVolume(1.0)
        end)

        T.it("getActiveSourceCount counts what is playing", function()
            love.audio.stop()
            T.eq(love.audio.getActiveSourceCount(), 0)
            local s = love.audio.newSource("c.mp3", kind)
            s:play()
            T.ok(love.audio.getActiveSourceCount() >= 1)
            love.audio.stop()
            T.eq(love.audio.getActiveSourceCount(), 0)
        end)

        T.it("pause() with no argument returns the sources it paused", function()
            love.audio.stop()
            local s = love.audio.newSource("m.mp3", kind)
            s:play()
            local paused = love.audio.pause()
            T.istype(paused, "table")
            T.ok(#paused >= 1, "should report the paused source")
            T.ok(s:isPaused())
            love.audio.stop()
        end)

        T.it("clone copies the settings, not the object", function()
            local s = love.audio.newSource("c.mp3", kind)
            s:setVolume(0.4)
            s:setPitch(1.5)
            s:setLooping(true)
            local c = s:clone()
            T.ok(c ~= s)
            T.eq(c:getPitch(), 1.5)
            T.ok(c:isLooping())
        end)

        T.it("getDuration reads a WAV header when the SDK cannot tell", function()
            local s = love.audio.newSource("p.mp3", kind)
            -- Point at the fixture: 4000 bytes at 8000 bytes/second = 0.5s.
            s._path, s._duration = "tests/fixtures/tone.wav", nil
            T.near(s:getDuration(), 0.5, 1e-6)
        end)

        T.it("getDuration is 0 for a format nothing can measure", function()
            local s = love.audio.newSource("p.mp3", kind)
            s._path, s._duration = "tests/fixtures/does-not-exist.mp3", nil
            T.eq(s:getDuration(), 0)
        end)

        T.it("isEffectsSupported is honest", function()
            T.nok(love.audio.isEffectsSupported())
        end)
    end)
end

for _, mode in ipairs({"OneLua", "PSP", "lpp-vita", "PS3"}) do
    load_backend(mode)
    shared_suite(mode)
end

-- ── Backend specifics ────────────────────────────────────────────
load_backend("OneLua")
T.describe("OneLua channels", function()
    T.it("a static source plays on channel 1, a stream on channel 2", function()
        local sfx = love.audio.newSource("sfx.mp3", "static")
        local bgm = love.audio.newSource("bgm.mp3", "stream")
        __rec.reset()
        sfx:play()
        T.eq(__rec.last("sound.play").args[2], 1)
        bgm:play()
        T.eq(__rec.last("sound.play").args[2], 2)
    end)

    T.it("a LOVE audio extension is converted to the mp3 the SDK decodes", function()
        local s = love.audio.newSource("music.ogg", "stream")
        T.ok(s._path:sub(-4) == ".mp3", "expected an .mp3 path, got " .. tostring(s._path))
    end)
end)

load_backend("PS3")
T.describe("PS3 single background voice", function()
    T.it("a stream source binds the voice", function()
        __rec.reset()
        love.audio.newSource("bgm.mp3", "stream")
        T.eq(__rec.count("snd.SetVoice"), 1)
    end)

    T.it("a static source loads nothing but still answers", function()
        local s = love.audio.newSource("sfx.wav", "static")
        T.eq(s._handle, nil)
        T.nok(s:play(), "no voice to play on")
        T.nok(s:isPlaying())
    end)

    T.it("the frame hook re-issues PlayVoice while a stream plays", function()
        local bgm = love.audio.newSource("bgm.mp3", "stream")
        bgm:play()
        __rec.reset()
        lv1lua.playsound()
        T.ok(__rec.count("snd.PlayVoice") >= 1, "the voice must be re-issued each frame")
        bgm:stop()
        __rec.reset()
        lv1lua.playsound()
        T.eq(__rec.count("snd.PlayVoice"), 0)
    end)
end)

io.write("\n=== love.audio (multi-backend) ===\n")
return T.summary()
