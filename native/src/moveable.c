/* A C fast path for Balatro's Moveable:move (engine/moveable.lua), reading and writing the object's Lua tables directly.
 *
 * Why direct access: through the public Lua API a C function reading the same fields is no faster than the Lua VM
 * (about 720 ns against 735 ns for the idle check on desktop); with luaH_getstr on pre-interned keys it takes 82 ns.
 * This file therefore includes Lua's internal headers and is tied to the Lua 5.1.5 in third_party/.
 *
 * Contract: native.mv_move(self, dt) returns true when it did the whole move, false (and changed nothing) when the object
 * is in a state the fast path does not cover; the caller then runs the Lua implementation. Covered: the frame guard, the
 * paused game, Glued roles, Minor roles (the major's move is called back in Lua; get_major and move_with_major are done
 * here, and Lua's move_with_major runs when they cannot) and Major roles, idle or moving (move_xy, move_r, move_scale and
 * move_wh are done here). Anything else, including a missing field or a field of the wrong type, is a bail; so is an
 * object with a juice, which stays in Lua.
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
#include <math.h>
#ifdef PSP_LUA_FLOAT
#include <pspmath.h>
#define MV_SQRT sqrtf
#define MV_FABS fabsf
#define MV_SIN vfpu_sinf
#define MV_COS vfpu_cosf
#else
#define MV_SQRT sqrt
#define MV_FABS fabs
#define MV_SIN sin
#define MV_COS cos
#endif

enum {
    K_G, K_FRAMES, K_MOVE, K_SETTINGS, K_paused, K_ROOM, K_T, K_VT, K_w, K_x, K_y, K_r, K_scale, K_h,
    K_FRAME, K_OLD_MAJOR, K_MAJOR, K_created_on_pause, K_alignment, K_prev_offset, K_offset, K_prev_type, K_type, K_lr_clamp,
    K_CALCING, K_role, K_role_type, K_major, K_STATIONARY, K_NEW_ALIGNMENT, K_config, K_refresh_movement, K_juice, K_zoom,
    K_xy_bond, K_r_bond, K_velocity, K_pinch, K_shadow_parrallax,
    K_scale_bond, K_wh_bond, K_ARGS, K_get_major, K_temp_offs, K_layered_parallax, K_exp_times, K_max_vel, K_states, K_drag, K_hover, K_is,
    K_REFRESH, K_Strong, K_xy, K_update, K_collide, K_container, K_TILESCALE, K_TILESIZE, K_parent,
    K_Glued, K_Minor, K_Major, K_Weak,
    K_COUNT
};
static const char *const key_names[K_COUNT] = {
    "G", "FRAMES", "MOVE", "SETTINGS", "paused", "ROOM", "T", "VT", "w", "x", "y", "r", "scale", "h",
    "FRAME", "OLD_MAJOR", "MAJOR", "created_on_pause", "alignment", "prev_offset", "offset", "prev_type", "type", "lr_clamp",
    "CALCING", "role", "role_type", "major", "STATIONARY", "NEW_ALIGNMENT", "config", "refresh_movement", "juice", "zoom",
    "xy_bond", "r_bond", "velocity", "pinch", "shadow_parrallax",
    "scale_bond", "wh_bond", "ARGS", "get_major", "temp_offs", "layered_parallax", "exp_times", "max_vel", "states", "drag", "hover", "is",
    "REFRESH_FRAME_MAJOR_CACHE", "Strong", "xy", "update", "collide", "container", "TILESCALE", "TILESIZE", "parent",
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

static void init_keys(lua_State *L) {
    if (keys_ready) return;
    lua_newtable(L);
    for (int i = 0; i < K_COUNT; i++) {
        lua_pushstring(L, key_names[i]);
        K[i] = rawtsvalue(L->top - 1);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, LUA_REGISTRYINDEX, "mv.keys");
    keys_ready = 1;
}

static int l_mv_setup(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    init_keys(L);
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

static void table_clear(Table *t) {
    int i;
    for (i = 0; i < t->sizearray; i++) setnilvalue(&t->array[i]);
    /* an empty hash part is the shared read-only dummy node, whose value is nil: only live entries are written */
    for (i = 0; i < sizenode(t); i++) { TValue *v = gval(gnode(t, i)); if (!ttisnil(v)) setnilvalue(v); }
    t->flags = 0;
}

static int is_weak(Table *role, int k) { return IS_STR(GS(role, k), K_Weak); }
static int is_strong(Table *role, int k) { return IS_STR(GS(role, k), K_Strong); }

/* ---- Moveable:move_xy, move_r, move_scale and move_wh, with Lua's operation order */
typedef struct { Table *T, *VT, *vel, *pin, *exp, *drag, *hover; int zoom; } Leaf;

