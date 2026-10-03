-- Backward-compatible shim.  Historically this file was the single OneLua
-- mock; it is now a thin loader kept so existing test files keep working.
-- New multi-backend tests should dofile `tests/setup.lua` directly and set
-- `__MODE` to pick the backend.
-- Always OneLua: inheriting __MODE from whichever suite ran last in the same
-- run_all process silently ran these tests under another backend.
__MODE = "OneLua"
dofile("tests/setup.lua")
