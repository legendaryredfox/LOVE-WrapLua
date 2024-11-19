local greeting = 'Hello WAAAAAAAAAAAARUDOOOOOOOOOOOO!!!!!'
local width = 480
local height = 272


local player = {}
local sprites = {}
local animations = {}
local frames = {}
local currentFrame = 1
local fps = 5                 -- Frames per second for the animation
local timeElapsed = 0
local timePerFrame = 1 / fps  -- Time per frame based on FPS
local desAnim8 = require("libraries/desAnim8")
local animation

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest") -- Best filter for pixel art

    animation = desAnim8.newAnimation("/assets/player_idle", 6, 5)

    player.x = width / 2
    player.y = height / 2
    player.speed = 80
end

function love.update(dt)
    timeElapsed = timeElapsed + dt
    local isMoving = false

    if love.keyboard.isDown("left") then
        player.x = player.x - player.speed * dt
        player.animation = animations.walkSide
        isMoving = true
    elseif love.keyboard.isDown("right") then
        player.x = player.x + player.speed * dt
        player.animation = animations.walkSide
        isMoving = true
    elseif love.keyboard.isDown("up") then
        player.y = player.y - player.speed * dt
        player.animation = animations.walkUp
        isMoving = true
    elseif love.keyboard.isDown("down") then
        player.y = player.y + player.speed * dt
        player.animation = animations.walkDown
        isMoving = true
    end

    if not isMoving then
        --player.animation = animations.idleDown
    end

    player.x = math.max(0, math.min(player.x, width - 48))
    player.y = math.max(0, math.min(player.y, height - 48))

    animation:update(dt)
end

function love.draw()
    local frame = frames[currentFrame]
    love.graphics.printf(greeting, 0, 5, width, "center")
    -- love.graphics.draw(frames[currentFrame], player.x, player.y, nil, nil, nil, 25 / 2, 25/ 2)
    animation:draw(player.x, player.y, nil, nil, nil)
end
