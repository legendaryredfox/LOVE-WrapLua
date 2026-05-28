local defaultfont = { font=font.load("oneFont.pgf"), size=15 }
local scale       = 0.375
local fontscale   = 0.6

font.setdefault(defaultfont.font)
lv1lua.current = {
    font        = defaultfont,
    color       = color.new(255,255,255,255),
    colorRGBA   = {1,1,1,1},
    bgcolor     = color.new(0,0,0,255),
    bgColorRGBA = {0,0,0,1},
    canvas      = nil,
}

local _lineWidth = 1

local function _c255(r,g,b,a)
    return math.floor(r*255+0.5), math.floor(g*255+0.5),
           math.floor(b*255+0.5), math.floor((a or 1)*255+0.5)
end

-- ──────────────────────────────────────────────────────────────
-- Image
-- ──────────────────────────────────────────────────────────────
function love.graphics.newImage(filename, settings)
    local img = image.load(lv1lua.dataloc.."game/"..filename)
    if lv1luaconf.imgscale == true then image.scale(img, scale*100) end
    return img
end

function love.graphics.draw(drawable, x, y, r, sx, sy, ox, oy)
    x, y = (x or 0) - (ox or 0)*(math.abs(sx or 1)),
           (y or 0) - (oy or 0)*(math.abs(sy or 1))
    if sx and not sy then sy = sx end
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x = x * scale; y = y * scale
    end
    if r then image.rotate(drawable, (r/math.pi)*180) end
    if sx then image.resize(drawable, image.getrealw(drawable)*sx, image.getrealh(drawable)*sy) end
    if drawable then image.blit(drawable, x, y, color.a(lv1lua.current.color)) end
end

-- ──────────────────────────────────────────────────────────────
-- Quad
-- ──────────────────────────────────────────────────────────────
function love.graphics.newQuad(x, y, width, height, swOrImg, sh)
    local sw, _sh
    if type(swOrImg) == "table" then
        sw = swOrImg.imageWidth or width; _sh = swOrImg.imageHeight or height
    else
        sw = swOrImg; _sh = sh
    end
    local q = { x=x or 0, y=y or 0, width=width or 0, height=height or 0,
                imageWidth=sw or width, imageHeight=_sh or height }
    function q:getViewport() return self.x,self.y,self.width,self.height end
    function q:setViewport(x,y,w,h,sw,sh)
        self.x,self.y,self.width,self.height=x or self.x,y or self.y,w or self.width,h or self.height
        if sw then self.imageWidth=sw; self.imageHeight=sh end
    end
    function q:getTextureDimensions() return self.imageWidth, self.imageHeight end
    function q:getScale() return self.width/self.imageWidth, self.height/self.imageHeight end
    return q
end

-- ──────────────────────────────────────────────────────────────
-- Color
-- ──────────────────────────────────────────────────────────────
function love.graphics.setColor(r, g, b, a)
    if type(r) == "table" then r,g,b,a = r[1],r[2],r[3],r[4] end
    a = a or 1
    lv1lua.current.colorRGBA = {r, g, b, a}
    local r8,g8,b8,a8 = _c255(r, g, b, a)
    lv1lua.current.color = color.new(r8, g8, b8, a8)
end

function love.graphics.getColor()
    local c = lv1lua.current.colorRGBA; return c[1],c[2],c[3],c[4]
end

function love.graphics.setBackgroundColor(r, g, b, a)
    if type(r) == "table" then r,g,b,a = r[1],r[2],r[3],r[4] end
    a = a or 1
    lv1lua.current.bgColorRGBA = {r,g,b,a}
    local r8,g8,b8,a8 = _c255(r, g, b, a)
    lv1lua.current.bgcolor = color.new(r8, g8, b8, a8)
end

function love.graphics.getBackgroundColor()
    local c = lv1lua.current.bgColorRGBA; return c[1],c[2],c[3],c[4]
end

function love.graphics.clear(r, g, b, a)
    if r == nil then screen.clear(lv1lua.current.bgcolor)
    elseif type(r) == "table" then
        local r8,g8,b8,a8 = _c255(r[1],r[2],r[3],r[4] or 1)
        screen.clear(color.new(r8,g8,b8,a8))
    else
        local r8,g8,b8,a8 = _c255(r,g or 0,b or 0,a or 1)
        screen.clear(color.new(r8,g8,b8,a8))
    end
end

