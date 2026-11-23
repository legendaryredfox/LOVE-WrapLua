/* A C fast path for Balatro's Moveable:move (engine/moveable.lua), reading and writing the object's Lua tables directly.
 *
 * Why direct access: through the public Lua API a C function reading the same fields is no faster than the Lua VM
 * (about 720 ns against 735 ns for the idle check on desktop); with luaH_getstr on pre-interned keys it takes 82 ns.
 * This file therefore includes Lua's internal headers and is tied to the Lua 5.1.5 in third_party/.
 *
 * Contract: native.mv_move(self, dt) returns true when it did the whole move, false (and changed nothing) when the object
 * is in a state the fast path does not cover; the caller then runs the Lua implementation. Covered: the frame guard, the
 * paused game, Glued roles, Minor roles (the major's move and move_with_major stay in Lua and are called back) and a
 * Major that has nothing to simulate. Anything else, including a missing field or a field of the wrong type, is a bail.
 *
 * native.mv_method(self, dt) is the same thing installed as Moveable.move: it runs the Lua implementation itself on a bail.
 *
 * native.mv_setup{ move_with_major = f, lr_clamp = f, fallback = f } interns the keys and registers the Lua functions
 * called back (fallback is only needed by mv_method). */
#define LUA_CORE
#include "lua.h"
#include "lauxlib.h"
#include "lobject.h"
#include "lstate.h"
#include "ltable.h"
#include "lstring.h"
#include "lgc.h"

enum {
    K_G, K_FRAMES, K_MOVE, K_SETTINGS, K_paused, K_ROOM, K_T, K_VT, K_w, K_x, K_y, K_r, K_scale, K_h,
    K_FRAME, K_OLD_MAJOR, K_MAJOR, K_created_on_pause, K_alignment, K_prev_offset, K_offset, K_prev_type, K_type, K_lr_clamp,
    K_CALCING, K_role, K_role_type, K_major, K_STATIONARY, K_NEW_ALIGNMENT, K_config, K_refresh_movement, K_juice, K_zoom,
    K_xy_bond, K_r_bond, K_velocity, K_pinch, K_shadow_parrallax,
    K_Glued, K_Minor, K_Major, K_Weak,
    K_COUNT
};
static const char *const key_names[K_COUNT] = {
    "G", "FRAMES", "MOVE", "SETTINGS", "paused", "ROOM", "T", "VT", "w", "x", "y", "r", "scale", "h",
    "FRAME", "OLD_MAJOR", "MAJOR", "created_on_pause", "alignment", "prev_offset", "offset", "prev_type", "type", "lr_clamp",
    "CALCING", "role", "role_type", "major", "STATIONARY", "NEW_ALIGNMENT", "config", "refresh_movement", "juice", "zoom",
    "xy_bond", "r_bond", "velocity", "pinch", "shadow_parrallax",
    "Glued", "Minor", "Major", "Weak",
};
static TString *K[K_COUNT];
static int keys_ready = 0;
static int ref_with_major = LUA_NOREF, ref_lr_clamp = LUA_NOREF, ref_fallback = LUA_NOREF;

#define GS(h, k) luaH_getstr((h), K[k])
#define IS_NUM(v) ttisnumber(v)
#define IS_TBL(v) ttistable(v)
#define FALSY(v) (ttisnil(v) || (ttisboolean(v) && bvalue(v) == 0))
#define IS_STR(v, k) (ttisstring(v) && rawtsvalue(v) == K[k])
#define NUM(h, k) nvalue(GS((h), (k)))
#define HALF(x) luai_numdiv((x), cast_num(2))

static void put(lua_State *L, Table *h, int k, const TValue *v) {
    TValue val = *v;   /* luaH_setstr may rehash the table v points into */
    setobj2t(L, luaH_setstr(L, h, K[k]), &val);
    h->flags = 0;
    luaC_barriert(L, h, &val);
}
static void put_num(lua_State *L, Table *h, int k, lua_Number n) {
    setnvalue(luaH_setstr(L, h, K[k]), n);
    h->flags = 0;
}
static void put_bool(lua_State *L, Table *h, int k, int b) {
    setbvalue(luaH_setstr(L, h, K[k]), b);
    h->flags = 0;
}
static void put_nil(lua_State *L, Table *h, int k) {
    if (ttisnil(GS(h, k))) return;
    setnilvalue(luaH_setstr(L, h, K[k]));
    h->flags = 0;
}

