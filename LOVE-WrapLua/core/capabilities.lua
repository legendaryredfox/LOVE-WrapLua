-- Central, honest capability table for every backend (FIX_PLAN T4.5).
--
-- One place records what each backend can actually do today, so getSupported /
-- getSystemLimits stop reporting desktop-LÖVE defaults and the README matrix
-- (T7.1) can be generated from a single source. `supported` mirrors the LÖVE
-- getSupported feature set (plus honest canvas/shader flags); `limits` feeds
-- getSystemLimits; `features` is wrapper-internal (transform stack, quad draw,
-- primitives, …) and drives docs, not the LÖVE API.

lv1lua.core = lv1lua.core or {}

-- Shared "everything off" feature set; each backend overrides what it supports.
local function supported(over)
    local s = {
        clampzero          = false,
        glsl3              = false,
        instancing         = false,
        multicanvasformats = false,
        lighten            = false,
        fullnpot           = false,
        pixelshaderhighp   = false,
        shaderderivatives  = false,
        canvas             = false,  -- no offscreen render target on any backend
        shader             = false,  -- no programmable pipeline exposed
    }
    if over then for k, v in pairs(over) do s[k] = v end end
    return s
end

local CAPS = {
    -- OneLua on PS Vita.
    ["OneLua"] = {
        renderer  = "OneLua",
        limits    = { pointsize = 1, texturesize = 512, multicanvas = 1, canvasmsaa = 0 },
        supported = supported(),
        features  = { transform = true, quaddraw = true, polygonfill = true,
                      primitives = true, scissor = false, blendmode = false },
    },
    -- OneLua on PSP: power-of-two textures, no transform stack.
    ["PSP"] = {
        renderer  = "OneLua PSP",
        limits    = { pointsize = 1, texturesize = 512, multicanvas = 1, canvasmsaa = 0 },
        supported = supported(),
        features  = { transform = false, quaddraw = true, polygonfill = true,
                      primitives = true, scissor = false, blendmode = false },
    },
    -- lpp-vita (vita2d): quad+rotation draw, software transform stack + scissor.
    ["lpp-vita"] = {
        renderer  = "lpp-vita",
        limits    = { pointsize = 1, texturesize = 1024, multicanvas = 1, canvasmsaa = 0 },
        supported = supported({ fullnpot = true }),
        features  = { transform = true, quaddraw = true, polygonfill = true,
                      primitives = true, scissor = true, blendmode = false },
    },
    -- PS3 Lua Player: least-supported tier — position-only blits, no primitives.
    ["PS3"] = {
        renderer  = "PS3 Lua",
        limits    = { pointsize = 1, texturesize = 512, multicanvas = 1, canvasmsaa = 0 },
        supported = supported(),
        features  = { transform = false, quaddraw = false, polygonfill = false,
                      primitives = false, scissor = false, blendmode = false },
    },
}

function lv1lua.core.capabilities(key)
    return CAPS[key] or CAPS["OneLua"]
end

-- Installs love.graphics.getSupported / getSystemLimits (and love._backend)
-- from the table for `key`. Getters return fresh copies so a caller cannot
-- mutate the shared capability record.
function lv1lua.core.installCapabilities(key)
    local caps = lv1lua.core.capabilities(key)
    love._backend = caps

    function love.graphics.getSystemLimits()
        local l = caps.limits
        return { pointsize   = l.pointsize,
                 texturesize = l.texturesize,
                 multicanvas = l.multicanvas,
                 canvasmsaa  = l.canvasmsaa }
    end

    function love.graphics.getSupported()
        local out = {}
        for k, v in pairs(caps.supported) do out[k] = v end
        return out
    end
end
