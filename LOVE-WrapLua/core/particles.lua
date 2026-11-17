-- Shared ParticleSystem.
--
-- Particles are simulated in Lua and drawn as individual sprites through
-- love.graphics.draw, so every backend gets the same object. Size and colour curves (up to 8 stops, linear
-- along the particle's life), size variation, starting rotation and spin are kept per particle; with none
-- of them set a particle is the plain draw it always was.
--
-- Live particles sit in one array that update compacts in place, in order, and a dead particle's table goes
-- to a pool the next emit takes from, so a steady system allocates nothing per frame.

local cos, sin, random, floor = math.cos, math.sin, math.random, math.floor

local MAX_STOPS = 8

-- A curve's value at life fraction t, over `n` stops of `width` numbers each, stored flat in `v`.
local function sample(v, n, width, t, k)
    if n == 1 then return v[k] end
    local pos = t * (n - 1)
    local i = floor(pos)
    if i >= n - 1 then return v[(n - 1) * width + k] end
    local f = pos - i
    local a = v[i * width + k]
    return a + (v[(i + 1) * width + k] - a) * f
end

function love.graphics.newParticleSystem(image, buffer)
    local list, count = {}, 0
    local pool, poolCount = {}, 0
    local ps = {
        _image=image, _buffer=buffer or 1000,
        _emitting=false,
        _rate=1, _lifetime=1, _timer=0,
        _sx=0,_sy=0, _ex=0,_ey=0,
        _minspeed=0,_maxspeed=100,
        _minlife=1, _maxlife=2,
    }
    local function retire(p)
        if poolCount < ps._buffer then
            poolCount = poolCount + 1
            pool[poolCount] = p
        end
    end
    function ps:setEmissionRate(r)    self._rate=r end
    function ps:setParticleLifetime(a,b) self._minlife=a; self._maxlife=b or a end
    function ps:setLinearAcceleration(x1,y1,x2,y2) self._sx=x1;self._sy=y1;self._ex=x2;self._ey=y2 end
    function ps:setSpeed(min,max) self._minspeed=min; self._maxspeed=max or min end
    function ps:setSizeVariation(v)
        if v < 0 or v > 1 then error("The size variation must be between 0 and 1", 2) end
        self._sizeVar = v
    end
    function ps:getSizeVariation()   return self._sizeVar or 0 end
    function ps:setSizes(...)
        local n = select("#", ...)
        if n == 0 or n > MAX_STOPS then error("Between 1 and 8 sizes are allowed", 2) end
        self._sizes = { ... }
        self._sizeCount = n
    end
    function ps:getSizes()
        if not self._sizes then return 1 end
        return (table.unpack or unpack)(self._sizes, 1, self._sizeCount)
    end
    function ps:setColors(...)
        local first = ...
        local flat, n = {}, 0
        if type(first) == "table" then
            n = select("#", ...)
            for i = 1, n do
                local c = select(i, ...)
                flat[#flat + 1] = c[1]; flat[#flat + 1] = c[2]; flat[#flat + 1] = c[3]
                flat[#flat + 1] = c[4] or 1
            end
        else
            local count = select("#", ...)
            if count % 4 ~= 0 then error("Colors need four numbers each", 2) end
            flat = { ... }
            n = count / 4
        end
        if n == 0 or n > MAX_STOPS then error("Between 1 and 8 colors are allowed", 2) end
        self._colors, self._colorCount = flat, n
    end
    function ps:setRotation(min, max)
        self._rotMin, self._rotMax = min, max or min
    end
    function ps:setSpin(min, max)
        self._spinMin, self._spinMax = min, max or min
    end
    function ps:setDirection(d)      self._dir=d end
    function ps:setSpread(s)         self._spread=s end
    function ps:setPosition(x,y)     self._px=x; self._py=y end
    function ps:getPosition()        return self._px or 0, self._py or 0 end
    function ps:start()              self._emitting=true end
    function ps:stop()               self._emitting=false end
    function ps:pause()              self._emitting=false end
    function ps:reset()
        for i = 1, count do retire(list[i]); list[i] = nil end
        count = 0
    end
    function ps:isActive()           return self._emitting end
    function ps:isPaused()           return not self._emitting end
    function ps:isStopped()          return not self._emitting end
    function ps:getCount()           return count end
    function ps:emit(n)
        local spread = self._spread or 0
        for i=1,n do
            local angle = (self._dir or 0) + random() * spread - spread/2
            local speed = self._minspeed + random()*(self._maxspeed-self._minspeed)
            local p
            if poolCount > 0 then
                p = pool[poolCount]; pool[poolCount] = nil; poolCount = poolCount - 1
            else
                p = {}
            end
            p.x, p.y = self._px or 0, self._py or 0
            p.vx, p.vy = cos(angle)*speed, sin(angle)*speed
            p.life = self._minlife + random()*(self._maxlife-self._minlife)
            p.age = 0
            local rmin = self._rotMin
            if rmin then p.rot = rmin + random() * (self._rotMax - rmin) else p.rot = 0 end
            local smin = self._spinMin
            if smin then p.spin = smin + random() * (self._spinMax - smin) else p.spin = 0 end
            local var = self._sizeVar
            p.sizeScale = var and (1 - var * random()) or 1
            count = count + 1
            list[count] = p
        end
    end
    function ps:update(dt)
        if self._emitting then
            self._timer = (self._timer or 0) + dt
            local n = floor(self._timer * self._rate)
            if n > 0 then self:emit(n); self._timer = self._timer - n/self._rate end
        end
        local kept = 0
        for i = 1, count do
            local p = list[i]
            p.age = p.age + dt
            if p.age < p.life then
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                p.rot = p.rot + p.spin * dt
                kept = kept + 1
                list[kept] = p
            else
                retire(p)
            end
        end
        for i = kept + 1, count do list[i] = nil end
        count = kept
    end
    local function replay()
        local draw = love.graphics.draw
        local sizes, colors = ps._sizes, ps._colors
        local shaped = sizes or colors or ps._sizeVar or ps._rotMin or ps._spinMin
        if not shaped then
            for i = 1, count do
                local p = list[i]
                draw(image, p.x, p.y)
            end
            return
        end
        local w, h = image:getWidth() / 2, image:getHeight() / 2
        local sn, cn = ps._sizeCount, ps._colorCount
        local setColor = love.graphics.setColor
        local br, bg, bb, ba
        if colors then br, bg, bb, ba = love.graphics.getColor() end
        for i = 1, count do
            local p = list[i]
            local t = p.age / p.life
            local size = p.sizeScale
            if sizes then size = size * sample(sizes, sn, 1, t, 1) end
            if colors then
                setColor(br * sample(colors, cn, 4, t, 1), bg * sample(colors, cn, 4, t, 2),
                         bb * sample(colors, cn, 4, t, 3), ba * sample(colors, cn, 4, t, 4))
            end
            draw(image, p.x, p.y, p.rot, size, size, w, h)
        end
        if colors then setColor(br, bg, bb, ba) end
    end
    function ps:_draw(x, y, r, sx, sy, ox, oy)
        lv1lua.core.withDrawTransform(x, y, r, sx, sy, ox, oy, replay)
    end
    function ps:clone()
        return love.graphics.newParticleSystem(image, self._buffer)
    end
    return lv1lua.util.registerDrawObject(ps)
end
