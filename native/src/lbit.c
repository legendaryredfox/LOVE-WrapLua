/* LuaJIT BitOp-compatible `bit` module for Lua 5.1 (Balatro does require "bit"). */
#include "lua.h"
#include "lauxlib.h"
#include <stdint.h>

static int32_t tobit(lua_State *L, int i) {
    /* wrap like LuaJIT: take the number modulo 2^32 */
    double d = luaL_checknumber(L, i);
    double m = d - 4294967296.0 * (double)(long long)(d / 4294967296.0);
    return (int32_t)(uint32_t)(long long)m;
}
#define PUSH(L, v) lua_pushnumber(L, (lua_Number)(int32_t)(v))

static int b_tobit(lua_State *L) { PUSH(L, tobit(L, 1)); return 1; }
static int b_bnot(lua_State *L) { PUSH(L, ~tobit(L, 1)); return 1; }
#define VARIADIC(name, op) \
static int name(lua_State *L) { int n = lua_gettop(L); int32_t r = tobit(L, 1); \
    for (int i = 2; i <= n; i++) r = r op tobit(L, i); PUSH(L, r); return 1; }
VARIADIC(b_band, &)
VARIADIC(b_bor, |)
VARIADIC(b_bxor, ^)
static int b_lshift(lua_State *L) { PUSH(L, (int32_t)((uint32_t)tobit(L,1) << (tobit(L,2) & 31))); return 1; }
static int b_rshift(lua_State *L) { PUSH(L, (int32_t)((uint32_t)tobit(L,1) >> (tobit(L,2) & 31))); return 1; }
static int b_arshift(lua_State *L) { PUSH(L, tobit(L,1) >> (tobit(L,2) & 31)); return 1; }
static int b_rol(lua_State *L) { uint32_t x = (uint32_t)tobit(L,1); int n = tobit(L,2) & 31; PUSH(L, (int32_t)((x << n) | (x >> ((32 - n) & 31)))); return 1; }
static int b_ror(lua_State *L) { uint32_t x = (uint32_t)tobit(L,1); int n = tobit(L,2) & 31; PUSH(L, (int32_t)((x >> n) | (x << ((32 - n) & 31)))); return 1; }
static int b_bswap(lua_State *L) { uint32_t x = (uint32_t)tobit(L,1); PUSH(L, (int32_t)((x>>24)|((x>>8)&0xff00)|((x<<8)&0xff0000)|(x<<24))); return 1; }
static int b_tohex(lua_State *L) {
    uint32_t x = (uint32_t)tobit(L, 1); int n = lua_isnoneornil(L, 2) ? 8 : (int)luaL_checkinteger(L, 2);
    const char *hex = "0123456789abcdef"; char buf[8];
    if (n < 0) { n = -n; hex = "0123456789ABCDEF"; }
    if (n > 8) n = 8;
    for (int i = n - 1; i >= 0; i--) { buf[i] = hex[x & 15]; x >>= 4; }
    lua_pushlstring(L, buf, n); return 1;
}
static const luaL_Reg funcs[] = {
    {"tobit", b_tobit}, {"bnot", b_bnot}, {"band", b_band}, {"bor", b_bor}, {"bxor", b_bxor},
    {"lshift", b_lshift}, {"rshift", b_rshift}, {"arshift", b_arshift},
    {"rol", b_rol}, {"ror", b_ror}, {"bswap", b_bswap}, {"tohex", b_tohex}, {NULL, NULL}
};
int luaopen_bit(lua_State *L) { luaL_register(L, "bit", funcs); return 1; }
