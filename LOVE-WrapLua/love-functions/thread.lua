love.thread = {}
local channels = {}
-- Registry of spawned threads, keyed by filename. Kept module-local so
-- getThreads()/getThread() never touch an undefined global.
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

-- LOVE takes a file name or the thread's Lua source. A string with a newline
-- is source; otherwise it is a file when it ends in ".lua" or names one.
local function compile(code)
    local isFile = not code:find("\n", 1, true)
        and (code:find("%.lua$") or (love.filesystem.getInfo and love.filesystem.getInfo(code)))
    if isFile then return love.filesystem.load(code) end
    return (loadstring or load)(code, "=thread")
end

-- Threads run synchronously on a coroutine. An error in the body is caught
-- like LOVE catches it: getError returns it and love.threaderror is called,
-- instead of the error unwinding through the caller of start().
function love.thread.newThread(filename)
    local thread = {
        running = false,
        _error  = nil,
        start = function(self, ...)
            self.running = true
            self._error  = nil
            local args = { ... }
            local nargs = select("#", ...)
            local chunk, err = compile(filename)
            if not chunk then
                self.running = false
                self._error = "Failed to load thread: " .. tostring(err)
            else
                local co = coroutine.create(function()
                    chunk(unpack(args, 1, nargs))
                end)
                local ok, res = coroutine.resume(co)
                if not ok then self._error = tostring(res) end
                if coroutine.status(co) == "dead" then self.running = false end
            end
            if self._error and love.threaderror then
                love.threaderror(self, self._error)
            end
        end,
        isRunning = function(self)
            return self.running
        end,
        wait = function(self)
            -- Threads run synchronously, so nothing to wait on.
        end,
        getError = function(self)
            return self._error
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
