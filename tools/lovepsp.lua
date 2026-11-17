-- Development steps for the native PSP backend, all in Lua. Run from the project root:
--   lua tools/lovepsp.lua build [--double] [--opt="-O2"]      compile native/EBOOT.PBP (docker pspdev)
--   lua tools/lovepsp.lua package <game_dir> <out_dir> [identity] [title]
--   lua tools/lovepsp.lua stage <game_dir> <out_dir>           package without the EBOOT (tests)
--   lua tools/lovepsp.lua manifest <dir>                      print the directory manifest the EBOOT reads
-- The C engine is the only part that needs a toolchain; everything else here is Lua over the shell.

local IMAGE = os.getenv("PSPDEV_IMAGE") or "pspdev/pspdev:latest"
local FONT  = "LOVE-WrapLua/Vera.ttf"

local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local function run(cmd)
    local ok, how, code = os.execute(cmd)
    if type(ok) == "number" then return ok == 0 end   -- Lua 5.1
    return ok == true and how == "exit" and code == 0
end

local function must(cmd, what)
    if not run(cmd) then error((what or cmd) .. " failed", 0) end
end

local function capture(cmd)
    local p = assert(io.popen(cmd))
    local s = p:read("*a")
    p:close()
    return s
end

local function exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local function write(path, s)
    local f = assert(io.open(path, "wb"))
    f:write(s)
    f:close()
end

-- ── manifest ─────────────────────────────────────────────────────
-- The emulator's host file system reports 8.3 names in capitals, so the backend reads the real names from here.
local function manifest(root)
    local entries = {}
    local out = capture("find " .. q(root) .. " -mindepth 1 -printf '%P\\t%y\\n'")
    local list, isdir = { [""] = {} }, { [""] = true }
    for line in out:gmatch("[^\n]+") do
        local path, kind = line:match("^(.*)\t(.)$")
        if path then
            local parent, name = path:match("^(.*)/([^/]+)$")
            if not parent then parent, name = "", path end
            list[parent] = list[parent] or {}
            local l = list[parent]
            l[#l + 1] = name
            if kind == "d" then isdir[path] = true; list[path] = list[path] or {} end
        end
    end
    local keys = {}
    for k in pairs(list) do keys[#keys + 1] = k end
    table.sort(keys)
    entries[#entries + 1] = "return {"
    for _, k in ipairs(keys) do
        table.sort(list[k])
        local names = {}
        for i, n in ipairs(list[k]) do names[i] = string.format("%q", n) end
        entries[#entries + 1] = string.format("  [%q] = {%s},", k, table.concat(names, ","))
    end
    entries[#entries + 1] = "}"
    return table.concat(entries, "\n") .. "\n"
end

-- ── build ────────────────────────────────────────────────────────
local function build(opts)
    local lua = "native/third_party/lua-5.1.5"
    if not exists(lua .. "/src/lua.h") then
        must("tar xzf native/third_party/lua-5.1.5.tar.gz -C native/third_party", "unpacking Lua 5.1.5")
        must("cd native/third_party && patch -s -p0 -d lua-5.1.5 --strip=1 < lua-5.1.5-psp.patch", "patching Lua")
    end
    local float = opts.double and "" or "-DPSP_LUA_FLOAT"
    local opt = opts.opt or "-O2"
    local key = float .. "|" .. opt
    local keyfile = "native/.luaflags"
    local uid, gid = capture("id -u"):gsub("%s", ""), capture("id -g"):gsub("%s", "")
    local cwd = capture("pwd"):gsub("\n", "")
    local docker = "docker run --rm --user " .. uid .. ":" .. gid .. " -v " .. q(cwd .. "/native") .. ":/work -w /work " .. IMAGE
    if (exists(keyfile) and read(keyfile) or "") ~= key then
        run(docker .. " make clean >/dev/null 2>&1")
        write(keyfile, key)
    end
    must(docker .. " make LUAFLOAT=" .. q(float) .. " OPT=" .. q(opt), "make")
    if not exists("native/EBOOT.PBP") then error("native/EBOOT.PBP was not produced", 0) end
    print("built native/EBOOT.PBP (" .. (float == "" and "double" or "float") .. " numbers, " .. opt .. ")")
end

-- ── package ──────────────────────────────────────────────────────
-- Shared wrapper modules the backend loads at boot (PSPNative/shared.lua). Hash libraries in vendor/ are read
-- only when a game calls love.data.hash.
local SHARED = {
    "core/loader.lua", "core/util.lua", "core/drawobject.lua", "core/spritebatch.lua", "core/particles.lua", "math.lua", "math", "data.lua", "data", "vendor",
}

-- Everything except the EBOOT: the game, the backend, the shared modules, the config and the manifest.
local function stage(game, out, identity, title)
    identity = identity or game:gsub("/+$", ""):match("([^/]+)$")
    title = title or identity
    must("rm -rf " .. q(out) .. " && mkdir -p " .. q(out .. "/game") .. " " .. q(out .. "/save")
        .. " " .. q(out .. "/LOVE-WrapLua/core"))
    must("cp -R " .. q(game .. "/.") .. " " .. q(out .. "/game/"), "copying the game")
    if not exists(out .. "/game/default.ttf") then must("cp " .. q(FONT) .. " " .. q(out .. "/game/default.ttf")) end
    for _, f in ipairs({ "boot.lua", "love_psp.lua", "psp_ffi.lua", "shared.lua", "extras.lua" }) do
        must("cp " .. q("LOVE-WrapLua/PSPNative/" .. f) .. " " .. q(out .. "/" .. f))
    end
    for _, f in ipairs(SHARED) do
        must("cp -R " .. q("LOVE-WrapLua/" .. f) .. " " .. q(out .. "/LOVE-WrapLua/" .. f:gsub("[^/]*$", "")), "copying " .. f)
    end
    write(out .. "/psp_config.lua", string.format("return { identity = %q, title = %q, font = \"default.ttf\" }\n", identity, title))
    write(out .. "/manifest.lua", manifest(out .. "/game"))
end

local function package(game, out, identity, title)
    if not exists("native/EBOOT.PBP") then error("build the EBOOT first: lua tools/lovepsp.lua build", 0) end
    stage(game, out, identity, title)
    must("cp native/EBOOT.PBP " .. q(out .. "/EBOOT.PBP"))
    print("packaged " .. out)
end

-- ── command line ─────────────────────────────────────────────────
local cmd = arg[1]
local rest = {}
for i = 2, #arg do rest[#rest + 1] = arg[i] end
local ok, err = pcall(function()
    if cmd == "build" then
        local opts = {}
        for _, a in ipairs(rest) do
            if a == "--double" then opts.double = true
            elseif a:match("^%-%-opt=") then opts.opt = a:match("^%-%-opt=(.*)$") end
        end
        build(opts)
    elseif cmd == "package" then
        if #rest < 2 then error("usage: package <game_dir> <out_dir> [identity] [title]", 0) end
        package(rest[1], rest[2], rest[3], rest[4])
    elseif cmd == "stage" then
        if #rest < 2 then error("usage: stage <game_dir> <out_dir> [identity] [title]", 0) end
        stage(rest[1], rest[2], rest[3], rest[4])
    elseif cmd == "manifest" then
        if not rest[1] then error("usage: manifest <dir>", 0) end
        io.write(manifest(rest[1]))
    else
        error("usage: lua tools/lovepsp.lua build | package | stage | manifest", 0)
    end
end)
if not ok then io.stderr:write(tostring(err), "\n"); os.exit(1) end
