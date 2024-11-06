local greeting =  'Hello WAAAAAAAAAAAARUDOOOOOOOOOOOO!!!!!'
local width = 480
local height = 272
-- global_os = love.system.getOS()

function love.load()
  player = {}
  player.x = width / 2
  player.y = height / 2
  player.speed = 200
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

  love.graphics.printf(greeting, width / 16, 5)
end

function love.draw()
  love.graphics.circle(player.x, player.y, 100)
end
