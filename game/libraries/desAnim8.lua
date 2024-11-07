local desAnim8 = {}

local function loadFramePaths(folderPath, frameCount)
    local framePaths = {}
    for i = 0, frameCount - 1 do
        local framePath = string.format("%s_frame_%02d.png", folderPath, i)
        table.insert(framePaths, framePath)
    end
    return framePaths
end

function desAnim8.newAnimation(folderPath, frameCount, fps)
    local animation = {}
    animation.frames = {}
    animation.currentFrame = 1
    animation.timeElapsed = 0
    animation.timePerFrame = 1 / fps

    local framePaths = loadFramePaths(folderPath, frameCount)
    for _, path in ipairs(framePaths) do
        table.insert(animation.frames, love.graphics.newImage(path))
    end

    function animation:update(dt)
        self.timeElapsed = self.timeElapsed + dt

        if self.timeElapsed >= self.timePerFrame then
            self.timeElapsed = self.timeElapsed - self.timePerFrame
            self.currentFrame = (self.currentFrame % #self.frames) + 1
        end
    end

    function animation:draw(x, y, r, sx, sy)--, ox, oy)
        local frame = self.frames[self.currentFrame]
        love.graphics.draw(frame, x, y, r or nil, sx or nil, sy or nil, 25 / 2, 25 / 2)
    end

    return animation
end

return desAnim8