/* every field the movers read, checked before anything is written; an object with a juice is not handled */
static int leaf_prepare(Table *self, Table *G, Leaf *lf) {
    static const int six[6] = { K_x, K_y, K_r, K_scale, K_w, K_h };
    static const int four[4] = { K_x, K_y, K_r, K_scale };
    const TValue *tv = GS(self, K_T), *vtv = GS(self, K_VT), *velv = GS(self, K_velocity), *pv = GS(self, K_pinch), *ev = GS(G, K_exp_times);
    int i;
    if (!IS_TBL(tv) || !IS_TBL(vtv) || !IS_TBL(velv) || !IS_TBL(pv) || !IS_TBL(ev)) return 0;
    if (!FALSY(GS(self, K_juice))) return 0;
    lf->T = hvalue(tv); lf->VT = hvalue(vtv); lf->vel = hvalue(velv); lf->pin = hvalue(pv); lf->exp = hvalue(ev);
    for (i = 0; i < 6; i++) if (!IS_NUM(GS(lf->T, six[i])) || !IS_NUM(GS(lf->VT, six[i]))) return 0;
    for (i = 0; i < 4; i++) if (!IS_NUM(GS(lf->vel, four[i]))) return 0;
    if (!IS_NUM(GS(lf->exp, K_xy)) || !IS_NUM(GS(lf->exp, K_r)) || !IS_NUM(GS(lf->exp, K_scale)) || !IS_NUM(GS(lf->exp, K_max_vel))) return 0;
    lf->zoom = !FALSY(GS(self, K_zoom));
    lf->drag = lf->hover = NULL;
    if (lf->zoom) {
        const TValue *st = GS(self, K_states);
        if (!IS_TBL(st)) return 0;
        const TValue *dr = GS(hvalue(st), K_drag), *ho = GS(hvalue(st), K_hover);
        if (!IS_TBL(dr) || !IS_TBL(ho)) return 0;
        lf->drag = hvalue(dr); lf->hover = hvalue(ho);
    }
    return 1;
}

#define ABSGT(a, b) (MV_FABS(a) > (b))

static void leaf_xy(lua_State *L, Table *self, const Leaf *lf, lua_Number dt) {
    Table *T = lf->T, *VT = lf->VT, *vel = lf->vel;
    lua_Number c001 = cast_num(0.01);
    if (NUM(T, K_x) != NUM(VT, K_x) || ABSGT(NUM(vel, K_x), c001) || NUM(T, K_y) != NUM(VT, K_y) || ABSGT(NUM(vel, K_y), c001)) {
        lua_Number xy = NUM(lf->exp, K_xy), mv = NUM(lf->exp, K_max_vel), one_m = luai_numsub(cast_num(1), xy);
        lua_Number vx = luai_numadd(luai_nummul(xy, NUM(vel, K_x)),
            luai_nummul(luai_nummul(luai_nummul(one_m, luai_numsub(NUM(T, K_x), NUM(VT, K_x))), cast_num(35)), dt));
        lua_Number vy = luai_numadd(luai_nummul(xy, NUM(vel, K_y)),
            luai_nummul(luai_nummul(luai_nummul(one_m, luai_numsub(NUM(T, K_y), NUM(VT, K_y))), cast_num(35)), dt));
        if (luai_numadd(luai_nummul(vx, vx), luai_nummul(vy, vy)) > luai_nummul(mv, mv)) {
            lua_Number actual = MV_SQRT(luai_numadd(luai_nummul(vx, vx), luai_nummul(vy, vy)));
            vx = luai_numdiv(luai_nummul(mv, vx), actual);
            vy = luai_numdiv(luai_nummul(mv, vy), actual);
        }
        put_bool(L, self, K_STATIONARY, 0);
        lua_Number px = luai_numadd(NUM(VT, K_x), vx), py = luai_numadd(NUM(VT, K_y), vy);
        if (MV_FABS(luai_numsub(px, NUM(T, K_x))) < c001 && MV_FABS(vx) < c001) { px = NUM(T, K_x); vx = 0; }
        if (MV_FABS(luai_numsub(py, NUM(T, K_y))) < c001 && MV_FABS(vy) < c001) { py = NUM(T, K_y); vy = 0; }
        put_num(L, vel, K_x, vx); put_num(L, vel, K_y, vy);
        put_num(L, VT, K_x, px); put_num(L, VT, K_y, py);
    }
}

