-- love.audio across the backends.
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
    ["3DS"]      = "LOVE-WrapLua/3DS/audio.lua",
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
    if mode == "3DS" then dofile("LOVE-WrapLua/3DS/fileio.lua") end
    dofile(AUDIO[mode])
    if mode == "3DS" then
        -- lpp-3ds decodes no MP3, so the shared suite's names are played as OGG.
        local newSource = love.audio.newSource
        love.audio.newSource = function(name, ...)
            if type(name) == "string" then name = name:gsub("%.mp3$", ".ogg") end
            return newSource(name, ...)
        end
    end
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

        -- LOVE 11: play on a playing source does nothing, play on a paused
        -- one resumes it, and only stop rewinds.
        T.it("play on a playing source neither restarts nor re-plays it", function()
            local s = love.audio.newSource("p.mp3", kind)
            setClock(0)
            s:play()
            setClock(5)
            __rec.reset()
            T.ok(s:play())
            T.near(s:tell(), 5)
            s:stop()
        end)

        T.it("play on a paused source resumes where it was", function()
            local s = love.audio.newSource("p.mp3", kind)
            setClock(0)
            s:play()
            setClock(2)
            s:pause()
            setClock(7)
            s:play()
            setClock(8)
            T.near(s:tell(), 3, 1e-9)
            s:stop()
        end)

        T.it("stop then play starts from the beginning", function()
            local s = love.audio.newSource("p.mp3", kind)
            setClock(0)
            s:play()
            setClock(5)
            s:stop()
            s:play()
            T.near(s:tell(), 0)
            s:stop()
        end)

        T.it("a fractional volume reaches the SDK without raising", function()
            local s = love.audio.newSource("p.mp3", kind)
            s:setVolume(0.5)
            T.near(s:getVolume(), 0.5, 0.01)
        end)

        T.it("release forgets the source", function()
            love.audio.stop()
            local s = love.audio.newSource("p.mp3", kind)
            s:play()
            T.ok(s:release())
            T.eq(love.audio.getActiveSourceCount(), 0)
            T.nok(s:release(), "a second release has nothing to free")
        end)

        T.it("love.audio.play / stop take several sources or a list", function()
            local a = love.audio.newSource("a.mp3", kind)
            local b = love.audio.newSource("b.mp3", kind)
            love.audio.play(a, b)
            T.ok(a._playing and b._playing, "both should be playing")
            love.audio.stop({ a, b })
            T.nok(a._playing or b._playing)
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

for _, mode in ipairs({"OneLua", "PSP", "lpp-vita", "PS3", "3DS"}) do
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

load_backend("lpp-vita")
T.describe("lpp-vita native contract", function()
    T.it("a volume set before play survives play", function()
        -- Sound.play resets the track volume to 32767 (luaSound.cpp).
        local s = love.audio.newSource("p.mp3", "static")
        s:setVolume(0.25)
        s:play()
        T.near(Sound.getVolume(s._handle) / 32767, 0.25, 0.001)
        s:stop()
    end)

    T.it("resume uses Sound.resume, not a second play", function()
        local s = love.audio.newSource("p.mp3", "static")
        s:play(); s:pause()
        __rec.reset()
        s:resume()
        T.eq(__rec.count("Sound.resume"), 1)
        T.eq(__rec.count("Sound.play"), 0)
        s:stop()
    end)

    T.it("stop closes the track so the next play starts fresh", function()
        -- Playing a track already in an audio thread starts a duplicate and
        -- leaves the paused original holding the thread.
        local s = love.audio.newSource("p.mp3", "static")
        s:play()
        s:stop()
        __rec.reset()
        s:play()
        T.eq(__rec.count("Sound.play.duplicate"), 0)
        s:stop()
    end)
end)

load_backend("PS3")
T.describe("PS3 single background voice", function()
    -- The voice is one channel: binding it at newSource meant the last
    -- source created owned it, so playing an earlier one played the wrong
    -- file. It is bound at play now.
    T.it("a stream binds the voice when it plays, not when it is created", function()
        __rec.reset()
        local a = love.audio.newSource("a.mp3", "stream")
        love.audio.newSource("b.mp3", "stream")
        T.eq(__rec.count("snd.SetVoice"), 0)
        a:play()
        T.ok(__rec.last("snd.SetVoice").args[2]:find("a.mp3", 1, true))
        a:stop()
    end)

    T.it("playing again after stop binds the freed voice again", function()
        local a = love.audio.newSource("a.mp3", "stream")
        a:play(); a:stop()
        __rec.reset()
        a:play()
        T.eq(__rec.count("snd.SetVoice"), 1)
        T.ok(a:isPlaying())
        a:stop()
    end)

    T.it("only the stream holding the voice reports playing", function()
        local a = love.audio.newSource("a.mp3", "stream")
        local b = love.audio.newSource("b.mp3", "stream")
        a:play(); b:play()
        T.nok(a:isPlaying())
        T.ok(b:isPlaying())
        b:stop()
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

T.describe("PS3 love.timer.getTime", function()
    T.it("advances by the frame time, not in whole seconds", function()
        __MODE = "PS3"
        dofile("tests/setup.lua")
        dofile("LOVE-WrapLua/core/timestep.lua")
        dofile("LOVE-WrapLua/PS3/timer.lua")
        local t0 = love.timer.getTime()
        lv1lua.core.step()
        T.near(love.timer.getTime() - t0, 1 / 60, 1e-9)
    end)
end)

io.write("\n=== love.audio (multi-backend) ===\n")
return T.summary()
