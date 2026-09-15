-- OneLua graphics: Canvas and Shader stubs.
--
-- OneLua exposes no render target and no programmable pipeline, so these keep
-- games from crashing but do not render offscreen. `getSupported().canvas` is
-- false; see Implemented.md.

local Canvas = {}
Canvas.__index = Canvas
function Canvas:getWidth()  return self._width end
function Canvas:getHeight() return self._height end
function Canvas:getDimensions() return self._width, self._height end
function Canvas:getFormat() return "rgba8" end
function Canvas:getMSAA()   return 0 end
function Canvas:getFilter() return "linear","linear",1 end
function Canvas:setFilter() end
function Canvas:getWrap()   return "clamp","clamp" end
function Canvas:setWrap()   end
function Canvas:newImageData() return nil end
-- Draws straight to the screen instead of to the canvas.
function Canvas:renderTo(fn) if fn then fn() end end

function love.graphics.newCanvas(width, height, settings)
    return setmetatable({
        _width  = width  or lv1lua.screenWidth,
        _height = height or lv1lua.screenHeight,
        imgData = nil,
    }, Canvas)
end

function love.graphics.setCanvas(canvas)
    lv1lua.current.canvas = canvas
end

function love.graphics.getCanvas()
    return lv1lua.current.canvas
end

local Shader = {}
Shader.__index = Shader
function Shader:send()        end
function Shader:sendColor()   end
function Shader:hasUniform()  return false end
function Shader:getWarnings() return "" end

function love.graphics.newShader(code, pixelcode)
    return setmetatable({}, Shader)
end

function love.graphics.setShader(shader)
    lv1lua.current.shader = shader
end

function love.graphics.getShader()
    return lv1lua.current.shader
end
