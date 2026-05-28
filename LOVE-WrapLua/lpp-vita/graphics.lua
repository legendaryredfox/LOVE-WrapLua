local defaultfont = Font.load(lv1lua.dataloc.."LOVE-WrapLua/Vera.ttf")
Font.setPixelSizes(defaultfont, 12)
local _lineWidth = 1

local function _c255(r,g,b,a)
    return math.floor(r*255+0.5), math.floor(g*255+0.5),
           math.floor(b*255+0.5), math.floor((a or 1)*255+0.5)
end

lv1lua.current = {
    font        = defaultfont,
    color       = Color.new(255,255,255,255),
    colorRGBA   = {1,1,1,1},
    bgcolor     = Color.new(0,0,0,255),
    bgColorRGBA = {0,0,0,1},
    canvas      = nil,
}

-- ──────────────────────────────────────────────────────────────
-- Image
-- ──────────────────────────────────────────────────────────────
function love.graphics.newImage(filename, settings)
    return Graphics.loadImage(lv1lua.dataloc.."game/"..filename)
end

function love.graphics.draw(drawable, x, y, r, sx, sy, ox, oy)
    x,y = (x or 0)-(ox or 0)*math.abs(sx or 1),
          (y or 0)-(oy or 0)*math.abs(sy or 1)
    r  = r  or 0
    sx = sx or 1; sy = sy or sx
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x=x*0.75; y=y*0.75
    end
    if lv1luaconf.imgscale == true then sx=sx*0.75; sy=sy*0.75 end
    if drawable then
        Graphics.drawScaleImage(x, y, drawable, sx, sy, lv1lua.current.color)
    end
end

-- ──────────────────────────────────────────────────────────────
-- Color
-- ──────────────────────────────────────────────────────────────
function love.graphics.setColor(r, g, b, a)
    if type(r)=="table" then r,g,b,a=r[1],r[2],r[3],r[4] end
    a = a or 1
    lv1lua.current.colorRGBA = {r,g,b,a}
    local r8,g8,b8,a8 = _c255(r,g,b,a)
    lv1lua.current.color = Color.new(r8,g8,b8,a8)
end

function love.graphics.getColor()
    local c = lv1lua.current.colorRGBA; return c[1],c[2],c[3],c[4]
end

function love.graphics.setBackgroundColor(r, g, b, a)
    if type(r)=="table" then r,g,b,a=r[1],r[2],r[3],r[4] end
    a = a or 1
    lv1lua.current.bgColorRGBA = {r,g,b,a}
    local r8,g8,b8,a8 = _c255(r,g,b,a)
    lv1lua.current.bgcolor = Color.new(r8,g8,b8,a8)
end

function love.graphics.getBackgroundColor()
    local c = lv1lua.current.bgColorRGBA; return c[1],c[2],c[3],c[4]
end

function love.graphics.clear(r, g, b, a)
    -- lpp-vita screen clear handled by lv1lua.draw; this is a no-op placeholder
end

-- ──────────────────────────────────────────────────────────────
-- Font
-- ──────────────────────────────────────────────────────────────
function love.graphics.newFont(setfont, setsize)
    if tonumber(setfont) then setsize=setfont; setfont=nil end
    setsize = setsize or 12
    local fobj
    if setfont then
        fobj = Font.load(lv1lua.dataloc.."game/"..setfont)
    else
        fobj = defaultfont
    end
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        setsize = setsize * 0.825
    end
    Font.setPixelSizes(fobj, setsize)
    local wrap = { _font=fobj, size=setsize }
    function wrap:getWidth(text)
        -- lpp-vita doesn't expose text width easily; approximate
        return #text * self.size * 0.6
    end
    function wrap:getHeight()  return self.size end
    function wrap:getBaseline() return self.size end
    function wrap:getAscent()  return self.size end
    function wrap:getDescent() return 0 end
    function wrap:getLineHeight() return 1.2 end
    function wrap:setLineHeight() end
    return wrap
end

function love.graphics.setFont(setfont, setsize)
    if setfont then
        lv1lua.current.font = setfont
        if setfont._font then Font.setPixelSizes(setfont._font, setfont.size) end
    end
    if setsize and lv1lua.current.font then lv1lua.current.font.size = setsize end
end

function love.graphics.getFont() return lv1lua.current.font end

function love.graphics.setNewFont(setfont, setsize)
    local newfont = love.graphics.newFont(setfont, setsize)
    love.graphics.setFont(newfont, setsize)
    return newfont
end

