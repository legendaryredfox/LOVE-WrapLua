-- Audio on the console build, MP3 only (docs/adr/002-psp-native-audio-format.md): tone.mp3 (1.0 s, from
-- ffmpeg -f lavfi -i "sine=frequency=440:duration=1" -ac 2 -c:a libmp3lame -b:a 128k tone.mp3, kept out of the repository)
-- played under its own name and under the name tone.ogg (a .ogg name plays its .mp3 sibling), static and streamed, plus
-- jingle.mp3 (a copy), pitch, looping, seek, clone and five streams at once. Logs AUDIO lines; the verdicts use the
-- mixer's own clock, so they also hold in the emulator.
local function check(name, cond) PSP_LOG("AUDIO " .. (cond and "ok   " or "FAIL ") .. name) end

local steps, i, src, t0 = {}, 0, nil, 0
local function wait(sec) local t = love.timer.getTime(); return function() return love.timer.getTime() - t >= sec end end

function love.load()
    local o = love.audio.newSource("tone.ogg", "static")
    check("mp3 under a .ogg name, static, loads", not o._stub)
    check("duration about 1.0 (encoder padding allowed)", math.abs(o:getDuration() - 1.0) < 0.1)
    local st = love.audio.newSource("tone.ogg", "stream")
    check("mp3 under a .ogg name, streamed, loads", not st._stub)
    check("stream duration about 1.0", math.abs(st:getDuration() - 1.0) < 0.1)
    local m = love.audio.newSource("jingle.mp3", "static")
    check("mp3 static loads", not m._stub)
    check("mp3 duration about 1.0 (encoder padding allowed)", math.abs(m:getDuration() - 1.0) < 0.1)
    local ms = love.audio.newSource("jingle.mp3", "stream")
    check("mp3 stream loads", not ms._stub)
    check("mp3 stream duration about 1.0", math.abs(ms:getDuration() - 1.0) < 0.1)
    local many, all_ok = {}, true
    for n = 1, 5 do many[n] = love.audio.newSource("jingle.mp3", "stream"); all_ok = all_ok and not many[n]._stub end
    check("five mp3 streams open at once (Balatro streams five)", all_ok)
    check("unsupported format is silent, not an error", love.audio.newSource("beep.flac")._stub == true)

    steps = {
        function() o:play(); return wait(0.3) end,
        function() check("static playing", o:isPlaying() and o:tell() > 0.05); o:pause(); return wait(0.1) end,
        function() local p = o:tell(); check("pause holds the position", o:isPaused() and math.abs(o:tell() - p) < 0.01); o:stop(); check("stop rewinds", o:tell() == 0 and o:isStopped()); st:play(); return wait(0.3) end,
        function() check("stream playing and advancing", st:isPlaying() and st:tell() > 0.05); st:seek(0.7); return wait(0.1) end,
        function() check("seek moved the stream", st:tell() >= 0.7); return wait(0.5) end,
        function() check("stream ended", not st:isPlaying()); o:setPitch(2); o:play(); return wait(0.3) end,
        function() check("pitch 2 runs twice as fast", o:tell() > 0.4 or not o:isPlaying()); o:stop(); o:setPitch(1); o:setLooping(true); o:play(); return wait(1.3) end,
        function() check("looping source still playing past its end", o:isPlaying()); local c = o:clone(); c:setVolume(0); c:play(); check("clone plays independently", c:isPlaying()); love.audio.stop(); check("love.audio.stop() stops everything", not o:isPlaying() and not c:isPlaying()); return wait(0.05) end,
        function() m:play(); ms:play(); return wait(0.3) end,
        function() check("mp3 static and stream playing and advancing", m:isPlaying() and m:tell() > 0.05 and ms:isPlaying() and ms:tell() > 0.05); ms:seek(0.6); return wait(0.1) end,
        function() check("mp3 stream seek moved forward", ms:tell() >= 0.55); m:stop(); ms:stop(); check("mp3 stop rewinds", m:tell() == 0 and ms:tell() == 0); return wait(0.05) end,
        function() for n = 1, 5 do many[n]:play() end; return wait(0.3) end,
        function() local ok = true; for n = 1, 5 do ok = ok and many[n]:isPlaying() and many[n]:tell() > 0.05 end; check("five mp3 streams play and advance together", ok); for n = 1, 5 do many[n]:stop() end; return wait(0.05) end,
    }
    i = 1
    local nxt = steps[1]()
    steps.cond = nxt
end

function love.update()
    if not steps.cond then return end
    if steps.cond() then
        i = i + 1
        if steps[i] then steps.cond = steps[i]() else PSP_LOG("AUDIO done"); love.event.quit() end
    end
end