static void leaf_scale(lua_State *L, Table *self, const Leaf *lf) {
    Table *T = lf->T, *VT = lf->VT, *vel = lf->vel;
    lua_Number zoom_add = 0;
    if (lf->zoom) {
        zoom_add = luai_numadd(FALSY(GS(lf->drag, K_is)) ? cast_num(0) : cast_num(0.1), FALSY(GS(lf->hover, K_is)) ? cast_num(0) : cast_num(0.05));
    }
    lua_Number des = luai_numadd(luai_numadd(NUM(T, K_scale), zoom_add), cast_num(0));
    if (des != NUM(VT, K_scale) || ABSGT(NUM(vel, K_scale), cast_num(0.001))) {
        put_bool(L, self, K_STATIONARY, 0);
        lua_Number es = NUM(lf->exp, K_scale);
        lua_Number v = luai_numadd(luai_nummul(es, NUM(vel, K_scale)), luai_nummul(luai_numsub(cast_num(1), es), luai_numsub(des, NUM(VT, K_scale))));
        put_num(L, vel, K_scale, v);
        put_num(L, VT, K_scale, luai_numadd(NUM(VT, K_scale), v));
    }
}

static void leaf_wh(lua_State *L, Table *self, const Leaf *lf, lua_Number dt) {
    Table *T = lf->T, *VT = lf->VT;
    int px = !FALSY(GS(lf->pin, K_x)), py = !FALSY(GS(lf->pin, K_y));
    lua_Number vw = NUM(VT, K_w), vh = NUM(VT, K_h), tw = NUM(T, K_w), th = NUM(T, K_h);
    if ((tw != vw && !px) || (th != vh && !py) || (vw > 0 && px) || (vh > 0 && py)) {
        put_bool(L, self, K_STATIONARY, 0);
        lua_Number step = luai_nummul(cast_num(8), dt);
        vw = luai_numadd(vw, luai_nummul(luai_nummul(step, px ? cast_num(-1) : cast_num(1)), tw));
        vh = luai_numadd(vh, luai_nummul(luai_nummul(step, py ? cast_num(-1) : cast_num(1)), th));
        /* math.max(math.min(v, t), 0): min keeps its first argument unless the second is smaller, max unless it is larger */
        if (luai_numlt(tw, vw)) vw = tw;
        if (luai_numlt(vw, cast_num(0))) vw = cast_num(0);
        if (luai_numlt(th, vh)) vh = th;
        if (luai_numlt(vh, cast_num(0))) vh = cast_num(0);
        put_num(L, VT, K_w, vw);
        put_num(L, VT, K_h, vh);
    }
}

static void leaf_r(lua_State *L, Table *self, const Leaf *lf, lua_Number dt) {
    Table *T = lf->T, *VT = lf->VT, *vel = lf->vel;
    lua_Number des = luai_numadd(luai_numadd(NUM(T, K_r), luai_numdiv(luai_nummul(cast_num(0.015), NUM(vel, K_x)), dt)), cast_num(0));
    if (des != NUM(VT, K_r) || ABSGT(NUM(vel, K_r), cast_num(0.001))) {
        put_bool(L, self, K_STATIONARY, 0);
        lua_Number er = NUM(lf->exp, K_r);
        lua_Number v = luai_numadd(luai_nummul(er, NUM(vel, K_r)), luai_nummul(luai_numsub(cast_num(1), er), luai_numsub(des, NUM(VT, K_r))));
        put_num(L, vel, K_r, v);
        put_num(L, VT, K_r, luai_numadd(NUM(VT, K_r), v));
    }
    {
        lua_Number c = cast_num(0.001);
        if (MV_FABS(luai_numsub(NUM(VT, K_r), NUM(T, K_r))) < c && MV_FABS(NUM(vel, K_r)) < c) {
            put_num(L, VT, K_r, NUM(T, K_r));
            put_num(L, vel, K_r, 0);
        }
    }
}

/* Moveable:calculate_parrallax once G.ROOM and the shadow_parrallax table have been checked */
static void parallax_c(lua_State *L, Table *T, Table *room_T, Table *sp) {
    lua_Number half = HALF(NUM(room_T, K_w));
    lua_Number a = luai_numsub(luai_numadd(NUM(T, K_x), HALF(NUM(T, K_w))), half);
    put_num(L, sp, K_x, luai_nummul(luai_numdiv(a, half), cast_num(1.5)));
}

/* ---- Moveable:get_major. Returns the table Lua's version returns, or NULL when something it would create is missing
   (the caller then runs Lua's version). Nothing is written before a NULL return for this object; the objects below it in the
   chain are complete by then, which is the state Lua's version would have left them in. */