-- ──────────────────────────────────────────────────────────────
-- Print
-- ──────────────────────────────────────────────────────────────
function love.graphics.print(text, x, y)
    if not text or text=="" then return end
    x, y = x or 0, y or 0
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then x=x*0.75; y=y*0.75 end
    local fobj = type(lv1lua.current.font)=="table" and lv1lua.current.font._font or lv1lua.current.font
    Font.print(fobj, x, y, text, lv1lua.current.color)
end

function love.graphics.printf(text, x, y, wrapWidth, align)
    if not text or text=="" then return end
    align = align or "left"; wrapWidth = wrapWidth or lv1lua.screenWidth
    local fobj = type(lv1lua.current.font)=="table" and lv1lua.current.font._font or lv1lua.current.font
    local lineH = (type(lv1lua.current.font)=="table" and lv1lua.current.font.size or 12)
    local lines = {}
    local cur = ""
    for word in text:gmatch("%S+") do
        local test = cur=="" and word or cur.." "..word
        local tw = #test * lineH * 0.6
        if tw > wrapWidth and cur~="" then
            table.insert(lines, cur); cur = word
        else cur = test end
    end
    table.insert(lines, cur)
    for i, line in ipairs(lines) do
        local ox = 0
        local lw = #line * lineH * 0.6
        if align=="center" then ox=(wrapWidth-lw)/2
        elseif align=="right" then ox=wrapWidth-lw end
        love.graphics.print(line, x+ox, y+(i-1)*lineH*1.2)
    end
end

-- ──────────────────────────────────────────────────────────────
-- Primitives
-- ──────────────────────────────────────────────────────────────
function love.graphics.rectangle(mode, x, y, w, h)
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then x=x*0.75;y=y*0.75;w=w*0.75;h=h*0.75 end
    if mode=="fill" then Graphics.fillRect(x,x+w,y,y+h,lv1lua.current.color)
    elseif mode=="line" then Graphics.fillEmptyRect(x,x+w,y,y+h,lv1lua.current.color) end
end

function love.graphics.line(...)
    local c = type(select(1,...))=="table" and select(1,...) or {...}
    for i=1,#c-2,2 do Graphics.drawLine(c[i],c[i+1],c[i+2],c[i+3],lv1lua.current.color) end
end

function love.graphics.circle(mode, x, y, radius, segments)
    if mode=="fill" then Graphics.fillCircle(x,y,radius,lv1lua.current.color)
    else
        local r,s = radius, segments or 32
        for i=0,s-1 do
            local a1,a2=i/s*math.pi*2,(i+1)/s*math.pi*2
            Graphics.drawLine(x+r*math.cos(a1),y+r*math.sin(a1),x+r*math.cos(a2),y+r*math.sin(a2),lv1lua.current.color)
        end
    end
end