static int l_mv_setup(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    if (!keys_ready) {
        lua_newtable(L);
        for (int i = 0; i < K_COUNT; i++) {
            lua_pushstring(L, key_names[i]);
            K[i] = rawtsvalue(L->top - 1);
            lua_rawseti(L, -2, i + 1);
        }
        lua_setfield(L, LUA_REGISTRYINDEX, "mv.keys");
        keys_ready = 1;
    }
    lua_getfield(L, 1, "move_with_major"); luaL_checktype(L, -1, LUA_TFUNCTION);
    if (ref_with_major != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref_with_major);
    ref_with_major = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_getfield(L, 1, "lr_clamp"); luaL_checktype(L, -1, LUA_TFUNCTION);
    if (ref_lr_clamp != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref_lr_clamp);
    ref_lr_clamp = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_getfield(L, 1, "fallback");
    if (ref_fallback != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref_fallback);
    if (lua_isfunction(L, -1)) ref_fallback = luaL_ref(L, LUA_REGISTRYINDEX);
    else { lua_pop(L, 1); ref_fallback = LUA_NOREF; }
    return 0;
}

/* Moveable:move's test for a Major with nothing to simulate: 1 idle, 0 not idle, -1 a field has the wrong type */
static int major_is_idle(Table *self, Table *T, Table *VT, Table *vel, Table *pin) {
    if (!FALSY(GS(self, K_juice)) || !FALSY(GS(self, K_zoom))) return 0;
    static const int eq[6] = { K_x, K_y, K_r, K_scale, K_w, K_h };
    for (int i = 0; i < 6; i++) {
        const TValue *a = GS(T, eq[i]), *b = GS(VT, eq[i]);
        if (!IS_NUM(a) || !IS_NUM(b)) return -1;
        if (nvalue(a) != nvalue(b)) return 0;
    }
    if (!FALSY(GS(pin, K_x)) || !FALSY(GS(pin, K_y))) return 0;
    static const int vk[4] = { K_x, K_y, K_r, K_scale };
    static const double lim[4] = { 0.01, 0.01, 0.001, 0.001 };
    for (int i = 0; i < 4; i++) {
        const TValue *v = GS(vel, vk[i]);
        if (!IS_NUM(v)) return -1;
        lua_Number n = nvalue(v), l = cast_num(lim[i]);
        if (n >= l || n <= -l) return 0;
    }
    return 1;
}

enum { PLAN_PAUSED, PLAN_GLUED, PLAN_MINOR, PLAN_MAJOR_IDLE, PLAN_NOROLE };

/* major:move(dt) through the object: a subclass may override move */
static void call_major_move(lua_State *L, const TValue *major, lua_Number dt) {
    setobj2s(L, L->top, major); L->top++;
    lua_getfield(L, -1, "move");
    lua_pushvalue(L, -2);
    lua_pushnumber(L, dt);
    lua_call(L, 2, 0);
    lua_pop(L, 1);
}
static void call_ref(lua_State *L, int ref, Table *self, int with_dt, lua_Number dt) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    sethvalue(L, L->top, self); L->top++;
    if (with_dt) lua_pushnumber(L, dt);
    lua_call(L, 1 + with_dt, 0);
}

