local greeting =  'Hello WAAAAAAAAAAAARUDOOOOOOOOOOOO!!!!!'
local width = 480
local height = 272
-- global_os = love.system.getOS()

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest") -- best filter for pixel art
  player = {}
  player.x = width / 2
  player.y = height / 2
  player.speed = 200
  player.sprite = love.graphics.newImage('assets/PNG/Default/Characters/red_character.png')
end

function love.update(dt)
  if love.keyboard.isDown("left") then
    player.x = player.x - player.speed * dt
  end
  if love.keyboard.isDown("right") then
    player.x = player.x + player.speed * dt
  end
  if love.keyboard.isDown("up") then
    player.y = player.y - player.speed * dt
  end
  if love.keyboard.isDown("down") then
    player.y = player.y + player.speed * dt
  end

  player.x = math.max(0, math.min(player.x, width))
  player.y = math.max(0, math.min(player.y, height))
end

function love.draw()
  love.graphics.draw(player.sprite, player.x, player.y)
  love.graphics.printf(greeting, width / 16, 5)
end