static Table *get_major_c(lua_State *L, Table *node, Table *G, int depth) {
    const TValue *rv = GS(node, K_role);
    if (depth > 64 || !IS_TBL(rv)) return NULL;
    Table *role = hvalue(rv);
    const TValue *mj = GS(role, K_major);
    int major_role = IS_STR(GS(role, K_role_type), K_Major);
    int self_major = IS_TBL(mj) && hvalue(mj) == node;
    if (!major_role && !self_major && !is_weak(role, K_xy_bond) && !is_weak(role, K_r_bond)) {
        const TValue *fv = GS(node, K_FRAME);
        if (!IS_TBL(fv)) return NULL;
        Table *FR = hvalue(fv);
        const TValue *cached = GS(FR, K_MAJOR);
        int refresh = !FALSY(GS(G, K_REFRESH));
        if (!FALSY(cached) && !refresh) return IS_TBL(cached) ? hvalue(cached) : NULL;
        if (!IS_TBL(mj)) return NULL;
        Table *sub = get_major_c(L, hvalue(mj), G, depth + 1);
        if (!sub) return NULL;
        const TValue *tov = GS(node, K_temp_offs), *lpv = GS(node, K_layered_parallax), *rov = GS(role, K_offset);
        const TValue *so = GS(sub, K_offset);
        if (!IS_TBL(tov) || !IS_TBL(lpv) || !IS_TBL(rov) || !IS_TBL(so)) return NULL;
        Table *res, *offt;
        int set_offset;
        if (!FALSY(cached)) {
            if (!IS_TBL(cached)) return NULL;
            res = hvalue(cached);
            const TValue *ex = GS(res, K_offset);
            if (FALSY(ex)) { offt = hvalue(tov); set_offset = 1; }
            else if (IS_TBL(ex)) { offt = hvalue(ex); set_offset = 0; }
            else return NULL;
        } else {
            /* EMPTY(OLD_MAJOR) drops its old offset too, so the temp table becomes the offset again */
            const TValue *ov = GS(FR, K_OLD_MAJOR);
            if (!IS_TBL(ov)) return NULL;
            res = hvalue(ov); offt = hvalue(tov); set_offset = 1;
        }
        Table *temp = hvalue(tov), *lp = hvalue(lpv), *ro = hvalue(rov), *sof = hvalue(so);
        if (res == temp || offt == sof) return NULL;
        if (!IS_NUM(GS(sof, K_x)) || !IS_NUM(GS(sof, K_y)) || !IS_NUM(GS(ro, K_x)) || !IS_NUM(GS(ro, K_y)) || !IS_NUM(GS(lp, K_x)) || !IS_NUM(GS(lp, K_y))) return NULL;
        /* from here on this object's cache is written, in Lua's order */
        if (FALSY(cached)) table_clear(res);
        table_clear(temp);
        { TValue sm = *GS(sub, K_major); put(L, res, K_major, &sm); }
        if (set_offset) { TValue t; sethvalue(L, &t, temp); put(L, res, K_offset, &t); }
        {
            lua_Number x = luai_numadd(luai_numadd(NUM(sof, K_x), NUM(ro, K_x)), NUM(lp, K_x));
            lua_Number y = luai_numadd(luai_numadd(NUM(sof, K_y), NUM(ro, K_y)), NUM(lp, K_y));
            put_num(L, offt, K_x, x); put_num(L, offt, K_y, y);
        }
        { TValue t; sethvalue(L, &t, res); put(L, FR, K_MAJOR, &t); }
        return res;
    } else {
        const TValue *av = GS(node, K_ARGS);
        if (!IS_TBL(av)) return NULL;
        Table *ARGS = hvalue(av);
        const TValue *gv = GS(ARGS, K_get_major);
        if (!IS_TBL(gv)) return NULL;
        Table *ga = hvalue(gv);
        const TValue *ov = GS(ga, K_offset);
        if (!IS_TBL(ov)) return NULL;
        Table *off = hvalue(ov);   /* put() may rehash ga and move the slot ov points to */
        { TValue t; sethvalue(L, &t, node); put(L, ga, K_major, &t); }
        put_num(L, off, K_x, 0);
        put_num(L, off, K_y, 0);
        return ga;
    }
}

/* ---- Moveable:move_with_major for a Minor role, after the major has moved. Returns 0, having written nothing but
   the (complete) get_major caches, when Lua's version has to do it. */
