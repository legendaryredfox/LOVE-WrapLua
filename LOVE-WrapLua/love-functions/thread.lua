love.thread = {}
local channels = {}

local function createChannel()
    local channel = {
        messages = {},
    }

    function channel:push(msg)
        table.insert(self.messages, msg)
    end

    function channel:pop()
        return table.remove(self.messages, 1)
    end

    function channel:peek()
        return self.messages[1]
    end

    function channel:clear()
        self.messages = {}
    end

    function channel:hasRead()
        return #self.messages > 0
    end

    return channel
end

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

function love.thread.getThreads()
    return threads
end

function love.thread.newChannel(name)
    if name then
        if not channels[name] then
            channels[name] = createChannel()
        end
        return channels[name]
    else
        return createChannel()
    end
end

function love.thread.getThread(name)
    return threads[name]
end
