local desAnim8 = {
    _VERSION     = 'desAnim8 v0.0.1',
    _DESCRIPTION = 'An animation library for LÖVE in the PSP platform',
    _URL         = 'https://github.com/legendaryredfox/desAnim8',
    _THANKS      = [[
        All thanks, recognition and incentives should go to https://github.com/kikito
    ]],
    _LICENSE     = [[
      MIT LICENSE
  
      Copyright (c) 2024
  
      Permission is hereby granted, free of charge, to any person obtaining a
      copy of this software and associated documentation files (the
      "Software"), to deal in the Software without restriction, including
      without limitation the rights to use, copy, modify, merge, publish,
      distribute, sublicense, and/or sell copies of the Software, and to
      permit persons to whom the Software is furnished to do so, subject to
      the following conditions:
  
      The above copyright notice and this permission notice shall be included
      in all copies or substantial portions of the Software.
  
      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
      OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
      MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
      IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
      CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
      TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
      SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    ]]
}
desAnim8.__index = desAnim8

function desAnim8.new(image, frameWidth, frameHeight, numFrames, frameDuration, imageWidth, imageHeight)
    local self = setmetatable({}, desAnim8)
    self.image = image
    self.frameWidth = frameWidth
    self.frameHeight = frameHeight
    self.numFrames = numFrames
    self.frameDuration = frameDuration
    self.quads = {}
    self.currentFrame = 1
    self.timeElapsed = 0

    for i = 0, numFrames - 1 do
        table.insert(self.quads, love.graphics.newQuad(i * frameWidth, 0, frameWidth, frameHeight, imageWidth, imageHeight))
    end

    return self
end

function desAnim8:update(dt)
    self.timeElapsed = self.timeElapsed + dt
    if self.timeElapsed >= self.frameDuration then
        self.timeElapsed = self.timeElapsed - self.frameDuration
        self.currentFrame = self.currentFrame % self.numFrames + 1
    end
end

function desAnim8:draw(x, y)
    local quad = self.quads[self.currentFrame]
    local quadX, quadY, quadWidth, quadHeight = quad:getViewport()
    image.blit(self.image, x, y, quadX, quadY, quadWidth, quadHeight)
end

return desAnim8