static int mwm_c(lua_State *L, Table *self, Table *role, Table *G, lua_Number dt) {
    static const int six[6] = { K_x, K_y, K_r, K_scale, K_w, K_h };
    int i;
    if (!FALSY(GS(self, K_juice))) return 0;
    const TValue *mj = GS(role, K_major);
    if (!IS_TBL(mj)) return 0;
    Table *mt = get_major_c(L, hvalue(mj), G, 0);
    if (!mt) return 0;
    const TValue *rv = GS(mt, K_major), *mo = GS(mt, K_offset), *ro = GS(role, K_offset);
    const TValue *tv = GS(self, K_T), *vtv = GS(self, K_VT);
    if (!IS_TBL(rv) || !IS_TBL(mo) || !IS_TBL(ro) || !IS_TBL(tv) || !IS_TBL(vtv)) return 0;
    Table *M = hvalue(rv), *moff = hvalue(mo), *roff = hvalue(ro), *T = hvalue(tv), *VT = hvalue(vtv);
    const TValue *mTv = GS(M, K_T), *mVTv = GS(M, K_VT);
    if (!IS_TBL(mTv) || !IS_TBL(mVTv)) return 0;
    Table *MT = hvalue(mTv), *MVT = hvalue(mVTv);
    for (i = 0; i < 6; i++) if (!IS_NUM(GS(T, six[i])) || !IS_NUM(GS(VT, six[i])) || !IS_NUM(GS(MT, six[i])) || !IS_NUM(GS(MVT, six[i]))) return 0;
    if (!IS_NUM(GS(moff, K_x)) || !IS_NUM(GS(moff, K_y)) || !IS_NUM(GS(roff, K_x)) || !IS_NUM(GS(roff, K_y))) return 0;
    int xy_weak = is_weak(role, K_xy_bond), r_weak = is_weak(role, K_r_bond);
    int sc_weak = is_weak(role, K_scale_bond), wh_weak = is_weak(role, K_wh_bond);
    Leaf lf;
    if (xy_weak || r_weak || sc_weak || wh_weak) {
        if (!leaf_prepare(self, G, &lf)) return 0;
        if (lf.T != T || lf.VT != VT) return 0;
    }
    lua_Number mvr = NUM(MVT, K_r), rx, ry;
    if (r_weak || (mvr < cast_num(0.0001) && mvr > cast_num(-0.0001))) {
        rx = luai_numadd(NUM(roff, K_x), NUM(moff, K_x));
        ry = luai_numadd(NUM(roff, K_y), NUM(moff, K_y));
    } else {
        lua_Number cs = MV_COS(mvr), sn = MV_SIN(mvr);
        lua_Number whw = luai_numadd(luai_numdiv(luai_numunm(NUM(T, K_w)), cast_num(2)), luai_numdiv(NUM(MT, K_w), cast_num(2)));
        lua_Number whh = luai_numadd(luai_numdiv(luai_numunm(NUM(T, K_h)), cast_num(2)), luai_numdiv(NUM(MT, K_h), cast_num(2)));
        lua_Number ox = luai_numsub(luai_numadd(NUM(roff, K_x), NUM(moff, K_x)), whw);
        lua_Number oy = luai_numsub(luai_numadd(NUM(roff, K_y), NUM(moff, K_y)), whh);
        rx = luai_numadd(luai_numsub(luai_nummul(ox, cs), luai_nummul(oy, sn)), whw);
        ry = luai_numadd(luai_numadd(luai_nummul(ox, sn), luai_nummul(oy, cs)), whh);
    }
    {
        const TValue *room = GS(G, K_ROOM);
        Table *room_T = NULL, *sp = NULL;
        if (!FALSY(room)) {
            if (!IS_TBL(room)) return 0;
            const TValue *rT = GS(hvalue(room), K_T), *spv = GS(self, K_shadow_parrallax);
            if (!IS_TBL(rT) || !IS_TBL(spv) || !IS_NUM(GS(hvalue(rT), K_w))) return 0;
            room_T = hvalue(rT); sp = hvalue(spv);
        }
        put_num(L, T, K_x, luai_numadd(NUM(MT, K_x), rx));
        put_num(L, T, K_y, luai_numadd(NUM(MT, K_y), ry));
        if (is_strong(role, K_xy_bond)) {
            put_num(L, VT, K_x, luai_numadd(NUM(MVT, K_x), rx));
            put_num(L, VT, K_y, luai_numadd(NUM(MVT, K_y), ry));
        } else if (xy_weak) leaf_xy(L, self, &lf, dt);
        if (is_strong(role, K_r_bond)) put_num(L, VT, K_r, luai_numadd(luai_numadd(NUM(T, K_r), NUM(MVT, K_r)), cast_num(0)));
        else if (r_weak) leaf_r(L, self, &lf, dt);
        if (is_strong(role, K_scale_bond))
            put_num(L, VT, K_scale, luai_numadd(luai_nummul(NUM(T, K_scale), luai_numdiv(NUM(MVT, K_scale), NUM(MT, K_scale))), cast_num(0)));
        else if (sc_weak) leaf_scale(L, self, &lf);
        if (is_strong(role, K_wh_bond)) {
            lua_Number mw = NUM(MT, K_w), mh = NUM(MT, K_h);
            put_num(L, VT, K_x, luai_numadd(NUM(VT, K_x), luai_nummul(luai_nummul(cast_num(0.5), luai_numsub(cast_num(1), luai_numdiv(NUM(MVT, K_w), mw))), NUM(T, K_w))));
            put_num(L, VT, K_w, luai_nummul(NUM(T, K_w), luai_numdiv(NUM(MVT, K_w), mw)));
            put_num(L, VT, K_h, luai_nummul(NUM(T, K_h), luai_numdiv(NUM(MVT, K_h), mh)));
        } else if (wh_weak) leaf_wh(L, self, &lf, dt);
        if (room_T) parallax_c(L, T, room_T, sp);
    }
    return 1;
}