function love.graphics.ellipse(mode, x, y, rx, ry, segments)
    ry=ry or rx; segments=segments or 32
    local pts={}
    for i=0,segments do local a=i/segments*math.pi*2; pts[#pts+1]=x+rx*math.cos(a); pts[#pts+1]=y+ry*math.sin(a) end
    love.graphics.polygon(mode, pts)
end

function love.graphics.polygon(mode, vertices, ...)
    local v = type(vertices)=="table" and vertices or {vertices,...}
    if #v<4 then return end
    if mode=="fill" then
        local cx,cy,n=0,0,#v/2
        for i=1,#v,2 do cx=cx+v[i]; cy=cy+v[i+1] end
        cx,cy=cx/n,cy/n
        for i=1,#v-2,2 do
            Graphics.drawLine(cx,cy,v[i],v[i+1],lv1lua.current.color)
            Graphics.drawLine(v[i],v[i+1],v[i+2],v[i+3],lv1lua.current.color)
        end
    else
        for i=1,#v-2,2 do Graphics.drawLine(v[i],v[i+1],v[i+2],v[i+3],lv1lua.current.color) end
        Graphics.drawLine(v[#v-1],v[#v],v[1],v[2],lv1lua.current.color)
    end
end

function love.graphics.arc(mode, arctype, x, y, radius, angle1, angle2, segments)
    if type(arctype)=="number" then
        segments=angle2;angle2=angle1;angle1=radius;radius=arctype;y=x;x=mode;arctype="pie";mode="line"
    end
    segments=segments or 12
    local pts={}
    if (arctype or "pie")=="pie" then pts[1]=x; pts[2]=y end
    for i=0,segments do local a=angle1+(angle2-angle1)*i/segments; pts[#pts+1]=x+radius*math.cos(a); pts[#pts+1]=y+radius*math.sin(a) end
    love.graphics.polygon(mode, pts)
end

function love.graphics.points(...)
    local c=type(select(1,...))=="table" and select(1,...) or {...}
    for i=1,#c-1,2 do Graphics.fillRect(c[i],c[i]+1,c[i+1],c[i+1]+1,lv1lua.current.color) end
end

-- ──────────────────────────────────────────────────────────────
-- Transform (minimal stubs for lpp-vita)
-- ──────────────────────────────────────────────────────────────
function love.graphics.push()     end
function love.graphics.pop()      end
function love.graphics.translate() end
function love.graphics.scale()    end
function love.graphics.rotate()   end
function love.graphics.origin()   end
function love.graphics.reset()    love.graphics.setColor(1,1,1,1); love.graphics.setBackgroundColor(0,0,0) end
function love.graphics.setScissor() end
function love.graphics.getScissor() return nil end

-- ──────────────────────────────────────────────────────────────
-- Stubs
-- ──────────────────────────────────────────────────────────────
function love.graphics.setDefaultFilter()   end
function love.graphics.getDefaultFilter()   return "linear","linear",1 end
function love.graphics.setBlendMode()       end
function love.graphics.getBlendMode()       return "alpha","alphamultiply" end
function love.graphics.setLineWidth(w)      _lineWidth=w or 1 end
function love.graphics.getLineWidth()       return _lineWidth end
function love.graphics.setLineStyle()       end; function love.graphics.getLineStyle() return "smooth" end
function love.graphics.getDimensions()      return lv1lua.screenWidth,lv1lua.screenHeight end
function love.graphics.getWidth()           return lv1lua.screenWidth end
function love.graphics.getHeight()          return lv1lua.screenHeight end
function love.graphics.isActive()           return true end
function love.graphics.present()            end
function love.graphics.captureScreenshot()  end
function love.graphics.stencil(fn)          if fn then fn() end end
function love.graphics.setStencilTest()     end; function love.graphics.getStencilTest() return "always",0 end
function love.graphics.newCanvas(w,h)
    return {_width=w or lv1lua.screenWidth,_height=h or lv1lua.screenHeight,
        getWidth=function(s)return s._width end,getHeight=function(s)return s._height end,
        renderTo=function(s,fn)if fn then fn() end end}
end
function love.graphics.setCanvas(c) end; function love.graphics.getCanvas() return nil end
function love.graphics.newShader(c)  return {send=function()end,hasUniform=function()return false end} end
function love.graphics.setShader()   end; function love.graphics.getShader() return nil end
function love.graphics.newQuad(x,y,w,h,swOrImg,sh)
    local sw,_sh
    if type(swOrImg)=="table" then sw=swOrImg:getDimensions and swOrImg:getDimensions() or w; _sh=sh
    else sw=swOrImg or w; _sh=sh or h end
    local q={x=x,y=y,width=w,height=h,sw=sw,sh=_sh}
    function q:getViewport() return self.x,self.y,self.width,self.height end
    function q:setViewport(x,y,w,h) self.x,self.y,self.width,self.height=x,y,w,h end
    function q:getTextureDimensions() return self.sw,self.sh end
    return q
end
function love.graphics.newSpriteBatch(img,max,usage)
    local sb={_image=img,_sprites={}}
    function sb:add(q,x,y,r,sx,sy,ox,oy)
        if type(q)=="table" and q.getViewport then table.insert(self._sprites,{quad=q,x=x,y=y,r=r,sx=sx,sy=sy,ox=ox,oy=oy})
        else table.insert(self._sprites,{x=q,y=x,r=y,sx=r,sy=sx}) end
        return #self._sprites
    end
    function sb:clear() self._sprites={} end; function sb:flush() end
    function sb:getCount() return #self._sprites end
    function sb:_draw(bx,by)
        for _,s in ipairs(self._sprites) do love.graphics.draw(self._image,(s.x or 0)+(bx or 0),(s.y or 0)+(by or 0),s.r,s.sx,s.sy) end
    end
    return sb
end
function love.graphics.newText(fnt,text)
    local t={_font=fnt,_batches={}}
    function t:set(s) self._batches={{text=s,x=0,y=0}} end
    function t:add(s,x,y) table.insert(self._batches,{text=s,x=x or 0,y=y or 0}); return #self._batches end
    function t:clear() self._batches={} end
    function t:getWidth() return 0 end; function t:getHeight() return 0 end
    function t:_draw(x,y) for _,b in ipairs(self._batches) do love.graphics.print(b.text,(x or 0)+b.x,(y or 0)+b.y) end end
    if text then t:set(text) end; return t
end
love.graphics.newTextBatch = love.graphics.newText
function love.graphics.getStats() return {drawcalls=0,texturememory=0} end
function love.graphics.getRendererInfo() return "lpp-vita","1.0","","" end
