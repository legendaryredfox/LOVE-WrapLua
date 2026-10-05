# Vendored libraries

Pure-Lua, single-file dependencies bundled so `love.data` hashing and
compression work on the consoles, which offer no C bindings and no package
path. Both run on Lua 5.1 to 5.5 and LuaJIT.

Both are pure Lua and slow on device: cache results, and never hash or
compress in a hot loop.

## LibDeflate.lua
- Source: https://github.com/SafeteeWoW/LibDeflate (v1.0.2-release), verbatim
- License: zlib (see the header in the file)
- Used by: `love.data.compress` / `love.data.decompress`
- Provides real DEFLATE (`CompressDeflate`) and zlib (`CompressZlib`). Their
  output is byte-compatible with desktop LÖVE.
- LÖVE's `gzip` and `lz4` have no encoder here. Requests for them fall back to
  DEFLATE, which round-trips within this wrapper but is not byte-compatible
  with desktop LÖVE's gzip or lz4.

## sha2.lua
- Source: https://github.com/Egor-Skriptunoff/pure_lua_SHA (VERSION 12, 2022-02-23)
- License: MIT
- Used by: `love.data.hash`
- Provides md5, sha1 and sha224/256/384/512 (and more) as lowercase hex;
  `love.data.hash` turns that into the raw digest LÖVE returns.
- **One local patch**, marked at the top of the file: upstream assigns to
  numeric `for` control variables, which Lua 5.5 makes const, so each site
  writes to a shadow local instead. Behaviour is unchanged on 5.1 to 5.4.