enum { PLAN_PAUSED, PLAN_GLUED, PLAN_MINOR, PLAN_MAJOR_IDLE, PLAN_MAJOR_ACTIVE, PLAN_NOROLE };

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

/* The whole move for one object: 1 when done, 0 (nothing changed) when the Lua implementation has to run. */
static int move_obj(lua_State *L, Table *self, lua_Number dt) {

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
    if (nvalue(fm) >= gm) return 1;

    int plan = PLAN_NOROLE;
    Table *T = NULL, *al = NULL, *role = NULL, *major = NULL, *room_T = NULL, *sp = NULL;
    Leaf lf;
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
            int idle = major_is_idle(self, T, hvalue(vtv), hvalue(velv), hvalue(pv));
            if (idle < 0) goto bail;
            plan = idle ? PLAN_MAJOR_IDLE : PLAN_MAJOR_ACTIVE;
            if (plan == PLAN_MAJOR_ACTIVE && !leaf_prepare(self, G, &lf)) goto bail;
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
    if (plan == PLAN_PAUSED) return 1;

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
                if (!mwm_c(L, self, role, G, dt)) call_ref(L, ref_with_major, self, 1, dt);
            }
        }
    } else if (plan == PLAN_MAJOR_IDLE || plan == PLAN_MAJOR_ACTIVE) {
        put_bool(L, self, K_STATIONARY, 1);
        if (plan == PLAN_MAJOR_ACTIVE) {
            leaf_xy(L, self, &lf, dt);
            leaf_r(L, self, &lf, dt);
            leaf_scale(L, self, &lf);
            leaf_wh(L, self, &lf, dt);
        }
        if (room_T) parallax_c(L, T, room_T, sp);
    }
    if (!FALSY(GS(al, K_lr_clamp))) call_ref(L, ref_lr_clamp, self, 0, 0);
    put_bool(L, self, K_NEW_ALIGNMENT, 0);
    return 1;
bail:
    return 0;
}

/* the arguments of native.mv_move / native.mv_method: (self, dt); 0 when they are not a table and a number */
static int move_args(lua_State *L, Table **self, lua_Number *dt) {
    if (!keys_ready) luaL_error(L, "native.mv_setup has not run");
    if (lua_gettop(L) < 2 || !IS_TBL(L->base) || !lua_isnumber(L, 2)) return 0;
    *self = hvalue(L->base);
    *dt = lua_tonumber(L, 2);
    return 1;
}
static int l_mv_move(lua_State *L) {
    Table *self; lua_Number dt;
    lua_pushboolean(L, move_args(L, &self, &dt) && move_obj(L, self, dt));
    return 1;
}
static void run_fallback(lua_State *L, Table *self, lua_Number dt) {
    if (ref_fallback == LUA_NOREF) luaL_error(L, "native.mv_method needs mv_setup{fallback = f}");
    call_ref(L, ref_fallback, self, 1, dt);
}
static int l_mv_method(lua_State *L) {
    Table *self; lua_Number dt;
    if (move_args(L, &self, &dt) && move_obj(L, self, dt)) return 0;
    lua_settop(L, 2);
    if (ref_fallback == LUA_NOREF) return luaL_error(L, "native.mv_method needs mv_setup{fallback = f}");
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref_fallback);
    lua_pushvalue(L, 1);
    lua_pushvalue(L, 2);
    lua_call(L, 2, 0);
    return 0;
}

/* native.mv_loop(moveables, game_move_frame, dt): for every object with FRAME.MOVE below the frame, v:move(dt) as
 * Game:update does. An object whose move is the native.mv_method installed by mv_setup skips the call frame. */
static int l_mv_loop(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_Number gm = luaL_checknumber(L, 2), dt = luaL_checknumber(L, 3);
    if (!keys_ready) return luaL_error(L, "native.mv_setup has not run");
    lua_settop(L, 3);
    lua_pushnil(L);
    while (lua_next(L, 1)) {
        const TValue *vv = L->top - 1;
        if (!IS_TBL(vv)) return luaL_error(L, "attempt to index a non-table moveable");
        Table *self = hvalue(vv);
        const TValue *fr = GS(self, K_FRAME);
        const TValue *fm = IS_TBL(fr) ? GS(hvalue(fr), K_MOVE) : NULL;
        if (!fm || !IS_NUM(fm)) return luaL_error(L, "attempt to compare a moveable FRAME.MOVE that is not a number");
        if (nvalue(fm) < gm) {
            lua_getfield(L, 5, "move");
            if (lua_tocfunction(L, -1) == l_mv_method) {
                lua_pop(L, 1);
                if (!move_obj(L, self, dt)) run_fallback(L, self, dt);
            } else {
                lua_pushvalue(L, 5);
                lua_pushnumber(L, dt);
                lua_call(L, 2, 0);
            }
        }
        lua_pop(L, 1);
    }
    return 0;
}

