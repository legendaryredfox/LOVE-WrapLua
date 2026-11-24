/* The Balatro-shaped fast paths (Moveable, UIBox walk, update gate), registered as native.balatro. They read Balatro's
 * own tables by field name, so they are built only with GAME=balatro (lua tools/lovepsp.lua build --game=balatro). */
#include "lua.h"
#include "lauxlib.h"

int mv_open(lua_State *L);
int uw_open(lua_State *L);
int rr_open(lua_State *L);

int balatro_open(lua_State *L) {
    lua_newtable(L);
    mv_open(L);
    uw_open(L);
    rr_open(L);
    lua_setfield(L, -2, "balatro");
    return 0;
}
