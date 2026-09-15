-- Backward-compatible shim.  Historically this file was the single OneLua
-- mock; it is now a thin loader kept so existing test files keep working.
-- New multi-backend tests should dofile `tests/setup.lua` directly and set
-- `__MODE` to pick the backend.
__MODE = __MODE or "OneLua"
dofile("tests/setup.lua")