/* native.mv_update_loop(moveables, dt, node_update): for every object whose update is not node_update, v:update(dt);
 * then v.states.collide.is = false. */
static int l_mv_update_loop(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_Number dt = luaL_checknumber(L, 2);
    luaL_checkany(L, 3);
    if (!keys_ready) return luaL_error(L, "native.mv_setup has not run");
    lua_settop(L, 3);
    lua_pushnil(L);
    while (lua_next(L, 1)) {
        if (!IS_TBL(L->top - 1)) return luaL_error(L, "attempt to index a non-table moveable");
        Table *self = hvalue(L->top - 1);
        lua_getfield(L, 5, "update");
        if (!lua_rawequal(L, 6, 3)) {
            lua_pushvalue(L, 5);
            lua_pushnumber(L, dt);
            lua_call(L, 2, 0);
        } else lua_pop(L, 1);
        const TValue *st = GS(self, K_states);
        const TValue *cl = IS_TBL(st) ? GS(hvalue(st), K_collide) : NULL;
        if (!cl || !IS_TBL(cl)) return luaL_error(L, "attempt to index a moveable without states.collide");
        put_bool(L, hvalue(cl), K_is, 0);
        lua_pop(L, 1);
    }
    return 0;
}


/* Balatro's prep_draw(moveable, scale, rotate, offset) and Node:translate_container() reduced to the engine's matrix calls.
 * As with mv_method, an argument or field of an unexpected type means nothing is done here and the Lua function runs. */
void eng_prep_draw(float S, float tx, float ty, float r, float ox, float oy, float sc);
void eng_translate_container(float a, float b, float r, float c, float d);
static int ref_prep_fb = LUA_NOREF, ref_tc_fb = LUA_NOREF;

static int l_ui_setup(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    init_keys(L);
    lua_getfield(L, 1, "prep_draw"); luaL_checktype(L, -1, LUA_TFUNCTION);
    if (ref_prep_fb != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref_prep_fb);
    ref_prep_fb = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_getfield(L, 1, "translate_container"); luaL_checktype(L, -1, LUA_TFUNCTION);
    if (ref_tc_fb != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ref_tc_fb);
    ref_tc_fb = luaL_ref(L, LUA_REGISTRYINDEX);
    return 0;
}

static int tile_size(lua_State *L, lua_Number *out) {
    const TValue *g = GS(hvalue(&L->l_gt), K_G);
    if (!IS_TBL(g)) return 0;
    const TValue *ts = GS(hvalue(g), K_TILESCALE), *tz = GS(hvalue(g), K_TILESIZE);
    if (!IS_NUM(ts) || !IS_NUM(tz)) return 0;
    out[0] = nvalue(ts);
    out[1] = nvalue(tz);
    return 1;
}

/* (lp and lp.key) or (parent.layered_parallax and ...key) or 0; 0 when a field has the wrong type */
static int parallax_of(const TValue *lp, const TValue *parent, int key, lua_Number *out) {
    const TValue *v;
    *out = 0;
    if (!FALSY(lp)) {
        if (!IS_TBL(lp)) return 0;
        v = GS(hvalue(lp), key);
        if (!FALSY(v)) { if (!IS_NUM(v)) return 0; *out = nvalue(v); return 1; }
    }
    if (!FALSY(parent)) {
        if (!IS_TBL(parent)) return 0;
        const TValue *plp = GS(hvalue(parent), K_layered_parallax);
        if (!FALSY(plp)) {
            if (!IS_TBL(plp)) return 0;
            v = GS(hvalue(plp), key);
            if (!FALSY(v)) { if (!IS_NUM(v)) return 0; *out = nvalue(v); return 1; }
        }
    }
    return 1;
}

/* (offset and offset.key or 0) */
static int offset_of(const TValue *off, int key, lua_Number *out) {
    *out = 0;
    if (FALSY(off)) return 1;
    if (!IS_TBL(off)) return 0;
    const TValue *v = GS(hvalue(off), key);
    if (FALSY(v)) return 1;
    if (!IS_NUM(v)) return 0;
    *out = nvalue(v);
    return 1;
}

