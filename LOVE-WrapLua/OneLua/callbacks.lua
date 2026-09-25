-- Vita Live Area hooks (WIP).
--
-- Kept under lv1lua so a game cannot collide with them by defining its own
-- onLiveArea / onResume, and so the frame loop can call them unconditionally.

function lv1lua.onLiveArea()
    -- love.audio.pause()
end

function lv1lua.onResume()
    -- love.audio.resume()
end