-- ──────────────────────────────────────────────────────────────
-- Font
-- ──────────────────────────────────────────────────────────────
function love.graphics.newFont(setfont, setsize)
    if tonumber(setfont) then setsize = setfont; setfont = nil end
    setsize = setsize or 12
    local fontDef = { font = defaultfont.font, size = setsize }
    function fontDef:getWidth(t)  return screen.textwidth(self.font, t, self.size/18.5) end
    function fontDef:getHeight()  return self.size end
    function fontDef:getBaseline() return self.size end
    function fontDef:getAscent()  return self.size end
    function fontDef:getDescent() return 0 end
    function fontDef:getLineHeight() return 1.2 end
    function fontDef:setLineHeight() end
    return fontDef
end

function love.graphics.setFont(setfont, setsize)
    if not lv1lua.isPSP and setfont then
        lv1lua.current.font = setfont
    else
        lv1lua.current.font = defaultfont
    end
    if setsize then lv1lua.current.font.size = setsize end
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
    if not text or text == "" then return end
    x, y = x or 0, y or 0
    local fontsize = lv1lua.current.font.size / 18.5
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x=x*scale; y=y*scale; fontsize=fontsize*fontscale
    end
    screen.print(lv1lua.current.font.font, x, y, text, fontsize, lv1lua.current.color)
end

local CHAR_WIDTH  = 8
local LINE_HEIGHT = 16

