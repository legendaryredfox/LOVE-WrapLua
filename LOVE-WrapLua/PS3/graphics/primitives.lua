-- PS3 graphics: primitives.
--
-- Filled-shape calls are not available across PS3 Lua players, so these accept
-- their arguments and draw nothing rather than crashing the game. A real
-- implementation needs the tiny3D/Mini2D backend (FIX_PLAN T6.6).

function love.graphics.rectangle(mode, x, y, w, h)  end
function love.graphics.line(...)                    end
function love.graphics.circle(mode, x, y, radius, segments)      end
function love.graphics.ellipse(mode, x, y, rx, ry, segments)     end
function love.graphics.polygon(mode, vertices, ...)              end
function love.graphics.arc(mode, arctype, x, y, radius, a1, a2, segs) end
function love.graphics.points(...)                  end
