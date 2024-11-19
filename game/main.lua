local desAnim8 = require 'libraries.desAnim8'

local screenWidth = 480
local screenHeight = 272
local frameDuration = 0.15 -- Duration of each frame in seconds
local numFrames = 6 -- Number of frames in the animation
local imageWidth = 288 -- Width of the entire sprite sheet
local imageHeight = 48 -- Height of the entire sprite sheet

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