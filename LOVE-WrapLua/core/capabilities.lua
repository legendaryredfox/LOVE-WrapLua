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

-- Behaviour that is right on real hardware but varies by emulator renderer, so
-- it must never be the thing a game's look depends on (FIX_PLAN T8.4). Each
-- flag is true when the backend's usual emulator gets it wrong or inconsistent:
--   blendmode        programmable blend / alpha differs per renderer
--   framebufferread  reading back the framebuffer (screenshots, RTT) is unreliable
--   texturefilter    filtering at quad edges bleeds neighbouring frames
--   savepersistence  writes can be lost when the emulator is closed
local function rendersensitive(over)
    local r = { blendmode = false, framebufferread = false,
                texturefilter = false, savepersistence = false }
    if over then for k, v in pairs(over) do r[k] = v end end
    return r
end

-- What love.system can answer on each target (FIX_PLAN T6.1). `cores` is the
-- CPU count the console actually gives a game, `battery` says whether a power
-- state exists to read at all, and `vibrate`/`openurl` record that no SDK here
-- exposes rumble or a browser hand-off. The clipboard is in-memory everywhere:
-- no console exposes a system one.
local function systemcaps(over)
    local s = { cores = 1, battery = true, vibrate = false, openurl = false,
                clipboard = "memory" }
    if over then for k, v in pairs(over) do s[k] = v end end
    return s
end

-- Which LOVE blend modes actually change compositing on each target
-- (FIX_PLAN T6.5). `native` says a blend call exists at all; `modes` lists the
-- ones that reach it. Everything else is tracked and renders as alpha, which is
-- what the platform default is on all four.
local function blendcaps(over)
    local b = { native = false, modes = { alpha = true } }
    if over then
        for k, v in pairs(over) do
            if k == "modes" then
                for m in pairs(v) do b.modes[m] = true end
            else
                b[k] = v
            end
        end
    end
    return b
end

-- What love.audio can do per target (FIX_PLAN T6.2). `voices` is how many
-- sounds can be audible at once, `seek`/`pitch` say whether the SDK really
-- seeks or resamples (where false, the shared layer only moves the position it
-- reports), and `formats` is what the decoder accepts.
local function audiocaps(over)
    local a = { voices = 1, seek = false, pitch = false, formats = "mp3" }
    if over then for k, v in pairs(over) do a[k] = v end end
    return a
end

-- `tier` is the support promise documented in the README: 1 supported,
-- 2 partial, 3 experimental (develop on desktop LOVE, confirm on hardware).
local CAPS = {
    -- OneLua on PS Vita.
    ["OneLua"] = {
        renderer  = "OneLua",
        tier      = 1,
        limits    = { pointsize = 1, texturesize = 512, multicanvas = 1, canvasmsaa = 0 },
        supported = supported(),
        features  = { transform = true, quaddraw = true, polygonfill = true,
                      primitives = true, scissor = false, blendmode = false },
        -- Vita3K: inaccurate programmable blend (#4109) and framebuffer reads
        -- (#422), both varying GL vs Vulkan vs MoltenVK; saves lost on close
        -- (#3918, #3659).
        emulator  = "Vita3K",
        rendersensitive = rendersensitive({ blendmode = true, framebufferread = true,
                                            savepersistence = true }),
        system    = systemcaps({ cores = 4 }),
        audio     = audiocaps({ voices = 2 }),
        -- The Vita port of ONElua kept blit / blitsprite / blittint and dropped
        -- the PSP's additive and subtractive blits, so alpha is all there is.
        blend     = blendcaps(),
    },
    -- OneLua on PSP: power-of-two textures, no transform stack.
    ["PSP"] = {
        renderer  = "OneLua PSP",
        tier      = 1,
        limits    = { pointsize = 1, texturesize = 512, multicanvas = 1, canvasmsaa = 0,
                      potonly = true },
        supported = supported(),
        features  = { transform = false, quaddraw = true, polygonfill = true,
                      primitives = true, scissor = false, blendmode = true },
        -- PPSSPP: texel bleed at quad edges (#14977) and framebuffer/texture
        -- sizing differences from hardware (#3085).
        emulator  = "PPSSPP",
        rendersensitive = rendersensitive({ texturefilter = true, framebufferread = true }),
        system    = systemcaps({ cores = 1 }),
        audio     = audiocaps({ voices = 2 }),
        -- OSLib's OSL_FX_ADD / OSL_FX_SUB reach Lua as image.blitadd /
        -- image.blitsub. Whole images only: neither takes a source rect, so a
        -- quad draw falls back to alpha.
        blend     = blendcaps({ native = true, imagesonly = true,
                                modes = { add = true, subtract = true } }),
    },
    -- lpp-vita (vita2d): quad+rotation draw, software transform stack + scissor.
    ["lpp-vita"] = {
        renderer  = "lpp-vita",
        tier      = 2,
        limits    = { pointsize = 1, texturesize = 1024, multicanvas = 1, canvasmsaa = 0 },
        supported = supported({ fullnpot = true }),
        features  = { transform = true, quaddraw = true, polygonfill = true,
                      primitives = true, scissor = true, blendmode = false },
        emulator  = "Vita3K",
        rendersensitive = rendersensitive({ blendmode = true, framebufferread = true,
                                            savepersistence = true }),
        system    = systemcaps({ cores = 4 }),
        audio     = audiocaps({ voices = 8, formats = "mp3, ogg, wav" }),
        -- Graphics_functions[] has no blend entry: initBlend / termBlend are
        -- the drawing-phase begin/end (vita2d_start_drawing / end_drawing).
        blend     = blendcaps(),
    },
    -- PS3 Lua Player: least-supported tier, position-only blits, no primitives.
    ["PS3"] = {
        renderer  = "PS3 Lua",
        tier      = 3,
        limits    = { pointsize = 1, texturesize = 512, multicanvas = 1, canvasmsaa = 0 },
        -- tiny3d's blend function reaches Lua, which is what LOVE's `lighten`
        -- feature flag means (the lighten/darken blend equations).
        supported = supported({ lighten = true }),
        features  = { transform = false, quaddraw = false, polygonfill = false,
                      primitives = false, scissor = false, blendmode = true },
        -- RPCS3 barely loads homebrew (#18997), so nothing here is emulator
        -- verifiable: treat every renderer-sensitive area as unconfirmed.
        emulator  = "RPCS3 (homebrew loading unreliable)",
        rendersensitive = rendersensitive({ blendmode = true, framebufferread = true,
                                            texturefilter = true, savepersistence = true }),
        -- A home console: there is no battery to report.
        system    = systemcaps({ cores = 2, battery = false }),
        -- One background voice: no binding for one-shot effects.
        audio     = audiocaps({ voices = 1 }),
        -- The player binds tiny3d's tiny3d_BlendFunc as gfx.BlendFunction and
        -- puts the whole constant set on the gfx table, so every LOVE mode maps.
        blend     = blendcaps({ native = true,
                                modes = { add = true, subtract = true, multiply = true,
                                          replace = true, screen = true,
                                          lighten = true, darken = true } }),
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

    -- A size the caller could not work out (a native handle the SDK will not
    -- measure) is skipped rather than compared, which would raise.
    if type(w) ~= "number" then w = nil end
    if type(h) ~= "number" then h = nil end
    if not w and not h then return true end

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