function love.graphics.printf(text, x, y, width, align)
    if not text or text == "" then return end
    align = align or "left"
    width = width or 480
    local lines = {}
    local maxChars = math.floor(width / CHAR_WIDTH)
    local currentLine = ""
    for word in text:gmatch("%S+") do
        if #currentLine + #word + 1 > maxChars then
            table.insert(lines, currentLine); currentLine = word
        else
            currentLine = currentLine == "" and word or (currentLine.." "..word)
        end
    end
    table.insert(lines, currentLine)
    for i, line in ipairs(lines) do
        local offsetX = 0
        if align == "center"     then offsetX = (width - #line*CHAR_WIDTH) / 2
        elseif align == "right"  then offsetX = width - #line*CHAR_WIDTH end
        love.graphics.print(line, x+offsetX, y+(i-1)*LINE_HEIGHT)
    end
end

-- ──────────────────────────────────────────────────────────────
-- Primitives
-- ──────────────────────────────────────────────────────────────
function love.graphics.rectangle(mode, x, y, w, h)
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x=x*scale; y=y*scale; w=w*scale; h=h*scale
    end
    if mode == "fill" then draw.fillrect(x,y,w,h,lv1lua.current.color)
    elseif mode == "line" then draw.rect(x,y,w,h,lv1lua.current.color) end
end

function love.graphics.line(...)
    local c = type(select(1,...))=="table" and select(1,...) or {...}
    for i=1,#c-2,2 do draw.line(c[i],c[i+1],c[i+2],c[i+3],lv1lua.current.color) end
end

function love.graphics.circle(mode, x, y, radius, segments)
    if mode == "fill" then
        draw.circle(x, y, radius, lv1lua.current.color, segments or 32)
    else
        local r, s = radius, segments or 32
        for i=0,s-1 do
            local a1,a2 = i/s*math.pi*2, (i+1)/s*math.pi*2
            draw.line(x+r*math.cos(a1),y+r*math.sin(a1),x+r*math.cos(a2),y+r*math.sin(a2),lv1lua.current.color)
        end
    end
end

function love.graphics.ellipse(mode, x, y, rx, ry, segments)
    ry = ry or rx; segments = segments or 32
    local pts={}
    for i=0,segments do
        local a=i/segments*math.pi*2
        pts[#pts+1]=x+rx*math.cos(a); pts[#pts+1]=y+ry*math.sin(a)
    end
    love.graphics.polygon(mode, pts)
end

function love.graphics.polygon(mode, vertices, ...)
    local v = type(vertices)=="table" and vertices or {vertices,...}
    if #v < 4 then return end
    if mode == "fill" then
        local cx,cy,n = 0,0,#v/2
        for i=1,#v,2 do cx=cx+v[i]; cy=cy+v[i+1] end
        cx,cy=cx/n,cy/n
        for i=1,#v-2,2 do
            draw.line(cx,cy,v[i],v[i+1],lv1lua.current.color)
            draw.line(v[i],v[i+1],v[i+2],v[i+3],lv1lua.current.color)
        end
    else
        for i=1,#v-2,2 do draw.line(v[i],v[i+1],v[i+2],v[i+3],lv1lua.current.color) end
        draw.line(v[#v-1],v[#v],v[1],v[2],lv1lua.current.color)
    end
end

function love.graphics.arc(mode, arctype, x, y, radius, angle1, angle2, segments)
    if type(arctype)=="number" then
        segments=angle2; angle2=angle1; angle1=radius; radius=arctype; y=x; x=mode; arctype="pie"; mode="line"
    end
    segments = segments or 12
    local pts = {}
    if (arctype or "pie")=="pie" then pts[1]=x; pts[2]=y end
    for i=0,segments do
        local a=angle1+(angle2-angle1)*i/segments
        pts[#pts+1]=x+radius*math.cos(a); pts[#pts+1]=y+radius*math.sin(a)
    end
    love.graphics.polygon(mode, pts)
end

function love.graphics.points(...)
    local c = type(select(1,...))=="table" and select(1,...) or {...}
    for i=1,#c-1,2 do draw.fillrect(c[i],c[i+1],1,1,lv1lua.current.color) end
end

-- ──────────────────────────────────────────────────────────────
-- Transform (minimal for PSP)
-- ──────────────────────────────────────────────────────────────
function love.graphics.push()    end
function love.graphics.pop()     end
function love.graphics.translate(x,y) end
function love.graphics.scale(sx,sy)   end
function love.graphics.rotate(a)      end
function love.graphics.origin()       end
function love.graphics.reset()
    love.graphics.setColor(1,1,1,1)
    love.graphics.setBackgroundColor(0,0,0)
end

function love.graphics.setScissor()   end
function love.graphics.getScissor()   return nil end

-- ──────────────────────────────────────────────────────────────
-- Misc stubs
-- ──────────────────────────────────────────────────────────────
function love.graphics.setDefaultFilter(min,mag,anisotropy) end
function love.graphics.getDefaultFilter() return "linear","linear",1 end
function love.graphics.setBlendMode(m)   end
function love.graphics.getBlendMode()    return "alpha","alphamultiply" end
function love.graphics.setLineWidth(w)   _lineWidth = w or 1 end
function love.graphics.getLineWidth()    return _lineWidth end
function love.graphics.setLineStyle()    end
function love.graphics.getLineStyle()    return "smooth" end
function love.graphics.getDimensions()   return lv1lua.screenWidth,lv1lua.screenHeight end
function love.graphics.getWidth()        return lv1lua.screenWidth end
function love.graphics.getHeight()       return lv1lua.screenHeight end
function love.graphics.isActive()        return true end
function love.graphics.present()         end
function love.graphics.captureScreenshot() end
function love.graphics.stencil(fn)  if fn then fn() end end
function love.graphics.setStencilTest() end
function love.graphics.getStencilTest() return "always",0 end
function love.graphics.newCanvas(w,h) return {_width=w or lv1lua.screenWidth,_height=h or lv1lua.screenHeight,
    getWidth=function(s)return s._width end, getHeight=function(s)return s._height end,
    renderTo=function(s,fn) if fn then fn() end end} end
function love.graphics.setCanvas(c) end
function love.graphics.getCanvas()  return nil end
function love.graphics.newShader(c) return {send=function()end,hasUniform=function()return false end} end
function love.graphics.setShader()  end
function love.graphics.getShader()  return nil end
function love.graphics.getFont()    return lv1lua.current.font end
function love.graphics.newSpriteBatch(img,max,usage)
    local sb={_image=img,_sprites={}}
    function sb:add(q,x,y,r,sx,sy,ox,oy)
        if type(q)=="table" and q.getViewport then table.insert(self._sprites,{quad=q,x=x,y=y,r=r,sx=sx,sy=sy,ox=ox,oy=oy})
        else table.insert(self._sprites,{x=q,y=x,r=y,sx=r,sy=sx,ox=sy,oy=ox}) end
        return #self._sprites
    end
    function sb:clear() self._sprites={} end
    function sb:flush() end
    function sb:getCount() return #self._sprites end
    function sb:_draw(bx,by)
        for _,s in ipairs(self._sprites) do
            love.graphics.draw(self._image,(s.x or 0)+(bx or 0),(s.y or 0)+(by or 0),s.r,s.sx,s.sy)
        end
    end
    return sb
end
function love.graphics.newText(fnt, text)
    local t={_font=fnt,_batches={}}
    function t:set(s) self._batches={{text=s,x=0,y=0}} end
    function t:add(s,x,y) table.insert(self._batches,{text=s,x=x or 0,y=y or 0}); return #self._batches end
    function t:clear() self._batches={} end
    function t:getWidth() return 0 end
    function t:getHeight() return 0 end
    function t:_draw(x,y)
        for _,b in ipairs(self._batches) do love.graphics.print(b.text,(x or 0)+b.x,(y or 0)+b.y) end
    end
    if text then t:set(text) end
    return t
end
love.graphics.newTextBatch = love.graphics.newText
function love.graphics.getStats() return {drawcalls=0,texturememory=0} end
function love.graphics.getRendererInfo() return "OneLua PSP","1.0","","" end
