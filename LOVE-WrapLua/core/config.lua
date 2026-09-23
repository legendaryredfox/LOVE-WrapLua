-- Configuration: the game's conf.lua, the wrapper's own lv1luaconf, and the
-- button layout that follows from it.

-- ── game/conf.lua ────────────────────────────────────────────────
-- LÖVE hands love.conf a table to fill in; keep it local so the game's conf
-- does not leak a global.
local conf = { window = {}, modules = {} }
lv1lua.loveconf = conf

if lv1lua.exists(lv1lua.dataloc .. "game/conf.lua") then
    dofile(lv1lua.dataloc .. "game/conf.lua")
    love.conf(conf)
    lv1lua.loveconf = conf
    if not lv1lua.loveconf.identity then
        lv1lua.loveconf.identity = "LOVE-WrapLua"
    end
end

-- ── wrapper config ───────────────────────────────────────────────
if not lv1luaconf then
    lv1luaconf = {
        keyconf  = "XB",
        imgscale = false,
        resscale = false,
    }
end

-- The draw code reads `imgscale` / `resscale`; older docs and games spell them
-- `img_scale` / `res_scale`. Accept both so a game written against either name
-- actually scales instead of being silently ignored.
if lv1luaconf.imgscale == nil then lv1luaconf.imgscale = lv1luaconf.img_scale or false end
if lv1luaconf.resscale == nil then lv1luaconf.resscale = lv1luaconf.res_scale or false end

-- ── button layout ────────────────────────────────────────────────
-- "SE" means "follow the console's own enter-button setting", which differs by
-- region: circle-to-confirm on Japanese units, cross elsewhere.
if lv1luaconf.keyconf == "SE" then
    lv1lua.confirm = false

    if lv1lua.mode == "lpp-vita" then
        if Controls.getEnterButton() == SCE_CTRL_CIRCLE then lv1lua.confirm = true end
    elseif lv1lua.mode == "OneLua" then
        if buttons.assign() == 0 then lv1lua.confirm = true end
        if not lv1lua.isPSP then
            -- Vita-only input modules.
            lv1lua.load("LOVE-WrapLua/" .. lv1lua.mode .. "/touch.lua")
            lv1lua.load("LOVE-WrapLua/" .. lv1lua.mode .. "/mouse.lua")
        end
    end

    lv1luaconf.keyconf = lv1lua.confirm and "XBA" or "XB"
end

-- Maps the console's face buttons onto the LÖVE key names games expect.
if lv1luaconf.keyconf == "XB" then
    lv1lua.keyset = {"b","a","y","x","leftshoulder","rightshoulder"}
elseif lv1luaconf.keyconf == "XBA" then
    lv1lua.keyset = {"a","b","x","y","leftshoulder","rightshoulder"}
elseif lv1luaconf.keyconf == "PS" then
    lv1lua.keyset = {"circle","cross","triangle","square","l","r"}
end
