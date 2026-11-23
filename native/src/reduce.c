/* A C version of the round-robin update gate Balatro's psp/opt.lua wraps around an object type's update().
 *
 * native.rr_make(class, rate, minAge) replaces class.update with a C closure and returns the per-frame cycle function.
 * The gate runs once per call, for every object of the type, and nearly always returns without updating: in Lua that
 * is a function call plus a dozen table accesses; here the object's fields are read with luaH_getstr on pre-interned
 * keys (this file includes Lua's internal headers and is tied to the Lua 5.1.5 in third_party/).
 *
 * Behaviour is the Lua wrapper's: an object younger than minAge seconds (G.TIMERS.REAL based) always updates; else
 * it updates once per `rate` calls, at most count / rate objects per frame, with the dt since its last real update.
 * Where the Lua wrapper would raise (a field of the wrong type, G.TIMERS.REAL missing) the original update runs
 * unchanged instead. */
#define LUA_CORE
#include "lua.h"
#include "lauxlib.h"
#include "lobject.h"
#include "lstate.h"
#include "ltable.h"
#include "lstring.h"

enum { R_G, R_TIMERS, R_REAL, R_ct, R_id, R_c, R_s, R_COUNT };
static const char *const names[R_COUNT] = { "G", "TIMERS", "REAL", "_r_ct", "_r_id", "_r_c", "_r_s" };
static TString *R[R_COUNT];
static int keys_ready = 0;

typedef struct {
    lua_Number id, updated, count, limit, rate, age;
    int has_age;
} RState;

#define FALSY(v) (ttisnil(v) || (ttisboolean(v) && bvalue(v) == 0))

static void init_keys(lua_State *L) {
    if (keys_ready) return;
    lua_newtable(L);
    for (int i = 0; i < R_COUNT; i++) {
        lua_pushstring(L, names[i]);
        R[i] = rawtsvalue(L->top - 1);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, LUA_REGISTRYINDEX, "rr.keys");
    keys_ready = 1;
}

static void put_num(lua_State *L, Table *o, int k, lua_Number n) {
    setnvalue(luaH_setstr(L, o, R[k]), n);
    o->flags = 0;
}

static int get_now(lua_State *L, lua_Number *out) {
    const TValue *g = luaH_getstr(hvalue(gt(L)), R[R_G]);
    if (!ttistable(g)) return 0;
    const TValue *t = luaH_getstr(hvalue(g), R[R_TIMERS]);
    if (!ttistable(t)) return 0;
    const TValue *v = luaH_getstr(hvalue(t), R[R_REAL]);
    if (!ttisnumber(v)) return 0;
    *out = nvalue(v);
    return 1;
}

static int rr_update(lua_State *L) {
    int n = lua_gettop(L);
    RState *st = (RState *)lua_touserdata(L, lua_upvalueindex(2));
    if (n < 1 || !ttistable(L->base)) goto pass;
    Table *o = hvalue(L->base);
    lua_Number now = 0;
    if (st->has_age) {
        if (!get_now(L, &now)) goto pass;
        const TValue *ct = luaH_getstr(o, R[R_ct]);
        if (FALSY(ct)) { put_num(L, o, R_ct, now + st->age); goto pass; }
        if (!ttisnumber(ct)) goto pass;
        if (nvalue(ct) > now) goto pass;
    }
    st->count += 1;
    const TValue *rid = luaH_getstr(o, R[R_id]);
    if ((ttisnumber(rid) && nvalue(rid) == st->id) || st->updated >= st->limit) return 0;
    const TValue *cv = luaH_getstr(o, R[R_c]);
    lua_Number c;
    if (FALSY(cv)) c = 1;
    else if (ttisnumber(cv)) c = nvalue(cv) + 1;
    else goto pass;
    put_num(L, o, R_c, c);
    if (c < st->rate) return 0;
    put_num(L, o, R_id, st->id);
    put_num(L, o, R_c, 0);
    if (!st->has_age && !get_now(L, &now)) goto pass;
    const TValue *sv = luaH_getstr(o, R[R_s]);
    int replace = 0;
    lua_Number dt = 0;
    if (!FALSY(sv)) {
        if (!ttisnumber(sv)) goto pass;
        dt = now - nvalue(sv);
        replace = 1;
    }
    put_num(L, o, R_s, now);
    st->updated += 1;
    if (replace) {
        if (n < 2) lua_settop(L, 2);
        lua_pushnumber(L, dt);
        lua_replace(L, 2);
        n = lua_gettop(L);
    }
pass:
    lua_pushvalue(L, lua_upvalueindex(1));
    lua_insert(L, 1);
    lua_call(L, n, LUA_MULTRET);
    return lua_gettop(L);
}

static int rr_cycle(lua_State *L) {
    RState *st = (RState *)lua_touserdata(L, lua_upvalueindex(1));
    if (st->updated < st->limit) st->id += 1;
    st->limit = st->count / st->rate;
    st->updated = 0;
    st->count = 0;
    return 0;
}

static int l_rr_make(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_Number rate = luaL_checknumber(L, 2);
    init_keys(L);
    lua_getfield(L, 1, "update");
    luaL_checktype(L, -1, LUA_TFUNCTION);
    RState *st = (RState *)lua_newuserdata(L, sizeof(RState));
    st->id = st->updated = st->count = st->limit = 0;
    st->rate = rate;
    st->has_age = lua_isnumber(L, 3);
    st->age = st->has_age ? lua_tonumber(L, 3) : 0;
    lua_pushvalue(L, -2);
    lua_pushvalue(L, -2);
    lua_pushcclosure(L, rr_update, 2);
    lua_setfield(L, 1, "update");
    lua_pushcclosure(L, rr_cycle, 1);
    return 1;
}

int rr_open(lua_State *L) {
    lua_pushcfunction(L, l_rr_make); lua_setfield(L, -2, "rr_make");
    return 0;
}
