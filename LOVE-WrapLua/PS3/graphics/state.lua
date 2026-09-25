-- PS3 graphics: native bring-up and the platform constants core/state.lua
-- drives.
--
-- The PS3 Lua Player exposes BlitToScreen/DrawText and little else, so most of
-- this backend is an honest stub. It is the least-supported tier; see
-- Implemented.md.

-- Bring up the native layer before anything draws.
InitGFX(720, 480)
InitFont("/dev_flash/data/font/SCE-PS3-RD-R-LATIN.TTF", 12)

lv1lua.gfx = {
    -- PS3 output is 720x480 while the game thinks in LÖVE's 1280x720-ish space.
    scale     = 0.5625,
    yOffset   = 37,
    lineWidth = 1,
    -- No native hooks: DrawText/BlitToScreen take no colour argument (so colour
    -- is only tracked), lv1lua.draw owns the frame clear, and there is no
    -- filter call.
}

-- Blend modes (FIX_PLAN T6.5). The player binds tiny3d's
-- tiny3d_BlendFunc(enable, srcFunc, dstFunc, func) as gfx.BlendFunction and
-- exposes the whole constant set on the gfx table, so every LOVE mode maps onto
-- real GPU state here, unlike on the other three backends.
--
-- tiny3d packs the RGB and alpha halves of each argument into disjoint bit
-- ranges (RGB low, alpha high) and expects them OR'd together. Lua 5.1 has no
-- bitwise operators and the halves never overlap, so they are added.
local BLEND = {
    alpha = {
        src = { "SRC_RGB_SRC_ALPHA", "SRC_ALPHA_SRC_ALPHA" },
        dst = { "DST_RGB_ONE_MINUS_SRC_ALPHA", "DST_ALPHA_ONE_MINUS_SRC_ALPHA" },
        fn  = { "RGB_FUNC_ADD", "ALPHA_FUNC_ADD" },
    },
    add = {
        src = { "SRC_RGB_SRC_ALPHA", "SRC_ALPHA_ZERO" },
        dst = { "DST_RGB_ONE", "DST_ALPHA_ONE" },
        fn  = { "RGB_FUNC_ADD", "ALPHA_FUNC_ADD" },
    },
    subtract = {
        src = { "SRC_RGB_SRC_ALPHA", "SRC_ALPHA_ZERO" },
        dst = { "DST_RGB_ONE", "DST_ALPHA_ONE" },
        fn  = { "RGB_FUNC_REVERSE_SUBTRACT", "ALPHA_FUNC_REVERSE_SUBTRACT" },
    },
    multiply = {
        src = { "SRC_RGB_DST_COLOR", "SRC_ALPHA_DST_ALPHA" },
        dst = { "DST_RGB_ZERO", "DST_ALPHA_ZERO" },
        fn  = { "RGB_FUNC_ADD", "ALPHA_FUNC_ADD" },
    },
    replace = {
        src = { "SRC_RGB_ONE", "SRC_ALPHA_ONE" },
        dst = { "DST_RGB_ZERO", "DST_ALPHA_ZERO" },
        fn  = { "RGB_FUNC_ADD", "ALPHA_FUNC_ADD" },
    },
    screen = {
        src = { "SRC_RGB_ONE", "SRC_ALPHA_ONE" },
        dst = { "DST_RGB_ONE_MINUS_SRC_COLOR", "DST_ALPHA_ONE_MINUS_SRC_COLOR" },
        fn  = { "RGB_FUNC_ADD", "ALPHA_FUNC_ADD" },
    },
    lighten = {
        src = { "SRC_RGB_ONE", "SRC_ALPHA_ONE" },
        dst = { "DST_RGB_ONE", "DST_ALPHA_ONE" },
        fn  = { "RGB_MAX", "ALPHA_MAX" },
    },
    darken = {
        src = { "SRC_RGB_ONE", "SRC_ALPHA_ONE" },
        dst = { "DST_RGB_ONE", "DST_ALPHA_ONE" },
        fn  = { "RGB_MIN", "ALPHA_MIN" },
    },
}

-- Reads a pair of gfx constants and combines them. Returns nil when the build
-- in front of us does not define one, which is what keeps an older player (the
-- SDL-only builds have no gfx table at all) from erroring on setBlendMode.
local function pair(prefix, names)
    local g = rawget(_G, "gfx")
    if type(g) ~= "table" then return nil end
    local a, b = g[prefix .. names[1]], g[prefix .. names[2]]
    if type(a) ~= "number" or type(b) ~= "number" then return nil end
    return a + b
end

lv1lua.gfx.blendHooks = {
    apply = function(mode)
        local g = rawget(_G, "gfx")
        if type(g) ~= "table" or type(g.BlendFunction) ~= "function" then return end
        local spec = BLEND[mode]
        if not spec then return end
        local src = pair("BLEND_FUNC_", spec.src)
        local dst = pair("BLEND_FUNC_", spec.dst)
        local fn  = pair("BLEND_", spec.fn)
        if not (src and dst and fn) then return end
        g.BlendFunction(1, src, dst, fn)
    end,
}

lv1lua.current = {
    -- Font wrapper object, assigned in graphics/font.lua.
    font        = nil,
    color       = nil,
    colorRGBA   = {1, 1, 1, 1},
    bgcolor     = nil,
    bgColorRGBA = {0, 0, 0, 1},
    canvas      = nil,
}
