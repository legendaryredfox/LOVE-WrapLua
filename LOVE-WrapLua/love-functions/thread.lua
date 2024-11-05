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

-- Add to love.thread module
function love.thread.newThread(filename)
    local thread = {
        running = false,
        start = function(self)
            self.running = true
            local chunk, err = love.filesystem.load(filename)
            if not chunk then
                error("Failed to load thread file: " .. err)
            end

            coroutine.wrap(function()
                chunk()
                self.running = false
            end)()
        end,
        isRunning = function(self)
            return self.running
        end,
        wait = function(self)
            -- while self.running do
            --     -- Small sleep or coroutine yield could go here if necessary
            -- end
        end
    }
    return thread
end
