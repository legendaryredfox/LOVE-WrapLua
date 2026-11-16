-- OneLua native capability probe.
--
-- The ONElua builds differ in which image.* and screen.* calls they ship: the stock PSP EBOOT.PBP has no
-- image.copyscale, the Vita port has no additive or subtractive blit. Probing once, here, replaces a type()
-- test on every draw, and lets a draw degrade instead of raising on a call that is not there.
-- lv1lua.core.probeNative() refills lv1lua.native in place (also love._backend.native), so code that captured
-- the table sees a later probe. It lives beside lv1lua.gfx, not in it: each state.lua builds a new gfx table.

lv1lua.core = lv1lua.core or {}

local native = lv1lua.native or {}
lv1lua.native = native

local IMAGE_CALLS = { "copyscale", "resize", "rotate", "center", "fliph", "flipv", "copy",
                      "blittint", "blitadd", "blitsub" }

local function has(t, name) return type(t) == "table" and type(t[name]) == "function" end

function lv1lua.core.probeNative()
    for _, name in ipairs(IMAGE_CALLS) do native[name] = has(image, name) end
    native.clip = has(screen, "clip")
    -- A scaled draw needs a scaled copy, or resize + clip to scale the sheet and cut the rectangle out.
    native.scaling = native.copyscale or (native.resize and native.clip) or false
    return native
end

lv1lua.core.probeNative()
