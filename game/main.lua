local greeting = 'Hello WAAAAAAAAAAAARUDOOOOOOOOOOOO!!!!!'
local width = 480
local height = 272

local anim8 = require 'libraries/anim8'

local player = {}
local sprites = {}
local animations = {}

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest") -- Best filter for pixel art

    sprites.playerSheet = love.graphics.newImage('assets/mystic_woods/sprites/characters/player.png')
    local playerGrid = anim8.newGrid(48, 48, 288, 480)

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

    if not isMoving then
        player.animation = animations.idleDown
    end

    player.x = math.max(0, math.min(player.x, width - 48))
    player.y = math.max(0, math.min(player.y, height - 48))

    player.animation:update(dt)
end

function love.draw()
    player.animation:draw(sprites.playerSheet, player.x, player.y, 0, 1, 1, 24, 24)

    love.graphics.printf(greeting, 0, 5, width, "center")
end
