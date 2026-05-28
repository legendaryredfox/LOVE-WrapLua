InitGFX(720, 480)
InitFont("/dev_flash/data/font/SCE-PS3-RD-R-LATIN.TTF", 12)
local _scale     = 0.5625
local _yOffset   = 37
local _lineWidth = 1

local function _c255(r,g,b,a)
    return math.floor(r*255+0.5), math.floor(g*255+0.5),
           math.floor(b*255+0.5), math.floor((a or 1)*255+0.5)
end

lv1lua.current = {
    font        = nil,
    color       = nil,
    colorRGBA   = {1,1,1,1},
    bgcolor     = nil,
    bgColorRGBA = {0,0,0,1},
    canvas      = nil,
}

-- ──────────────────────────────────────────────────────────────
-- Image
-- ──────────────────────────────────────────────────────────────
function love.graphics.newImage(filename, settings)
    local img = surface()
    img:LoadIMG(lv1lua.dataloc.."game/"..filename)
    return img
end

function love.graphics.draw(drawable, x, y, r, sx, sy, ox, oy)
    x,y = (x or 0)-(ox or 0)*math.abs(sx or 1),
          (y or 0)-(oy or 0)*math.abs(sy or 1)
    x = x * _scale; y = y * _scale + _yOffset
    if drawable then
        drawable:setRectPos(x, y)
        BlitToScreen(drawable)
    end
end

-- ──────────────────────────────────────────────────────────────
-- Color
-- ──────────────────────────────────────────────────────────────
function love.graphics.setColor(r, g, b, a)
    if type(r)=="table" then r,g,b,a=r[1],r[2],r[3],r[4] end
    lv1lua.current.colorRGBA = {r, g or 0, b or 0, a or 1}
end

function love.graphics.getColor()
    local c = lv1lua.current.colorRGBA; return c[1],c[2],c[3],c[4]
end

function love.graphics.setBackgroundColor(r, g, b, a)
    if type(r)=="table" then r,g,b,a=r[1],r[2],r[3],r[4] end
    lv1lua.current.bgColorRGBA = {r, g or 0, b or 0, a or 1}
end

function love.graphics.getBackgroundColor()
    local c = lv1lua.current.bgColorRGBA; return c[1],c[2],c[3],c[4]
end

function love.graphics.clear(r, g, b, a)
    -- PS3 clear handled in lv1lua.draw; stub here
end

-- ──────────────────────────────────────────────────────────────
-- Font / Print
-- ──────────────────────────────────────────────────────────────
function love.graphics.newFont(setfont, setsize)
    if tonumber(setfont) then setsize=setfont; setfont=nil end
    setsize = setsize or 12
    local wrap = { _font=nil, size=setsize }
    function wrap:getWidth(t) return #t * self.size * 0.6 end
    function wrap:getHeight() return self.size end
    function wrap:getBaseline() return self.size end
    function wrap:getAscent() return self.size end
    function wrap:getDescent() return 0 end
    function wrap:getLineHeight() return 1.2 end
    function wrap:setLineHeight() end
    return wrap
end

function love.graphics.setFont(setfont, setsize) end
function love.graphics.getFont()    return lv1lua.current.font end
function love.graphics.setNewFont(setfont, setsize)
    local newfont = love.graphics.newFont(setfont, setsize)
    love.graphics.setFont(newfont, setsize)
    return newfont
end

function love.graphics.print(text, x, y)
    if not text or text=="" then return end
    x = (x or 0) * _scale; y = (y or 0) * _scale + _yOffset
    DrawText(x, y, text)
end

