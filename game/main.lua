local greeting = 'Hello WAAAAAAAAAAAARUDOOOOOOOOOOOO!!!!!'
local width = 480
local height = 272

-- Library for animations
local anim8 = require 'libraries/anim8'

-- Define player, sprites, and animations
local player = {}
local sprites = {}
local animations = {}

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest") -- Best filter for pixel art

    -- Load player sprite sheet
    sprites.playerSheet = love.graphics.newImage('assets/mystic_woods/sprites/characters/player.png')
    local playerGrid = anim8.newGrid(48, 48, 288, 480)

    -- Define animations for different player states
    animations.idleDown = anim8.newAnimation(playerGrid('1-6', 1), 0.15)
    animations.idleSide = anim8.newAnimation(playerGrid('1-6', 2), 0.15)
    animations.idleUp = anim8.newAnimation(playerGrid('1-6', 3), 0.15)
    animations.walkDown = anim8.newAnimation(playerGrid('1-6', 4), 0.15)
    animations.walkSide = anim8.newAnimation(playerGrid('1-6', 5), 0.15)
    animations.walkUp = anim8.newAnimation(playerGrid('1-6', 6), 0.15)
    animations.attackDown = anim8.newAnimation(playerGrid('1-4', 7), 0.15)
    animations.attackSide = anim8.newAnimation(playerGrid('1-4', 8), 0.15)
    animations.attackUp = anim8.newAnimation(playerGrid('1-4', 9), 0.15)
    animations.death = anim8.newAnimation(playerGrid('1-3', 10), 0.15)

    -- Initialize player position and settings
    player.x = width / 2
    player.y = height / 2
    player.speed = 200
    player.animation = animations.idleDown
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

    -- Default to idle animation if not moving
    if not isMoving then
        player.animation = animations.idleDown
    end

    -- Keep player within screen boundaries
    player.x = math.max(0, math.min(player.x, width - 48))
    player.y = math.max(0, math.min(player.y, height - 48))

    -- Update the current animation
    player.animation:update(dt)
end

function love.draw()
    -- Draw the player with animation centered at player.x, player.y
    player.animation:draw(sprites.playerSheet, player.x, player.y, 0, 1, 1, 24, 24)
    --  player.animation:draw(sprites.playerSheet, px - 24, py - 38, 0, player.direction, 1, player.customOffset, 0)

    -- Draw greeting message at the top center
    love.graphics.printf(greeting, 0, 5, width, "center")
end
