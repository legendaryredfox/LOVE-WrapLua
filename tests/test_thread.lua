local T = dofile("tests/runner.lua")
dofile("tests/mock_platform.lua")
-- thread.lua uses require internally; redirect it to avoid path issues, then
-- put the interpreter's own require back. run_all shares one process, and
-- leaving this shim in place broke later tests: on LuaJIT the vendored sha2
-- asks for the built-in "bit", which the shim turned into dofile("bit.lua").
local systemRequire = require
require = function(p) return dofile(p:gsub("%.", "/")..".lua") end
dofile("LOVE-WrapLua/love-functions/thread.lua")
require = systemRequire

-- ── Channel via getChannel ───────────────────────────────────────
T.describe("love.thread.getChannel", function()
    T.it("returns a channel object", function()
        local ch = love.thread.getChannel("events")
        T.istype(ch, "table")
    end)

    T.it("same name returns the same channel", function()
        local a = love.thread.getChannel("shared")
        local b = love.thread.getChannel("shared")
        T.ok(a == b, "same instance expected")
    end)

    T.it("different names return different channels", function()
        local a = love.thread.getChannel("ch_a")
        local b = love.thread.getChannel("ch_b")
        T.ok(a ~= b, "different instances expected")
    end)
end)

-- ── Channel via newChannel ───────────────────────────────────────
T.describe("love.thread.newChannel", function()
    T.it("named newChannel returns/stores channel by name", function()
        local ch = love.thread.newChannel("named_ch")
        T.ok(ch == love.thread.getChannel("named_ch"))
    end)

    T.it("unnamed newChannel returns anonymous channel", function()
        local ch = love.thread.newChannel()
        T.istype(ch, "table")
        T.ok(ch.push, "should have push method")
    end)
end)

-- ── Channel messages ─────────────────────────────────────────────
T.describe("Channel:push/pop/peek", function()
    local ch

    -- fresh channel before each test
    local function fresh() ch = love.thread.newChannel() end

    T.it("push then pop returns the value", function()
        fresh()
        ch:push("hello")
        T.eq(ch:pop(), "hello")
    end)

    T.it("pop on empty channel returns nil", function()
        fresh()
        T.ok(ch:pop() == nil)
    end)

    T.it("FIFO order is preserved", function()
        fresh()
        ch:push(1); ch:push(2); ch:push(3)
        T.eq(ch:pop(), 1)
        T.eq(ch:pop(), 2)
        T.eq(ch:pop(), 3)
    end)

    T.it("peek does not consume the value", function()
        fresh()
        ch:push("peek_me")
        local p = ch:peek()
        T.eq(p, "peek_me")
        T.eq(ch:pop(), "peek_me")  -- still there
    end)

    T.it("hasRead returns true when messages exist", function()
        fresh()
        T.nok(ch:hasRead(), "empty channel should return false")
        ch:push("x")
        T.ok(ch:hasRead(), "non-empty channel should return true")
    end)

    T.it("clear empties the channel", function()
        fresh()
        ch:push(1); ch:push(2)
        ch:clear()
        T.nok(ch:hasRead())
        T.ok(ch:pop() == nil)
    end)
end)

-- ── Channel isolation ────────────────────────────────────────────
T.describe("Channel isolation", function()
    T.it("pushing to one channel does not affect another", function()
        local a = love.thread.newChannel()
        local b = love.thread.newChannel()
        a:push("for_a")
        T.ok(b:pop() == nil, "b should be empty")
        T.eq(a:pop(), "for_a")
    end)
end)

-- ── Thread object ────────────────────────────────────────────────
T.describe("love.thread.newThread", function()
    T.it("returns an object with isRunning method", function()
        local th = love.thread.newThread("nonexistent_file.lua")
        T.istype(th, "table")
        T.ok(th.isRunning, "should have isRunning")
        T.nok(th:isRunning(), "new thread should not be running")
    end)
end)

-- ── Thread registry + blocking channel API (#4) ──────────────────
T.describe("thread registry + channel API", function()
    T.it("getThreads returns a table and never errors", function()
        T.istype(love.thread.getThreads(), "table")
    end)

    T.it("getThread returns nil for an unknown name", function()
        T.ok(love.thread.getThread("no_such_thread") == nil)
    end)

    T.it("newThread registers a retrievable thread", function()
        local th = love.thread.newThread("worker.lua")
        T.ok(love.thread.getThread("worker.lua") == th)
    end)

    T.it("supply/demand/getCount behave", function()
        local ch = love.thread.newChannel()
        ch:supply("a"); ch:supply("b")
        T.eq(ch:getCount(), 2)
        T.eq(ch:demand(), "a")
        T.eq(ch:getCount(), 1)
    end)

    T.it("performAtomic runs a function with the channel", function()
        local ch = love.thread.newChannel()
        local n = ch:performAtomic(function(c) c:push(1); c:push(2); return c:getCount() end)
        T.eq(n, 2)
    end)

    T.it("start forwards args into the thread chunk", function()
        local captured
        love.filesystem.load = function(_) return function(a, b) captured = {a, b} end end
        local th = love.thread.newThread("args.lua")
        th:start(7, 9)
        T.eq(captured[1], 7); T.eq(captured[2], 9)
    end)
end)

io.write("\n=== love.thread ===\n")
return T.summary()
