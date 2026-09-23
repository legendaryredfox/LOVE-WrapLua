-- OneLua graphics: ParticleSystem.
--
-- Particles are simulated in Lua and drawn as individual sprites: no size,
-- colour or rotation curves (those setters are accepted and ignored).

function love.graphics.newParticleSystem(image, buffer)
    local ps = {
        _image=image, _buffer=buffer or 1000,
        _particles={}, _emitting=false,
        _rate=1, _lifetime=1, _timer=0,
        _sx=0,_sy=0, _ex=0,_ey=0,
        _minspeed=0,_maxspeed=100,
        _minlife=1, _maxlife=2,
    }
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
    function ps:reset()              self._particles={} end
    function ps:isActive()           return self._emitting end
    function ps:isPaused()           return not self._emitting end
    function ps:isStopped()          return not self._emitting end
    function ps:getCount()           return #self._particles end
    function ps:emit(n)
        for i=1,n do
            local angle = (self._dir or 0) + math.random() * (self._spread or 0) - (self._spread or 0)/2
            local speed = self._minspeed + math.random()*(self._maxspeed-self._minspeed)
            table.insert(self._particles, {
                x=self._px or 0, y=self._py or 0,
                vx=math.cos(angle)*speed, vy=math.sin(angle)*speed,
                life=self._minlife + math.random()*(self._maxlife-self._minlife),
                age=0,
            })
        end
    end
    function ps:update(dt)
        if self._emitting then
            self._timer = (self._timer or 0) + dt
            local count = math.floor(self._timer * self._rate)
            if count > 0 then self:emit(count); self._timer = self._timer - count/self._rate end
        end
        local alive = {}
        for _, p in ipairs(self._particles) do
            p.age = p.age + dt
            if p.age < p.life then
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                alive[#alive+1] = p
            end
        end
        self._particles = alive
    end
    function ps:_draw(x,y)
        for _, p in ipairs(self._particles) do
            love.graphics.draw(self._image, p.x+(x or 0), p.y+(y or 0))
        end
    end
    function ps:clone()
        return love.graphics.newParticleSystem(self._image, self._buffer)
    end
    return lv1lua.util.registerDrawObject(ps)
end
