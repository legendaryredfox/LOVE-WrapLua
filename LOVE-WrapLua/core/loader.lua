-- Internal module loader.
--
-- Console SDKs give us no usable package path, and `require` is remapped to the
-- game directory (see script.lua), so every internal module is pulled in with
-- dofile plus the platform data prefix. `lv1lua.load` centralises that so module
-- files never repeat the prefix dance.
--
-- This file is the one exception: it has to be dofile'd directly.

lv1lua = lv1lua or {}

function lv1lua.load(path)
    return dofile((lv1lua.dataloc or "") .. path)
end

-- Loads `path` only once per session. Used where several entry points pull in
-- the same shared module (e.g. core/util from every backend).
local _loaded = {}
function lv1lua.loadOnce(path)
    if _loaded[path] then return _loaded[path] end
    local result = lv1lua.load(path)
    _loaded[path] = result == nil and true or result
    return result
end
