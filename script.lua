-- LOVE-WrapLua entry point.
--
-- index.lua / app.lua set lv1lua.mode (and lv1lua.dataloc) for the console they
-- are built for, then dofile this. Everything below is ordered: the runtime and
-- config have to exist before any backend module loads, the backend before the
-- game, and the game before its callbacks are wired.

if not lv1lua then lv1lua = {} end

dofile((lv1lua.dataloc or "") .. "LOVE-WrapLua/core/loader.lua")

lv1lua.loadOnce("LOVE-WrapLua/core/util.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/transform.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/textwrap.lua")

lv1lua.loadOnce("LOVE-WrapLua/core/runtime.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/input.lua")
lv1lua.load("LOVE-WrapLua/love-functions/thread.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/config.lua")
-- After config: the accumulator reads lv1luaconf.updaterate / maxframeskip.
lv1lua.loadOnce("LOVE-WrapLua/core/timestep.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/modules.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/require.lua")

-- ── start the game ───────────────────────────────────────────────
love.math.setRandomSeed(os.time())
dofile(lv1lua.dataloc .. "game/main.lua")
if love.load then love.load() end

lv1lua.loadOnce("LOVE-WrapLua/core/callbacks.lua")

-- ── main loop ────────────────────────────────────────────────────
while lv1lua.running do
    lv1lua.draw()
    lv1lua.update()
    lv1lua.updatecontrols()
end
