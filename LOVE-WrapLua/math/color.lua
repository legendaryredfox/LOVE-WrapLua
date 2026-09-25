-- love.math: colour conversion.

function love.math.colorFromBytes(r, g, b, a)
    return r/255, g/255, b/255, (a or 255)/255
end

function love.math.colorToBytes(r, g, b, a)
    return math.floor(r*255+0.5), math.floor(g*255+0.5),
           math.floor(b*255+0.5), math.floor((a or 1)*255+0.5)
end

-- sRGB transfer functions. Both accept a table, a single channel, or r,g,b,a.
function love.math.gammaToLinear(r, g, b, a)
    local function f(v) return v <= 0.04045 and v/12.92 or ((v+0.055)/1.055)^2.4 end
    if type(r) == 'table' then
        return {f(r[1]), f(r[2]), f(r[3]), r[4] or 1}
    end
    if g == nil then return f(r) end
    return f(r), f(g), f(b), a
end

function love.math.linearToGamma(r, g, b, a)
    local function f(v) return v <= 0.0031308 and v*12.92 or 1.055*v^(1/2.4)-0.055 end
    if type(r) == 'table' then
        return {f(r[1]), f(r[2]), f(r[3]), r[4] or 1}
    end
    if g == nil then return f(r) end
    return f(r), f(g), f(b), a
end
