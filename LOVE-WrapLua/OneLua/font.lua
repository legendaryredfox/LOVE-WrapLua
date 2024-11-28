local font = {}
font.__index = font

function love.font.newFontData(rasterizer)
  local self = setmetatable({}, font)
  self.fontData = rasterizer()
  return self
end

function font:getWidth()
  return self.fontData.width
end

function font:getHeight()
  return self.fontData.height
end

function font:getData()
  return self.fontData.data
end

function font:clone()
  local newFontData = {}
  for k, v in pairs(self.fontData) do
    if type(v) == "table" then
      newFontData[k] = {}
      for k2, v2 in pairs(v) do
        newFontData[k][k2] = v2
      end
    else
      newFontData[k] = v
    end
  end
  local newFont = setmetatable({}, font)
  newFont.fontData = newFontData
  return newFont
end

function font:getFFIPointer()
  return {
    data = self.fontData.data,
    get = function(self, index)
      return self.data[index]
    end,
    set = function(self, index, value)
      self.data[index] = value
    end
  }
end

return font