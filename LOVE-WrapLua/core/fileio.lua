-- File access seam for the shared modules.
--
-- filesystem.lua, core/audio.lua and core/require.lua open files through
-- lv1lua.fileio instead of calling io.open / loadfile directly, because one
-- player (lpp-3ds) rebinds io.open, io.read, io.write and io.close to its own
-- handle-based calls, so the standard file object never exists there. A
-- backend like that installs its own table before this file loads; everywhere
-- else the defaults below are the standard library.
--
--   open(path, mode)  a file object with :read(n | "*a"), :write(s),
--                     :seek(whence, offset) and :close(), or nil, err
--   loadfile(path)    a compiled chunk, or nil, err
--
-- Optional, used by filesystem.lua where present (each SDK answers these
-- differently, and the generic fallbacks there probe through `open`):
--
--   exists(path)  isDir(path)  list(dir) -> names  mkdir(path)  remove(path)

lv1lua.fileio = lv1lua.fileio or {}
local fileio = lv1lua.fileio

if not fileio.open then
    function fileio.open(path, mode) return io.open(path, mode) end
end

if not fileio.loadfile then
    function fileio.loadfile(path) return loadfile(path) end
end
