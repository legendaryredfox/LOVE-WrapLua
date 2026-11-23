/* A C version of the per-frame signature walk of the UI layer cache (psp/opt.lua in balatro_psp, section 7): for every
 * element of a UIBox it compares position, size, colour, text, progress and state flags with the values stored in the
 * previous frame's signature array and stores the new ones. Like moveable.c it reads the Lua tables directly through
 * Lua's internal luaH_getstr, so it is tied to the Lua 5.1.5 in third_party/.
 *
 * native.ui_walk(root, sig, start, sigq, uit_object, now) -> next_index, changed
 *   sig            the signature array (positive integer keys); entries from start + 1 on are compared and rewritten
 *   uit_object     the value of G.UIT.O, now the value of G.TIMERS.REAL
 * It returns nothing (nil) when a field is missing or has an unexpected type; sig may then be partly rewritten, so the
 * caller must treat the box as changed and run its own walk. */
#define LUA_CORE
#include "lua.h"
#include "lauxlib.h"
#include "lobject.h"
#include "lstate.h"
#include "ltable.h"
#include "lstring.h"
#include "lgc.h"

enum {
    K_states, K_config, K_UIT, K_VT, K_layered_parallax, K_shadow_parrallax, K_colour, K_x, K_y, K_w, K_h, K_r, K_scale,
    K_text, K_button_delay_progress, K_progress_bar, K_ref_table, K_ref_value, K_chosen, K_hover, K_collide, K_visible, K_focus,
    K_drag, K_is, K_can, K_last_clicked, K_button_UIE, K_button, K_children, K_draw_layer, K_h_popup, K_alert,
    K_COUNT
};
static const char *const key_names[K_COUNT] = {
    "states", "config", "UIT", "VT", "layered_parallax", "shadow_parrallax", "colour", "x", "y", "w", "h", "r", "scale",
    "text", "button_delay_progress", "progress_bar", "ref_table", "ref_value", "chosen", "hover", "collide", "visible", "focus",
    "drag", "is", "can", "last_clicked", "button_UIE", "button", "children", "draw_layer", "h_popup", "alert",
};
static TString *K[K_COUNT];
static int keys_ready = 0;

#define GS(h, k) luaH_getstr((h), K[k])
#define IS_NUM(v) ttisnumber(v)
#define IS_TBL(v) ttistable(v)
#define FALSY(v) (ttisnil(v) || (ttisboolean(v) && bvalue(v) == 0))
#define IS_STR(v, k) (ttisstring(v) && rawtsvalue(v) == K[k])
#define NUM(h, k) nvalue(GS((h), (k)))

typedef struct {
    Table *sig;
    lua_Number sigq, now;
    TValue uit_object;   /* a copy: the Lua stack may be reallocated while walking */
    int diff;
} Ctx;

/* sig[idx] ~= v then sig[idx] = v, diff = true */
static void sig_set(lua_State *L, Ctx *c, int idx, const TValue *v) {
    TValue val = *v;
    const TValue *cur = luaH_getnum(c->sig, idx);
    if (luaO_rawequalObj(cur, &val)) return;
    setobj2t(L, luaH_setnum(L, c->sig, idx), &val);
    c->sig->flags = 0;
    luaC_barriert(L, c->sig, &val);
    c->diff = 1;
}
static void sig_num(lua_State *L, Ctx *c, int idx, lua_Number n) {
    TValue v; setnvalue(&v, n);
    sig_set(L, c, idx, &v);
}
static lua_Number floor_to_int(lua_Number x) { return luai_numsub(x, luai_nummod(x, cast_num(1))); }

#define NEED_TBL(v) do { if (!IS_TBL(v)) return 0; } while (0)
#define NEED_NUM(v) do { if (!IS_NUM(v)) return 0; } while (0)

static int is_true(Table *h, int k) { return !FALSY(GS(h, k)); }

