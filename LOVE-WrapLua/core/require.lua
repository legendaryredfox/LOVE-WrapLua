-- Redirects the game's `require` into the game directory.
--
-- Games written for LÖVE do `require("libraries.anim8")` or
-- `require("libraries/anim8")` relative to their own folder, which is not where
-- the console's module search starts.

lv1lua.core = lv1lua.core or {}

-- Lua's require takes dots as path separators; a console `dofile` takes them
-- literally, so "libraries.anim8" has to become "libraries/anim8.lua".
local function resolvePath(param)
    param = tostring(param)
    if string.sub(param, -4) == ".lua" then
        param = string.sub(param, 1, -5)
    end
    return (string.gsub(param, "%.", "/")) .. ".lua"
end

-- Not everything a game requires lives in game/: the vendored libraries ask
-- for the interpreter's own modules (LuaJIT's "bit", for one), so a name that
-- does not resolve inside the game folder falls back to the original require
-- instead of failing.
local systemRequire = require

if lv1lua.mode == "OneLua" then
    -- OneLua's require does have a working search path; just prefix it.
    lv1lua.core.oldRequire = systemRequire
    function require(param)
        local ok, result = pcall(systemRequire, "game/" .. param)
        if ok then return result end
        return systemRequire(param)
    end
else
    -- Elsewhere there is no package path at all, so fall back to dofile, with
    -- require's own caching: a module runs once, and every later require of it
    -- (in either spelling) gets the same value back.
    local loaded = {}
    function require(param)
        local path = resolvePath(param)
        local cached = loaded[path]
        if cached ~= nil then return cached end

        local full = lv1lua.dataloc .. "game/" .. path
        local chunk = loadfile(full)
        if not chunk then
            -- Not a game file: let the interpreter resolve it (vendored
            -- libraries pull in "bit" and friends this way).
            if systemRequire then return systemRequire(param) end
            error("module '" .. tostring(param) .. "' not found at " .. full, 2)
        end

        local result = chunk()
        if result == nil then result = true end
        loaded[path] = result
        return result
    end
end
