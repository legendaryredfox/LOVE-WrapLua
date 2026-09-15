-- Redirects the game's `require` into the game directory.
--
-- Games written for LÖVE do `require("libraries/anim8")` relative to their own
-- folder, which is not where the console's module search starts.

if lv1lua.mode == "OneLua" then
    -- OneLua's require does have a working search path; just prefix it.
    __oldRequire = require
    function require(param)
        return __oldRequire("game/" .. param)
    end
else
    -- Elsewhere there is no package path at all, so fall back to dofile.
    function require(param)
        if string.sub(param, -4) == ".lua" then
            param = lv1lua.dataloc .. "game/" .. param
        else
            param = lv1lua.dataloc .. "game/" .. param .. ".lua"
        end
        return dofile(param)
    end
end