function love.graphics.printf(text, x, y, wrapWidth, align)
    if not text or text=="" then return end
    align = align or "left"; wrapWidth = wrapWidth or lv1lua.screenWidth
    local lineH = 14
    local maxCh = math.floor(wrapWidth / 8)
    local lines = {}; local cur = ""
    for word in text:gmatch("%S+") do
        local test = cur=="" and word or cur.." "..word
        if #test > maxCh and cur~="" then table.insert(lines,cur); cur=word
        else cur=test end
    end
    table.insert(lines, cur)
    for i, line in ipairs(lines) do
        local ox = 0
        if align=="center" then ox=(wrapWidth-#line*8)/2 elseif align=="right" then ox=wrapWidth-#line*8 end
        love.graphics.print(line, x+ox, y+(i-1)*lineH)
    end
end

-- ──────────────────────────────────────────────────────────────
-- Primitives (stubs — PS3 graphics bindings vary by homebrew SDK)
-- ──────────────────────────────────────────────────────────────
function love.graphics.rectangle(mode, x, y, w, h)
    x=x*_scale; y=y*_scale+_yOffset; w=w*_scale; h=h*_scale
    -- Graphics.fillRect / fillEmptyRect not available in all PS3 Lua players
end

function love.graphics.line(...)   end
function love.graphics.circle(mode,x,y,radius,segments) end
function love.graphics.ellipse(mode,x,y,rx,ry,segments) end
function love.graphics.polygon(mode,vertices,...)        end
function love.graphics.arc(mode,arctype,x,y,radius,a1,a2,segs) end
function love.graphics.points(...)                       end

-- ──────────────────────────────────────────────────────────────
-- Transform stubs
-- ──────────────────────────────────────────────────────────────
function love.graphics.push()      end
function love.graphics.pop()       end
function love.graphics.translate() end
function love.graphics.scale()     end
function love.graphics.rotate()    end
function love.graphics.origin()    end
function love.graphics.reset()     love.graphics.setColor(1,1,1,1); love.graphics.setBackgroundColor(0,0,0) end
function love.graphics.setScissor() end
function love.graphics.getScissor() return nil end

-- ──────────────────────────────────────────────────────────────
-- Misc stubs
-- ──────────────────────────────────────────────────────────────
function love.graphics.setDefaultFilter()   end
function love.graphics.getDefaultFilter()   return "linear","linear",1 end
function love.graphics.setBlendMode()       end
function love.graphics.getBlendMode()       return "alpha","alphamultiply" end
function love.graphics.setLineWidth(w)      _lineWidth=w or 1 end
function love.graphics.getLineWidth()       return _lineWidth end
function love.graphics.setLineStyle()       end; function love.graphics.getLineStyle() return "smooth" end
function love.graphics.setLineJoin()        end; function love.graphics.getLineJoin()  return "miter" end
function love.graphics.setPointSize()       end; function love.graphics.getPointSize() return 1 end
function love.graphics.getDimensions()      return lv1lua.screenWidth,lv1lua.screenHeight end
function love.graphics.getWidth()           return lv1lua.screenWidth end
function love.graphics.getHeight()          return lv1lua.screenHeight end
function love.graphics.isActive()           return true end
function love.graphics.present()            end
function love.graphics.captureScreenshot()  end
function love.graphics.stencil(fn)          if fn then fn() end end
function love.graphics.setStencilTest()     end; function love.graphics.getStencilTest() return "always",0 end
function love.graphics.newCanvas(w,h)
    return {_w=w,_h=h, getWidth=function(s)return s._w end, getHeight=function(s)return s._h end,
        renderTo=function(s,fn)if fn then fn() end end}
end
function love.graphics.setCanvas(c) end; function love.graphics.getCanvas() return nil end
function love.graphics.newShader()   return {send=function()end,hasUniform=function()return false end} end
function love.graphics.setShader()   end; function love.graphics.getShader() return nil end
function love.graphics.newQuad(x,y,w,h,sw,sh)
    local q={x=x,y=y,width=w,height=h,sw=sw or w,sh=sh or h}
    function q:getViewport() return self.x,self.y,self.width,self.height end
    function q:setViewport(x,y,w,h) self.x,self.y,self.width,self.height=x,y,w,h end
    function q:getTextureDimensions() return self.sw,self.sh end
    return q
end
function love.graphics.newSpriteBatch(img,max,usage)
    local sb={_image=img,_sprites={}}
    function sb:add(q,x,y,r,sx,sy,ox,oy)
        if type(q)=="table" and q.getViewport then table.insert(self._sprites,{quad=q,x=x,y=y})
        else table.insert(self._sprites,{x=q,y=x}) end
        return #self._sprites
    end
    function sb:clear() self._sprites={} end; function sb:flush() end
    function sb:getCount() return #self._sprites end
    function sb:_draw(bx,by)
        for _,s in ipairs(self._sprites) do love.graphics.draw(self._image,(s.x or 0)+(bx or 0),(s.y or 0)+(by or 0)) end
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
function love.graphics.getRendererInfo() return "PS3 Lua","1.0","","" end
