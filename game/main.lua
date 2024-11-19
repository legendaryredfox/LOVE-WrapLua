local desAnim8 = require 'libraries.desAnim8'

local screenWidth = 480
local screenHeight = 272
local frameDuration = 0.15
local numFrames = 6
local imageWidth = 288
local imageHeight = 48

function love.load()
    local sprite = love.graphics.newImage('assets/mystic_woods/sprites/characters/player.png')
    player = {}
    player.animations = {}
    player.animations['idle'] = desAnim8.new(sprite, 48, 48, numFrames, frameDuration, imageWidth, imageHeight)
    player.x = screenWidth / 2
    player.y = screenHeight / 2
end

function love.update(dt)
    player.animations['idle']:update(dt)
end

function love.draw()
    player.animations['idle']:draw(player.x, player.y)
end