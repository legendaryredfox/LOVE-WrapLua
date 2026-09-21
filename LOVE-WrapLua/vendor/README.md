# Vendored libraries

Pure-Lua, single-file dependencies bundled verbatim (no local patches) so the
wrapper's `love.data` hashing and compression work on the consoles, which give
us no C bindings and no package path. Both are Lua 5.1–5.4 + LuaJIT compatible;
they are **not** patched for Lua 5.5 (which makes numeric-`for` variables const)
because the CI/runtime targets are 5.1/5.3/5.4/luajit.

Both are pure Lua and slow on-device — cache results; do not hash/compress in a
hot loop.

## LibDeflate.lua
- Source: https://github.com/SafeteeWoW/LibDeflate (v1.0.2-release)
- License: zlib (see header in the file)
- Used by: `love.data.compress` / `love.data.decompress`
- Provides real DEFLATE (`CompressDeflate`) and zlib (`CompressZlib`).
- **Caveat:** LÖVE's `gzip` and `lz4` formats have no encoder here. Requests for
  them fall back to DEFLATE — round-trips within this wrapper, but the bytes are
  not compatible with desktop LÖVE's gzip/lz4. `deflate` and `zlib` output *is*
  byte-compatible with desktop LÖVE.

## sha2.lua
- Source: https://github.com/Egor-Skriptunoff/pure_lua_SHA (VERSION 12, 2022-02-23)
- License: MIT
- Used by: `love.data.hash`
- Provides md5, sha1, sha224/256/384/512 (and more). Returns lowercase hex;
  `love.data.hash` unhexes it to the raw-byte digest LÖVE returns.
