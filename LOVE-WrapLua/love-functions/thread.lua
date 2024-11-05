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
