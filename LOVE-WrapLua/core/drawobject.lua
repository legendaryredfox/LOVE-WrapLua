-- Placing a whole object (SpriteBatch, Text, ParticleSystem) the way one sprite is placed.

lv1lua.core = lv1lua.core or {}

-- draw(object, x, y, r, sx, sy, ox, oy) places a whole batch, text or particle
-- system the way it places one sprite. The object replays its own draws inside
-- that transform, pushed onto the stack every backend folds into its draws.
function lv1lua.core.withDrawTransform(x, y, r, sx, sy, ox, oy, fn)
    local lg = love.graphics
    sx = sx or 1; sy = sy or sx
    lg.push()
    lg.translate(x or 0, y or 0)
    if r and r ~= 0 then lg.rotate(r) end
    if sx ~= 1 or sy ~= 1 then lg.scale(sx, sy) end
    if (ox and ox ~= 0) or (oy and oy ~= 0) then lg.translate(-(ox or 0), -(oy or 0)) end
    local ok, err = pcall(fn)
    lg.pop()
    if not ok then error(err, 0) end
end
