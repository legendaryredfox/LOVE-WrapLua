-- Returns a fresh runner table each time it is dofile'd.
local T = { _pass = 0, _fail = 0, _suite = "?" }

function T.describe(name, fn) T._suite = name; fn() end

function T.it(desc, fn)
    local ok, err = pcall(fn)
    if ok then
        T._pass = T._pass + 1
        io.write(string.format("  PASS  %s: %s\n", T._suite, desc))
    else
        T._fail = T._fail + 1
        io.write(string.format("  FAIL  %s: %s\n        %s\n", T._suite, desc, tostring(err)))
    end
end

-- Equality assertion (errors with level 2 so the caller line is reported)
function T.eq(got, want)
    if got ~= want then
        error(string.format("want %s, got %s", tostring(want), tostring(got)), 2)
    end
end

-- Approximate equality for floating point
function T.near(got, want, tol)
    tol = tol or 1e-6
    if math.abs(got - want) > tol then
        error(string.format("want ~%g (±%g), got %g", want, tol, got), 2)
    end
end

-- Truthy / falsy
function T.ok(v, msg)
    if not v then error(msg or ("expected truthy, got " .. tostring(v)), 2) end
end
function T.nok(v, msg)
    if v then error(msg or ("expected falsy, got " .. tostring(v)), 2) end
end

-- Type check
function T.istype(v, want)
    if type(v) ~= want then
        error(string.format("want type %s, got %s", want, type(v)), 2)
    end
end

-- Range check [lo, hi]
function T.inrange(v, lo, hi)
    if v < lo or v > hi then
        error(string.format("want value in [%g, %g], got %g", lo, hi, v), 2)
    end
end

function T.summary()
    io.write(string.format("  ─── %d passed, %d failed ───\n\n", T._pass, T._fail))
    return T._fail
end

return T
