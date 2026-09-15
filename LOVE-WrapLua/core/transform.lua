-- Software transform stack, shared by the backends.
--
-- None of the console SDKs exposes a matrix stack, so push/pop/translate/scale/
-- rotate/scissor are tracked here and flattened into plain offsets, scales and a
-- rotation that the native draw calls can consume.
--
-- Each stack level composes into its own transform (two translates inside one
-- push must add up), and the flattened result is cached until something marks
-- the stack dirty.

lv1lua.core = lv1lua.core or {}

local Level = {}
Level.__index = Level

function Level.new()
    return setmetatable({
        _offsetX = 0, _offsetY = 0,
        _scaleX  = 1, _scaleY  = 1,
        _rotation = 0,
        _usingScissor = false,
        _scissorX = 0, _scissorY = 0,
        _scissorWidth = 0, _scissorHeight = 0,
    }, Level)
end

local Stack = {}
Stack.__index = Stack

-- Flattens every level into `self.transform`. Cheap to call: no-op while clean.
function Stack:updateTransform()
    if not self._dirty then return end
    local x, y, sx, sy, rot = 0, 0, 1, 1, 0
    local usingScissor, scX, scY, scW, scH = false, 0, 0, 0, 0
    for i = 1, #self.stack do
        local t = self.stack[i]
        x   = x * t._scaleX + t._offsetX
        y   = y * t._scaleY + t._offsetY
        sx  = sx * t._scaleX
        sy  = sy * t._scaleY
        rot = rot + t._rotation
        if t._usingScissor then
            usingScissor = true
            scX, scY, scW, scH = t._scissorX, t._scissorY, t._scissorWidth, t._scissorHeight
        end
    end
    local tr = self.transform
    tr._offsetX, tr._offsetY = x, y
    tr._scaleX,  tr._scaleY  = sx, sy
    tr._rotation             = rot
    tr._usingScissor         = usingScissor
    tr._scissorX, tr._scissorY, tr._scissorWidth, tr._scissorHeight = scX, scY, scW, scH
    self._dirty = false
end

function Stack:top() return self.stack[#self.stack] end

function Stack:push()
    self.stack[#self.stack + 1] = Level.new()
    self._dirty = true
end

function Stack:pop()
    if #self.stack > 0 then
        self.stack[#self.stack] = nil
        self._dirty = true
    end
end

function Stack:clear()
    self.stack = {}
    self._dirty = true
end

-- Marks the flattened transform stale. Call after mutating a level in place.
function Stack:invalidate() self._dirty = true end

function lv1lua.core.newTransformStack()
    return setmetatable({
        transform = Level.new(),
        stack     = {},
        _dirty    = true,
    }, Stack)
end

lv1lua.core.newTransformLevel = Level.new
