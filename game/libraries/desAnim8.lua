-- Animation.lua

local desAnim8 = {}
desAnim8.__index = desAnim8

function desAnim8.new(imagePath, frameWidth, frameHeight, totalFrames, animationSpeed)
    local self = setmetatable({}, desAnim8)
    self.image = love.graphics.newImage(imagePath)
    self.frameWidth = frameWidth
    self.frameHeight = frameHeight
    self.totalFrames = totalFrames
    self.animationSpeed = animationSpeed
    self.currentFrame = 1
    self.timer = 0
    self.quads = {}
    self.flipX = 1 -- 1 for normal, -1 for flipped horizontally
    self.flipY = 1 -- 1 for normal, -1 for flipped vertically

    -- Create quads for each frame
    for i = 0, totalFrames - 1 do
        self.quads[i + 1] = love.graphics.newQuad(
            i * frameWidth, 0, frameWidth, frameHeight,
            self.image:getDimensions()
        )
    end

    return self
end

function desAnim8:update(dt)
    -- Update animation timer
    self.timer = self.timer + dt
    if self.timer >= self.animationSpeed then
        self.currentFrame = self.currentFrame % self.totalFrames + 1 -- Loop frames
        self.timer = 0 -- Reset timer
    end
end

function desAnim8:draw(x, y)
    -- Draw the current frame with flipping
    love.graphics.draw(self.image, self.quads[self.currentFrame], x, y, 0, self.flipX, self.flipY, self.frameWidth / 2, self.frameHeight / 2)
end

-- Method to set the flip state
function desAnim8:setFlip(flipX, flipY)
    self.flipX = flipX and -1 or 1  -- Flip horizontally if true
    self.flipY = flipY and -1 or 1  -- Flip vertically if true
end

return desAnim8
