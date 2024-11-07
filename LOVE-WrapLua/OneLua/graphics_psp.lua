
local defaultfont
local scale = 0.375
local fontscale = 0.6

defaultfont = {font=font.load("oneFont.pgf"),size=15}
font.setdefault(defaultfont.font)

lv1lua.current = {font=defaultfont,color=color.new(255,255,255,255)}

function love.graphics.newImage(filename)
    img = image.load(lv1lua.dataloc.."game/"..filename)

    --scale 1280x720 to 480x270(psp)
    if lv1luaconf.imgscale == true then
        image.scale(img,scale*100)
    end

    return img
end

function love.graphics.draw(drawable, x, y, r, sx, sy)

    x = x or 0
    y = y or 0


    if sx and not sy then sy = sx end


    if lv1luaconf.imgscale or lv1luaconf.resscale then
        x = x * scale
        y = y * scale
    end


    if r then
        local degrees = (r / math.pi) * 180
        image.rotate(drawable, degrees)
    end


    if sx and sy then
        local width = image.getrealw(drawable) * sx
        local height = image.getrealh(drawable) * sy
        image.resize(drawable, width, height)
    end


    if drawable then
        local color_alpha = color.a(lv1lua.current.color) or 255
        image.blit(drawable, x, y, color_alpha)
    end
end


function love.graphics.newFont(setfont, setsize)
    if tonumber(setfont) then
        setsize = setfont
    elseif not setsize then
        setsize = 12
    end

    if tonumber(setfont) or lv1lua.isPSP then
        setfont = defaultfont.font
    elseif setfont then
        setfont = font.load(lv1lua.dataloc.."game/"..setfont)
    end

    local table = {
        font = setfont;
        size = setsize;
    }
    return table
end

function love.graphics.setFont(setfont,setsize)
    if not lv1lua.isPSP and setfont then
        lv1lua.current.font = setfont
    else
        lv1lua.current.font = defaultfont
    end

    if setsize then
        lv1lua.current.font.size = setsize
    end
end

function love.graphics.print(text,x,y)
    local fontsize = lv1lua.current.font.size/18.5
    if not x then x = 0 end
    if not y then y = 0 end


    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x = x * scale; y = y * scale
        fontsize = fontsize*fontscale
    end

    if text then
        screen.print(lv1lua.current.font.font,x,y,text,fontsize,lv1lua.current.color)
    end
end

local CHAR_WIDTH = 8
local LINE_HEIGHT = 16

function love.graphics.printf(text, x, y, width, align)
    align = align or "left"
    width = width or 480

    local lines = {}
    local function wrapText(text, maxChars)
        local currentLine = ""
        for word in text:gmatch("%S+") do
            if #currentLine + #word + 1 > maxChars then
                table.insert(lines, currentLine)
                currentLine = word
            else
                currentLine = currentLine == "" and word or (currentLine .. " " .. word)
            end
        end
        table.insert(lines, currentLine)
    end
    wrapText(text, math.floor(width / CHAR_WIDTH))
    for i, line in ipairs(lines) do
        local offsetX = 0
        if align == "center" then
            offsetX = (width - #line * CHAR_WIDTH) / 2
        elseif align == "right" then
            offsetX = width - #line * CHAR_WIDTH
        end

        love.graphics.print(line, x + offsetX, y + (i - 1) * LINE_HEIGHT)
    end
end

function love.graphics.setColor(r,g,b,a)
    if not a then a = 255 end
    lv1lua.current.color = color.new(r,g,b,a)
end

function love.graphics.setBackgroundColor(r,g,b)
    screen.clear(color.new(r,g,b))
end

function love.graphics.rectangle(mode, x, y, w, h)
    --scale 1280x720 to 480x270(psp)
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x = x * scale; y = y * scale; w = w * scale; h = h * scale
    end

    if mode == "fill" then
        draw.fillrect(x, y, w, h, lv1lua.current.color)
    elseif mode == "line" then
        draw.rect(x, y, w, h, lv1lua.current.color)
    end
end

function love.graphics.line(x1,y1,x2,y2)
    draw.line(x1,y1,x2,y2,lv1lua.current.color)
end

function love.graphics.circle(x,y,radius)
    draw.circle(x,y,radius,lv1lua.current.color,30)
end


function love.graphics.setDefaultFilter(min, mag, anisotropy)
    --Point/Nearest
    --Apoint (Not supported from love)
    --Linear
    --Alinear (Not supported from love)
    if(min == "linear") then
        min = __IMG_FILTER_LINEAR
    elseif(min == "nearest" or min == "point") then
        min = __IMG_FILTER_POINT
    end
    if(mag == "linear") then
        mag = __IMG_FILTER_LINEAR
    elseif(mag == "nearest" or mag == "point") then
        mag = __IMG_FILTER_POINT
    end
    defaultMinificationFilter = min
    defaultMagnificationFilter = mag
    anisotropy = (anisotropy == nil) and 0 or 1
end

function love.graphics.getDefaultFilter()
    return defaultMinificationFilter, defaultMagnificationFilter, anisotropy
end

function love.graphics.newQuad(x, y, width, height, imageWidth, imageHeight)
    local quad = {
        x = x or 0,
        y = y or 0,
        width = width or 0,
        height = height or 0,
        imageWidth = imageWidth or width,
        imageHeight = imageHeight or height
    }

    function quad:getViewport()
        return self.x, self.y, self.width, self.height
    end

    function quad:setViewport(x, y, width, height)
        self.x = x or self.x
        self.y = y or self.y
        self.width = width or self.width
        self.height = height or self.height
    end

    return quad
end
