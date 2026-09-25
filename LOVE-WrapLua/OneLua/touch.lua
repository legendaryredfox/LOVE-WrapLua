-- OneLua (Vita): love.touch over the front touchscreen.
--
-- The SDK reports `touch.front` as an array of {x, y, pressed} with a `count`
-- field, refreshed by the frame loop. Ids are 1-based and only ids up to
-- `count` are live.

love.touch._touches = {}
love.touch._count   = 0

function love.touch.__getFrontTouches(touchUserData)
    local front = touchUserData and touchUserData.front or { count = 0 }
    love.touch._count = front.count or 0
    for i = 1, love.touch._count do
        love.touch._touches[i] = front[i]
    end
    -- Drop anything left over from a frame with more fingers down.
    for i = love.touch._count + 1, #love.touch._touches do
        love.touch._touches[i] = nil
    end
end

local function touchAt(id)
    if type(id) ~= "number" or id < 1 or id > love.touch._count then return nil end
    return love.touch._touches[id]
end

function love.touch.getPosition(id)
    local t = touchAt(id)
    if not t then return 0, 0 end
    return t.x, t.y
end

function love.touch.getPressure(id)
    local t = touchAt(id)
    if t and t.pressed then return 1 end
    return 0
end

function love.touch.getTouches()
    local ids = {}
    for i = 1, love.touch._count do ids[i] = i end
    return ids
end
