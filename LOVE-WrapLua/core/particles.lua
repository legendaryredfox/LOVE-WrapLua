-- Shared ParticleSystem.
--
-- Particles are simulated in Lua and drawn as individual sprites through
-- love.graphics.draw, so every backend gets the same object: no size, colour
-- or rotation curves (those setters are accepted and ignored).
--
-- Live particles sit in one array that update compacts in place, in order, and a dead particle's table goes
-- to a pool the next emit takes from, so a steady system allocates nothing per frame.

local cos, sin, random, floor = math.cos, math.sin, math.random, math.floor

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
    function ps:setSizeVariation(v)  end
    function ps:setSizes(...)        end
    function ps:setColors(...)       end
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
        for i = 1, count do
            local p = list[i]
            draw(image, p.x, p.y)
        end
    end
    function ps:_draw(x, y, r, sx, sy, ox, oy)
        lv1lua.core.withDrawTransform(x, y, r, sx, sy, ox, oy, replay)
    end
    function ps:clone()
        return love.graphics.newParticleSystem(image, self._buffer)
    end
    return lv1lua.util.registerDrawObject(ps)
end