static int walk_node(lua_State *L, Table *node, int *si, Ctx *c, int depth) {
    if (depth > 60) return 0;
    int i = *si;
    const TValue *stv = GS(node, K_states), *cfv = GS(node, K_config);
    NEED_TBL(stv); NEED_TBL(cfv);
    Table *st = hvalue(stv), *cf = hvalue(cfv);
    { TValue nv; sethvalue(L, &nv, node); sig_set(L, c, i + 1, &nv); }

    if (!luaO_rawequalObj(GS(node, K_UIT), &c->uit_object)) {
        const TValue *vtv = GS(node, K_VT), *lpv = GS(node, K_layered_parallax), *spv = GS(node, K_shadow_parrallax);
        const TValue *col = GS(cf, K_colour);
        NEED_TBL(vtv); NEED_TBL(lpv); NEED_TBL(spv);
        Table *VT = hvalue(vtv), *lp = hvalue(lpv), *sp = hvalue(spv);
        NEED_NUM(GS(VT, K_x)); NEED_NUM(GS(VT, K_y)); NEED_NUM(GS(VT, K_w)); NEED_NUM(GS(VT, K_h));
        NEED_NUM(GS(VT, K_r)); NEED_NUM(GS(VT, K_scale));
        NEED_NUM(GS(lp, K_x)); NEED_NUM(GS(lp, K_y)); NEED_NUM(GS(sp, K_x)); NEED_NUM(GS(sp, K_y));
        lua_Number sq = c->sigq;
        lua_Number x = floor_to_int(luai_nummul(NUM(VT, K_x), sq)), y = floor_to_int(luai_nummul(NUM(VT, K_y), sq));
        lua_Number w = floor_to_int(luai_nummul(NUM(VT, K_w), sq)), h = floor_to_int(luai_nummul(NUM(VT, K_h), sq));
        lua_Number rs = luai_numadd(NUM(VT, K_r), luai_nummul(NUM(VT, K_scale), cast_num(1000)));
        sig_num(L, c, i + 2, x); sig_num(L, c, i + 3, y); sig_num(L, c, i + 4, w); sig_num(L, c, i + 5, h); sig_num(L, c, i + 6, rs);
        lua_Number p = luai_numadd(luai_numadd(luai_numadd(NUM(lp, K_x), luai_nummul(NUM(lp, K_y), cast_num(3.1))),
            luai_nummul(NUM(sp, K_x), cast_num(7.3))), luai_nummul(NUM(sp, K_y), cast_num(11.7)));
        sig_num(L, c, i + 7, p);
        lua_Number cn = 0;
        if (!FALSY(col)) {
            if (!IS_TBL(col)) return 0;
            Table *ct = hvalue(col);
            const TValue *c1 = luaH_getnum(ct, 1), *c2 = luaH_getnum(ct, 2), *c3 = luaH_getnum(ct, 3), *c4 = luaH_getnum(ct, 4);
            NEED_NUM(c1); NEED_NUM(c2); NEED_NUM(c3); NEED_NUM(c4);
            cn = luai_numadd(luai_numadd(luai_numadd(nvalue(c1), luai_nummul(nvalue(c2), cast_num(3))),
                luai_nummul(nvalue(c3), cast_num(7))), luai_nummul(nvalue(c4), cast_num(11)));
        }
        sig_num(L, c, i + 8, cn);
        sig_set(L, c, i + 9, GS(cf, K_text));

        /* cf.button_delay_progress or (cf.progress_bar and cf.progress_bar.ref_table[cf.progress_bar.ref_value]) or (cf.chosen and 1) or 0 */
        {
            TValue pr;
            const TValue *bd = GS(cf, K_button_delay_progress);
            if (!FALSY(bd)) pr = *bd;
            else {
                setnilvalue(&pr);
                const TValue *pb = GS(cf, K_progress_bar);
                if (!FALSY(pb)) {
                    if (!IS_TBL(pb)) return 0;
                    const TValue *rt = GS(hvalue(pb), K_ref_table), *rv = GS(hvalue(pb), K_ref_value);
                    if (!IS_TBL(rt) || !ttisstring(rv)) return 0;
                    const TValue *got = luaH_getstr(hvalue(rt), rawtsvalue(rv));
                    if (ttisnil(got) && hvalue(rt)->metatable != NULL) return 0;   /* __index: leave it to Lua */
                    pr = *got;
                }
                if (FALSY(&pr)) {
                    if (!FALSY(GS(cf, K_chosen))) { setnvalue(&pr, cast_num(1)); }
                    else { setnvalue(&pr, cast_num(0)); }
                }
            }
            sig_set(L, c, i + 10, &pr);
        }

        {
            const TValue *hov = GS(st, K_hover), *col_ = GS(st, K_collide), *foc = GS(st, K_focus), *dra = GS(st, K_drag);
            NEED_TBL(hov); NEED_TBL(col_); NEED_TBL(foc); NEED_TBL(dra);
            lua_Number b = 0;
            if (is_true(hvalue(hov), K_is)) b = luai_numadd(b, cast_num(1));
            if (is_true(hvalue(col_), K_can)) b = luai_numadd(b, cast_num(2));
            if (is_true(st, K_visible)) b = luai_numadd(b, cast_num(4));
            if (is_true(hvalue(foc), K_is)) b = luai_numadd(b, cast_num(8));
            if (is_true(hvalue(dra), K_is)) b = luai_numadd(b, cast_num(16));
            {
                const TValue *lc = GS(node, K_last_clicked);
                if (!FALSY(lc)) {
                    NEED_NUM(lc);
                    if (nvalue(lc) > luai_numsub(c->now, cast_num(0.1))) b = luai_numadd(b, cast_num(32));
                }
            }
            const TValue *bu = GS(cf, K_button_UIE);
            if (!FALSY(bu)) {
                NEED_TBL(bu);
                const TValue *bst = GS(hvalue(bu), K_states), *bcf = GS(hvalue(bu), K_config);
                NEED_TBL(bst); NEED_TBL(bcf);
                const TValue *bh = GS(hvalue(bst), K_hover);
                NEED_TBL(bh);
                b = luai_numadd(b, cast_num(64));
                if (is_true(hvalue(bh), K_is)) b = luai_numadd(b, cast_num(128));
                if (is_true(hvalue(bcf), K_button)) b = luai_numadd(b, cast_num(256));
            }
            sig_num(L, c, i + 11, b);
        }
        *si = i + 11;
    } else {
        sig_set(L, c, i + 2, GS(st, K_visible));
        *si = i + 2;
    }

    if (is_true(st, K_visible)) {
        const TValue *chv = GS(node, K_children);
        NEED_TBL(chv);
        if (!lua_checkstack(L, 6)) return 0;
        sethvalue(L, L->top, hvalue(chv)); L->top++;
        lua_pushnil(L);
        while (lua_next(L, -2)) {
            const TValue *kv = L->top - 2, *vv = L->top - 1;
            if (!IS_TBL(vv)) return 0;
            Table *v = hvalue(vv);
            const TValue *vc = GS(v, K_config);
            if (!IS_TBL(vc)) return 0;
            if (FALSY(GS(hvalue(vc), K_draw_layer)) && !IS_STR(kv, K_h_popup) && !IS_STR(kv, K_alert) && !FALSY(GS(v, K_states))) {
                if (!walk_node(L, v, si, c, depth + 1)) return 0;
            }
            lua_pop(L, 1);
        }
        lua_pop(L, 1);
    }
    return 1;
}

