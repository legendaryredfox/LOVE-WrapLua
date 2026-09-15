love.thread = {}
local channels = {}
-- Registry of spawned threads, keyed by filename. Kept module-local so
-- getThreads()/getThread() never touch an undefined global (#4).
local threads = {}

local unpack = table.unpack or unpack

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

    function channel:getCount()
        return #self.messages
    end

    -- supply/demand are the blocking variants in desktop LÖVE. This wrapper is
    -- single-threaded (threads run synchronously as coroutines), so they cannot
    -- block: supply is an immediate push, demand is a non-blocking pop that
    -- returns nil when the channel is empty. See Implemented.md.
    function channel:supply(msg)
        table.insert(self.messages, msg)
        return true
    end

    function channel:demand()
        return table.remove(self.messages, 1)
    end

    function channel:performAtomic(fn, ...)
        return fn(self, ...)
    end

    return channel
end

function love.thread.getChannel(name)
    if not channels[name] then
        channels[name] = createChannel()
    end
    return channels[name]
end

function love.thread.newThread(filename)
    local thread = {
        running = false,
        start = function(self, ...)
            self.running = true
            local args = { ... }
            local nargs = select("#", ...)
            local chunk, err = love.filesystem.load(filename)
            if not chunk then
                error("Failed to load thread file: " .. tostring(err))
            end

            coroutine.wrap(function()
                chunk(unpack(args, 1, nargs))
                self.running = false
            end)()
        end,
        isRunning = function(self)
            return self.running
        end,
        wait = function(self)
            -- Threads run synchronously, so nothing to wait on.
        end,
        getError = function(self)
            return nil
        end,
    }
    threads[filename] = thread
    return thread
end

function love.thread.getThreads()
    return threads
end

function love.thread.getThread(name)
    return threads[name]
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
