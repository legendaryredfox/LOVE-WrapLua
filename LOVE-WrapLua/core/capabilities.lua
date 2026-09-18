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
        limits    = { pointsize = 1, texturesize = 512, multicanvas = 1, canvasmsaa = 0,
                      potonly = true },
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

-- Power-of-two test that stays integer-safe on Lua 5.1 (no bitwise operators).
local function isPOT(n)
    if type(n) ~= "number" or n < 1 or n ~= math.floor(n) then return false end
    while n % 2 == 0 do n = n / 2 end
    return n == 1
end

-- Validates a texture/spritesheet against the active backend's hardware limits
-- and warns (once per distinct problem) instead of letting the GPU corrupt it
-- silently. Reused by newImage and newQuad; the PSP GPU needs power-of-two,
-- <=512x512 textures (FIX_PLAN T8.1). Returns true when the size is safe.
function lv1lua.core.validateTexture(w, h, name)
    local caps = love._backend or lv1lua.core.capabilities(lv1lua.mode)
    local max, ok = caps.limits.texturesize, true
    name = name or "image"

    if (w and w > max) or (h and h > max) then
        ok = false
        lv1lua.util.warn(string.format(
            "%s is %sx%s, larger than the %s texture limit of %d; split the spritesheet.",
            name, tostring(w), tostring(h), caps.renderer, max))
    end
    if caps.limits.potonly and (not isPOT(w) or not isPOT(h)) then
        ok = false
        lv1lua.util.warn(string.format(
            "%s is %sx%s, not power-of-two (required on %s); pad each dimension to a power of two.",
            name, tostring(w), tostring(h), caps.renderer))
    end
    return ok
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