static int move_core(lua_State *L) {
    if (!keys_ready) return luaL_error(L, "native.mv_setup has not run");
    if (lua_gettop(L) < 2 || !IS_TBL(L->base) || !lua_isnumber(L, 2)) goto bail;
    Table *self = hvalue(L->base);
    lua_Number dt = lua_tonumber(L, 2);

    const TValue *v = GS(hvalue(&L->l_gt), K_G);
    if (!IS_TBL(v)) goto bail;
    Table *G = hvalue(v);
    v = GS(G, K_FRAMES);
    if (!IS_TBL(v)) goto bail;
    const TValue *gmv = GS(hvalue(v), K_MOVE);
    if (!IS_NUM(gmv)) goto bail;
    lua_Number gm = nvalue(gmv);

    v = GS(self, K_FRAME);
    if (!IS_TBL(v)) goto bail;
    Table *FR = hvalue(v);
    const TValue *fm = GS(FR, K_MOVE);
    if (!IS_NUM(fm)) goto bail;
    if (nvalue(fm) >= gm) { lua_pushboolean(L, 1); return 1; }

    int plan = PLAN_NOROLE;
    Table *T = NULL, *al = NULL, *role = NULL, *major = NULL, *room_T = NULL, *sp = NULL;
    if (FALSY(GS(self, K_created_on_pause))) {
        v = GS(G, K_SETTINGS);
        if (!IS_TBL(v)) goto bail;
        if (!FALSY(GS(hvalue(v), K_paused))) plan = PLAN_PAUSED;
    }
    if (plan != PLAN_PAUSED) {
        v = GS(self, K_alignment);
        if (!IS_TBL(v)) goto bail;
        al = hvalue(v);
        const TValue *po = GS(al, K_prev_offset), *of = GS(al, K_offset);
        if (!IS_TBL(po) || !IS_TBL(of)) goto bail;
        const TValue *pox = GS(hvalue(po), K_x), *poy = GS(hvalue(po), K_y);
        const TValue *ofx = GS(hvalue(of), K_x), *ofy = GS(hvalue(of), K_y);
        if (!IS_NUM(pox) || !IS_NUM(poy) || !IS_NUM(ofx) || !IS_NUM(ofy)) goto bail;
        /* a changed alignment makes Moveable:move call align_to_major, which stays in Lua */
        if (nvalue(pox) != nvalue(ofx) || nvalue(poy) != nvalue(ofy) || !luaO_rawequalObj(GS(al, K_prev_type), GS(al, K_type))) goto bail;

        v = GS(self, K_role);
        if (!IS_TBL(v)) goto bail;
        role = hvalue(v);
        const TValue *rt = GS(role, K_role_type), *mj = GS(role, K_major);
        if (IS_STR(rt, K_Glued)) {
            plan = PLAN_GLUED;
            if (!FALSY(mj)) {
                if (!IS_TBL(mj)) goto bail;
                major = hvalue(mj);
                const TValue *mT = GS(major, K_T), *mVT = GS(major, K_VT), *sVT = GS(self, K_VT);
                if (!IS_TBL(mT) || !IS_TBL(mVT) || !IS_TBL(sVT)) goto bail;
                if (!IS_TBL(GS(major, K_pinch)) || !IS_TBL(GS(major, K_shadow_parrallax))) goto bail;
                static const int need[6] = { K_x, K_y, K_w, K_h, K_r, K_scale };
                for (int i = 0; i < 6; i++) if (!IS_NUM(GS(hvalue(mVT), need[i]))) goto bail;
                if (!IS_NUM(GS(hvalue(mT), K_w))) goto bail;
            }
        } else if (IS_STR(rt, K_Minor)) {
            plan = PLAN_MINOR;
            if (!FALSY(mj)) {
                if (!IS_TBL(mj)) goto bail;
                major = hvalue(mj);
                const TValue *mf = GS(major, K_FRAME);
                if (!IS_TBL(mf) || !IS_NUM(GS(hvalue(mf), K_MOVE))) goto bail;
                if (!IS_TBL(GS(self, K_config))) goto bail;
                if (ref_with_major == LUA_NOREF) goto bail;
            }
        } else if (IS_STR(rt, K_Major)) {
            const TValue *tv = GS(self, K_T), *vtv = GS(self, K_VT), *velv = GS(self, K_velocity), *pv = GS(self, K_pinch);
            if (!IS_TBL(tv) || !IS_TBL(vtv) || !IS_TBL(velv) || !IS_TBL(pv)) goto bail;
            T = hvalue(tv);
            if (major_is_idle(self, T, hvalue(vtv), hvalue(velv), hvalue(pv)) != 1) goto bail;
            plan = PLAN_MAJOR_IDLE;
            const TValue *room = GS(G, K_ROOM);
            if (!FALSY(room)) {
                if (!IS_TBL(room)) goto bail;
                const TValue *rT = GS(hvalue(room), K_T), *spv = GS(self, K_shadow_parrallax);
                if (!IS_TBL(rT) || !IS_TBL(spv)) goto bail;
                if (!IS_NUM(GS(hvalue(rT), K_w)) || !IS_NUM(GS(T, K_x)) || !IS_NUM(GS(T, K_w))) goto bail;
                room_T = hvalue(rT); sp = hvalue(spv);
            }
        }
        if (!FALSY(GS(al, K_lr_clamp)) && ref_lr_clamp == LUA_NOREF) goto bail;
    }

    /* nothing bails from here on; the frame stamps first, in the order Moveable:move does them */
    put(L, FR, K_OLD_MAJOR, GS(FR, K_MAJOR));
    put_nil(L, FR, K_MAJOR);
    put_num(L, FR, K_MOVE, gm);
    if (plan == PLAN_PAUSED) { lua_pushboolean(L, 1); return 1; }

    put_nil(L, self, K_CALCING);
    if (plan == PLAN_GLUED) {
        if (major) {
            Table *mT = hvalue(GS(major, K_T)), *mVT = hvalue(GS(major, K_VT)), *sVT = hvalue(GS(self, K_VT));
            put(L, self, K_T, GS(major, K_T));
            lua_Number mvw = NUM(mVT, K_w), mtw = NUM(mT, K_w);
            /* VT.x = major.VT.x + (0.5*(1 - major.VT.w/major.T.w)*self.T.w), self.T being major.T by now */
            put_num(L, sVT, K_x, luai_numadd(NUM(mVT, K_x),
                luai_nummul(luai_nummul(cast_num(0.5), luai_numsub(cast_num(1), luai_numdiv(mvw, mtw))), mtw)));
            put_num(L, sVT, K_y, NUM(mVT, K_y));
            put_num(L, sVT, K_w, mvw);
            put_num(L, sVT, K_h, NUM(mVT, K_h));
            put_num(L, sVT, K_r, NUM(mVT, K_r));
            put_num(L, sVT, K_scale, NUM(mVT, K_scale));
            put(L, self, K_pinch, GS(major, K_pinch));
            put(L, self, K_shadow_parrallax, GS(major, K_shadow_parrallax));
        }
    } else if (plan == PLAN_MINOR) {
        if (major) {
            if (NUM(hvalue(GS(major, K_FRAME)), K_MOVE) < gm) call_major_move(L, GS(role, K_major), dt);
            const TValue *st = GS(major, K_STATIONARY);
            put(L, self, K_STATIONARY, st);
            const TValue *cfg = GS(self, K_config);
            if (!IS_TBL(cfg)) return luaL_error(L, "attempt to index field 'config'");
            if (FALSY(st) || !FALSY(GS(self, K_NEW_ALIGNMENT)) || !FALSY(GS(hvalue(cfg), K_refresh_movement))
                || !FALSY(GS(self, K_juice)) || IS_STR(GS(role, K_xy_bond), K_Weak) || IS_STR(GS(role, K_r_bond), K_Weak)) {
                put_bool(L, self, K_CALCING, 1);
                call_ref(L, ref_with_major, self, 1, dt);
            }
        }
    } else if (plan == PLAN_MAJOR_IDLE) {
        put_bool(L, self, K_STATIONARY, 1);
        if (room_T) {
            lua_Number half = HALF(NUM(room_T, K_w));
            lua_Number a = luai_numsub(luai_numadd(NUM(T, K_x), HALF(NUM(T, K_w))), half);
            put_num(L, sp, K_x, luai_nummul(luai_numdiv(a, half), cast_num(1.5)));
        }
    }
    if (!FALSY(GS(al, K_lr_clamp))) call_ref(L, ref_lr_clamp, self, 0, 0);
    put_bool(L, self, K_NEW_ALIGNMENT, 0);
    lua_pushboolean(L, 1);
    return 1;
bail:
    lua_pushboolean(L, 0);
    return 1;
}

static int l_mv_move(lua_State *L) {
    int done = move_core(L);
    (void)done;
    return 1;
}
static int l_mv_method(lua_State *L) {
    move_core(L);
    int handled = lua_toboolean(L, -1);
    lua_settop(L, 2);
    if (handled) return 0;
    if (ref_fallback == LUA_NOREF) return luaL_error(L, "native.mv_method needs mv_setup{fallback = f}");
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref_fallback);
    lua_pushvalue(L, 1);
    lua_pushvalue(L, 2);
    lua_call(L, 2, 0);
    return 0;
}

int mv_open(lua_State *L) {
    lua_pushcfunction(L, l_mv_setup); lua_setfield(L, -2, "mv_setup");
    lua_pushcfunction(L, l_mv_move); lua_setfield(L, -2, "mv_move");
    lua_pushcfunction(L, l_mv_method); lua_setfield(L, -2, "mv_method");
    return 0;
}
