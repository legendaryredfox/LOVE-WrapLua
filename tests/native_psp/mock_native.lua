-- Mock of the C module `native` (native/src/engine.c): records calls, real files via the shell.
local M = { calls = {} }
local function rec(name, ...) M.calls[#M.calls + 1] = { name, ... }; return nil end
local function sh(cmd) local p = io.popen(cmd); local s = p:read("*a"); p:close(); return s end
function M.count(name) local n = 0; for _, c in ipairs(M.calls) do if c[1] == name then n = n + 1 end end return n end
function M.last(name) for i = #M.calls, 1, -1 do if M.calls[i][1] == name then return M.calls[i] end end end
function M.reset() M.calls = {} end
-- A real matrix stack (the C engine's 2x3 affine: x' = a*x + c*y + e, y' = b*x + d*y + f), so the Lua wrappers
-- that read it back are tested against geometry and not against recorded calls.
local m, stk = { 1, 0, 0, 1, 0, 0 }, {}
function M.push() stk[#stk + 1] = { unpack(m) } end
function M.pop() if #stk > 0 then m = table.remove(stk) end end
function M.origin() m = { 1, 0, 0, 1, 0, 0 } end
function M.reset_stack() stk = {}; M.origin() end
function M.translate(x, y) m[5] = m[5] + m[1] * x + m[3] * y; m[6] = m[6] + m[2] * x + m[4] * y end
function M.scale(sx, sy) sy = sy or sx; m[1] = m[1] * sx; m[2] = m[2] * sx; m[3] = m[3] * sy; m[4] = m[4] * sy end
function M.rotate(r)
    local c, s = math.cos(r), math.sin(r)
    local a, b, cc, d = m[1], m[2], m[3], m[4]
    m[1], m[2], m[3], m[4] = a * c + cc * s, b * c + d * s, -a * s + cc * c, -b * s + d * c
end
function M.shear(kx, ky)
    kx, ky = kx or 0, ky or 0
    local a, b, c, d = m[1], m[2], m[3], m[4]
    m[1], m[2], m[3], m[4] = a + c * ky, b + d * ky, a * kx + c, b * kx + d
end
for _, n in ipairs({ "push", "pop", "origin", "reset_stack", "translate", "scale", "rotate", "shear" }) do
    local real = M[n]
    M[n] = function(...) rec(n, ...); return real(...) end
end
function M.get_matrix() return unpack(m) end
function M.set_matrix(a, b, c, d, e, f) m = { a, b, c, d, e, f } end
function M.mul_matrix(a, b, c, d, e, f)
    local A, B, C, D = m[1], m[2], m[3], m[4]
    local E, F = m[1] * e + m[3] * f + m[5], m[2] * e + m[4] * f + m[6]
    m = { A * a + C * b, B * a + D * b, A * c + C * d, B * c + D * d, E, F }
end
for _, n in ipairs({ "tex_filter", "draw", "fill_poly", "fill_rect", "line", "prep_draw", "begin_frame", "clear", "end_frame", "scissor", "blend", "font_draw", "cpu", "exit", "tex_mem", "palette", "canvas_set", "suppress" }) do
    M[n] = function(...) return rec(n, ...) end
end
local cr, cg, cb, ca = 1, 1, 1, 1
function M.set_color(a, b, c, d)
    if type(a) == "table" then a, b, c, d = a[1], a[2], a[3], a[4] end
    cr, cg, cb, ca = a, b, c, d or 1
    return rec("set_color", cr, cg, cb, ca)
end
function M.get_color() return cr, cg, cb, ca end
local B = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function M.b64encode(d)
    local out = {}
    for i = 1, #d, 3 do
        local a, b, c = d:byte(i, i + 2)
        local v = a * 65536 + (b or 0) * 256 + (c or 0)
        local q = { math.floor(v / 262144) % 64, math.floor(v / 4096) % 64, math.floor(v / 64) % 64, v % 64 }
        out[#out + 1] = B:sub(q[1] + 1, q[1] + 1) .. B:sub(q[2] + 1, q[2] + 1) .. (b and B:sub(q[3] + 1, q[3] + 1) or "=") .. (c and B:sub(q[4] + 1, q[4] + 1) or "=")
    end
    return table.concat(out)
end
function M.b64decode(d)
    local out, acc, bits = {}, 0, 0
    for ch in d:gmatch("[%w%+/]") do
        acc = acc * 64 + (B:find(ch, 1, true) - 1); bits = bits + 6
        if bits >= 8 then bits = bits - 8; out[#out + 1] = string.char(math.floor(acc / 2 ^ bits)); acc = acc % 2 ^ bits end
    end
    return table.concat(out)
end
local ncanvas = 0
function M.reset_pool() ncanvas = 0 end
function M.canvas_new(w, h)
    rec("canvas_new", w, h)
    if w > 512 or h > 512 or ncanvas >= 2 then return nil, "out of VRAM" end   -- like the 2 x 512x240 VRAM pool
    ncanvas = ncanvas + 1; return { canvas = true }
end
function M.image_load(p) rec("image_load", p); return { tex = p }, 32, 16 end
function M.font_load(p, size) rec("font_load", p, size); return { font = p }, size * 0.8, -size * 0.2, size end
function M.font_width(f, s) return #s * 6 end
function M.font_has(f, s) return true end
M.now = 0
function M.time() M.now = M.now + 1 / 60; return M.now end
function M.sleep() end
function M.pad() return M.mask or 0, 0, 0 end
function M.mem() return 1e7, 1e7 end
function M.stat(p)
    local out = sh("stat -c '%F %s %Y' '" .. p .. "' 2>/dev/null")
    local kind, size, mt = out:match("^(%S+)[^%d]*(%d+) (%d+)")
    if not kind then return nil end
    return out:find("^directory") and "directory" or "file", tonumber(size), tonumber(mt)
end
function M.listdir(p)
    if not M.stat(p) then return nil end
    local t = {}
    for n in sh("ls -A '" .. p .. "'"):gmatch("[^\n]+") do t[#t + 1] = n end
    return t
end
function M.mkdir(p) return os.execute("mkdir '" .. p .. "' 2>/dev/null") == 0 end
function M.remove(p) return os.execute("rm -r '" .. p .. "' 2>/dev/null") == 0 end
function M.inflate(d) return d end
function M.deflate(d) return d end
return M
