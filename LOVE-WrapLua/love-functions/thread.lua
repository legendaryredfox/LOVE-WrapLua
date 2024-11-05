-- Initialize the thread module
love.thread = {}
local channels = {}

function love.thread.getChannel(name)
    if channels[name] then
        return channels[name]
    end
        local channel = {
        messages = {},
        push = function(self, msg)
            table.insert(self.messages, msg)
        end,
        pop = function(self)
            return table.remove(self.messages, 1)
        end,
        clear = function(self)
            self.messages = {}
        end,
        hasRead = function(self)
            return #self.messages > 0
        end
    }
    channels[name] = channel
    return channel
end

function love.thread.newThread(func)
  local thread = {
      running = false,
      func = func,
      start = function(self)
          self.running = true
          coroutine.wrap(function()
              self.func()
              self.running = false
          end)()
      end,
      isRunning = function(self)
          return self.running
      end,
      wait = function(self)
          -- while self.running do
          --     -- Yield or delay here if needed
          -- end
      end
  }
  return thread
end
