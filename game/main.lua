local greeting = 'Hello WAAAAAAAAAAAARUDOOOOOOOOOOOO!!!!!'
local width = 480
local height = 272

local desAnim8 = require 'libraries/desAnim8'

local player = {}
local sprites = {}
local animations = {}

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest") -- Best filter for pixel art

    player.animation = desAnim8.new("assets/player_idle.png", 25, 25, 6, 0.15)

    player.x = width / 2
    player.y = height / 2
    player.speed = 200
end

function love.update(dt)
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

    player.animation:update(dt)
end

function love.draw()
    love.graphics.printf(greeting, 0, 5, width, "center")
    player.animation:draw(player.x, player.y)
end