static int prep_core(lua_State *L) {
    int n = lua_gettop(L);
    if (n < 2 || !IS_TBL(L->base) || !IS_NUM(L->base + 1)) return 0;
    Table *m = hvalue(L->base);
    lua_Number scale = nvalue(L->base + 1);
    const TValue *rotate = n >= 3 ? L->base + 2 : luaO_nilobject;
    const TValue *offset = n >= 4 ? L->base + 3 : luaO_nilobject;
    lua_Number ts[2];
    if (!tile_size(L, ts)) return 0;
    const TValue *vt = GS(m, K_VT);
    if (!IS_TBL(vt)) return 0;
    Table *VT = hvalue(vt);
    const TValue *vx = GS(VT, K_x), *vy = GS(VT, K_y), *vw = GS(VT, K_w), *vh = GS(VT, K_h), *vr = GS(VT, K_r), *vsc = GS(VT, K_scale);
    if (!IS_NUM(vx) || !IS_NUM(vy) || !IS_NUM(vw) || !IS_NUM(vh) || !IS_NUM(vr) || !IS_NUM(vsc)) return 0;
    lua_Number px, py, ox, oy, rot = 0;
    const TValue *lp = GS(m, K_layered_parallax), *parent = GS(m, K_parent);
    if (!FALSY(parent) && !IS_TBL(parent)) return 0;   /* Lua indexes parent.layered_parallax before using either value */
    if (!parallax_of(lp, parent, K_x, &px) || !parallax_of(lp, parent, K_y, &py)) return 0;
    if (!offset_of(offset, K_x, &ox) || !offset_of(offset, K_y, &oy)) return 0;
    if (!FALSY(rotate)) { if (!IS_NUM(rotate)) return 0; rot = nvalue(rotate); }
    lua_Number r = 0;
    if (nvalue(vr) != 0 || !FALSY(GS(m, K_juice)) || !FALSY(rotate)) r = nvalue(vr) + rot;
    lua_Number vs = nvalue(vsc), w = nvalue(vw), h = nvalue(vh), two = cast_num(2);
    eng_prep_draw((float)(ts[0] * ts[1]),
                  (float)(nvalue(vx) + w / two + ox + px),
                  (float)(nvalue(vy) + h / two + oy + py),
                  (float)r,
                  (float)(-scale * w * vs / two),
                  (float)(-scale * h * vs / two),
                  (float)(vs * scale));
    return 1;
}

static int tc_core(lua_State *L) {
    if (lua_gettop(L) < 1 || !IS_TBL(L->base)) return 0;
    Table *self = hvalue(L->base);
    const TValue *c = GS(self, K_container);
    if (FALSY(c)) return 1;
    if (!IS_TBL(c)) return 0;
    if (hvalue(c) == self) return 1;
    const TValue *t = GS(hvalue(c), K_T);
    if (!IS_TBL(t)) return 0;
    const TValue *tw = GS(hvalue(t), K_w), *th = GS(hvalue(t), K_h), *tr = GS(hvalue(t), K_r), *tx = GS(hvalue(t), K_x), *ty = GS(hvalue(t), K_y);
    if (!IS_NUM(tw) || !IS_NUM(th) || !IS_NUM(tr) || !IS_NUM(tx) || !IS_NUM(ty)) return 0;
    lua_Number ts[2];
    if (!tile_size(L, ts)) return 0;
    lua_Number w = nvalue(tw), h = nvalue(th), half = cast_num(0.5);
    eng_translate_container((float)(w * ts[0] * ts[1] * half),
                            (float)(h * ts[0] * ts[1] * half),
                            (float)nvalue(tr),
                            (float)(-w * ts[0] * ts[1] * half + nvalue(tx) * ts[0] * ts[1]),
                            (float)(-h * ts[0] * ts[1] * half + nvalue(ty) * ts[0] * ts[1]));
    return 1;
}

static int run_ui_fallback(lua_State *L, int ref, const char *what) {
    if (ref == LUA_NOREF) return luaL_error(L, "native.%s needs ui_setup", what);
    int n = lua_gettop(L);
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    lua_insert(L, 1);
    lua_call(L, n, 0);
    return 0;
}
static int l_prep_method(lua_State *L) {
    if (!keys_ready) return luaL_error(L, "native.ui_setup has not run");
    if (prep_core(L)) return 0;
    return run_ui_fallback(L, ref_prep_fb, "prep_method");
}
static int l_tc_method(lua_State *L) {
    if (!keys_ready) return luaL_error(L, "native.ui_setup has not run");
    if (tc_core(L)) return 0;
    return run_ui_fallback(L, ref_tc_fb, "tc_method");
}

int mv_open(lua_State *L) {
    lua_pushcfunction(L, l_mv_setup); lua_setfield(L, -2, "mv_setup");
    lua_pushcfunction(L, l_mv_move); lua_setfield(L, -2, "mv_move");
    lua_pushcfunction(L, l_mv_method); lua_setfield(L, -2, "mv_method");
    lua_pushcfunction(L, l_ui_setup); lua_setfield(L, -2, "ui_setup");
    lua_pushcfunction(L, l_prep_method); lua_setfield(L, -2, "prep_method");
    lua_pushcfunction(L, l_tc_method); lua_setfield(L, -2, "tc_method");
    lua_pushcfunction(L, l_mv_loop); lua_setfield(L, -2, "mv_loop");
    lua_pushcfunction(L, l_mv_update_loop); lua_setfield(L, -2, "mv_update_loop");
    return 0;
}