static int l_ui_walk(lua_State *L) {
    if (!keys_ready) {
        lua_newtable(L);
        for (int i = 0; i < K_COUNT; i++) {
            lua_pushstring(L, key_names[i]);
            K[i] = rawtsvalue(L->top - 1);
            lua_rawseti(L, -2, i + 1);
        }
        lua_setfield(L, LUA_REGISTRYINDEX, "uw.keys");
        keys_ready = 1;
    }
    int top0 = lua_gettop(L);
    if (top0 < 6 || !IS_TBL(L->base) || !IS_TBL(L->base + 1) || !lua_isnumber(L, 3) || !lua_isnumber(L, 4) || !lua_isnumber(L, 6)) return 0;
    Ctx c;
    c.sig = hvalue(L->base + 1);
    c.sigq = lua_tonumber(L, 4);
    c.now = lua_tonumber(L, 6);
    c.uit_object = L->base[4];
    c.diff = 0;
    int si = (int)lua_tonumber(L, 3);
    if (!walk_node(L, hvalue(L->base), &si, &c, 0)) { lua_settop(L, top0); return 0; }
    lua_settop(L, top0);
    lua_pushinteger(L, si);
    lua_pushboolean(L, c.diff);
    return 2;
}

int uw_open(lua_State *L) {
    lua_pushcfunction(L, l_ui_walk); lua_setfield(L, -2, "ui_walk");
    return 0;
}
