-- Generic PSP boot for any LÖVE 11 game placed in game/ (main.lua, conf.lua optional).
-- Optional psp_config.lua next to the EBOOT: return { identity=, title=, os=, font= }.
package.path = "game/?.lua;game/?/init.lua;./?.lua"
local f = io.open("psp_log.txt", "w"); if f then f:close() end
-- watchdog.flag next to the EBOOT: log a traceback every 30M VM instructions (finds stalls)
if loadfile("watchdog.flag") then
    local n = 0
    PSP_HOOK = function() n = n + 1; if n <= 8 then PSP_LOG("WATCHDOG #" .. n .. " " .. debug.traceback("", 2)) end end
end
if loadfile("framelog.flag") then PSP_FRAMELOG = 120 end   -- framelog.flag: log every 120 presents
dofile("love_psp.lua")
dofile("shared.lua")
-- ffi/jit/table.new shim for games written for LuaJIT (psp_ffi.lua is shipped with the backend)
local ffi_shim = loadfile("psp_ffi.lua"); if ffi_shim then package.preload.ffi = ffi_shim; ffi_shim() end
-- trace_require.flag next to the EBOOT: log every require (enter/leave) to find where a boot stops
if loadfile("trace_require.flag") then
    local real, depth = require, 0
    -- game print() output goes to psp_log.txt too (otherwise it is lost on the PSP)
    function print(...)
        local t = { ... }
        for i = 1, select("#", ...) do t[i] = tostring(t[i]) end
        PSP_LOG("print: " .. table.concat(t, "\t"))
    end
    local gi = love.filesystem.getInfo
    love.filesystem.getInfo = function(path, ...)
        local r = gi(path, ...)
        if r == nil then PSP_LOG("getInfo MISSING: " .. tostring(path)) end
        return r
    end
    local rl = love.filesystem.load
    love.filesystem.load = function(path, ...)
        local before = collectgarbage("count")
        local fn, err = rl(path, ...)
        if not fn then return fn, err end
        return function(...)
            PSP_LOG("load> " .. tostring(path) .. string.format(" [lua %dKB]", collectgarbage("count")))
            local b = collectgarbage("count")
            local r = { fn(...) }
            local d = collectgarbage("count") - b
            if d > 256 then PSP_LOG(string.format("load %s: +%dKB (now %dKB)", tostring(path), d, collectgarbage("count"))) end
            return unpack(r)
        end
    end
    -- memory watch: every 200k VM instructions, log a traceback when the heap grew by more than 6 MB
    local rr = love.filesystem.read
    love.filesystem.read = function(path, ...)
        PSP_LOG("fs.read " .. tostring(path) .. string.format(" [lua %dKB]", collectgarbage("count")))
        return rr(path, ...)
    end
    local last = collectgarbage("count")
    local function memwatch()
        local c = collectgarbage("count")
        if c - last > 2048 then PSP_LOG(string.format("MEMWATCH heap %dKB (+%dKB)\n%s", c, c - last, debug.traceback("", 2))) end
        last = c
    end
    -- ring buffer of the last executed lines: "not enough memory" carries no traceback, this shows where it happened
    local ring, rn = {}, 0
    PSP_LINES = function() local t = {}; for i = 1, 40 do local e = ring[(rn + i) % 40 + 1]; if e then t[#t + 1] = e end end return table.concat(t, "\n") end
    local getinfo = debug.getinfo
    PSP_MEMWATCH = function(ev, line)
        if ev == "line" then local i = getinfo(2, "S"); rn = (rn + 1) % 40; ring[rn + 1] = i.short_src .. ":" .. line else memwatch() end
    end
    debug.sethook(PSP_MEMWATCH, "", 20000)
    function require(name)
        PSP_LOG(string.rep(" ", depth) .. "require> " .. tostring(name) .. string.format("  [lua %dKB free %dKB]", collectgarbage("count"), native.mem() / 1024)); depth = depth + 1
        local ok, r = pcall(real, name); depth = depth - 1
        PSP_LOG(string.rep(" ", depth) .. "require< " .. tostring(name) .. (ok and "" or (" ERR " .. tostring(r))))
        if not ok then error(r, 0) end
        return r
    end
end
if PSP_HOOK then debug.sethook(PSP_HOOK, "", 30000000) end
if native.palette and loadfile("nopalette.flag") then native.palette(false) end   -- A/B: RGBA8888 textures only
native.cpu(333)
native.begin_frame()

local function crash(msg)
    if PSP_LINES then PSP_LOG("LAST LINES:\n" .. PSP_LINES()) end
    PSP_LOG("FATAL: " .. tostring(msg) .. string.format("  [lua %dKB, free %dKB, largest block %dKB, tex %dKB]", collectgarbage("count"), native.mem() / 1024, select(2, native.mem()) / 1024, (native.tex_mem and native.tex_mem() or 0) / 1024))
    local lines = {}
    for l in tostring(msg):gmatch("[^\n]+") do lines[#lines + 1] = l end
    local ok, font = pcall(love.graphics.newFont, 12)
    for _ = 1, 1800 do
        love.graphics.clear(0.4, 0, 0, 1)
        love.graphics.setColor(1, 1, 1, 1)
        if ok then
            love.graphics.setFont(font)
            for i = 1, math.min(#lines, 20) do love.graphics.print(lines[i]:sub(1, 90), 4, 4 + (i - 1) * 12) end
        end
        love.graphics.present()
    end
end

-- Standard LÖVE 11 main loop, used when the game does not define love.run.
local function default_run()
    if love.load then love.load({}, {}) end
    if love.timer then love.timer.step() end
    local dt = 0
    return function()
        if love.event then
            love.event.pump()
            for name, a, b, c, d, e, f in love.event.poll() do
                if name == "quit" then if not love.quit or not love.quit() then return a or 0 end end
                love.handlers[name](a, b, c, d, e, f)
            end
        end
        if love.timer then dt = love.timer.step() end
        if love.update then love.update(dt) end
        love.graphics.origin()
        love.graphics.clear(love.graphics.getBackgroundColor())
        if love.draw then love.draw() end
        love.graphics.present()
        if love.timer then love.timer.sleep(0.001) end
    end
end

local ok, err = xpcall(function()
    -- LÖVE order: conf.lua (love.conf) first, then main.lua
    local conf = loadfile("game/conf.lua")
    if conf then
        conf()
        if love.conf then love.conf({ window = {}, modules = {}, audio = {}, version = "11.5", identity = nil }) end
    end
    local main = assert(loadfile("game/main.lua"))
    PSP_LOG("conf ok; running main.lua"); main(); PSP_LOG("main.lua ok; love.run=" .. tostring(love.run ~= nil))
    local loop = (love.run and love.run()) or default_run()
    PSP_LOG("love.run returned loop")
    local frames = 0
    while true do
        local r = loop()
        frames = frames + 1
        if frames == 1 or frames % 300 == 0 then
            PSP_LOG(string.format("frame %d t=%.1f lua=%dKB free=%dKB tex=%dKB", frames, love.timer.getTime(), collectgarbage("count"), native.mem() / 1024, (native.tex_mem and native.tex_mem() or 0) / 1024))
        end
        if r then break end
    end
end, function(e) return debug.traceback(tostring(e), 2) end)
if not ok then crash(err) end
native.exit()
