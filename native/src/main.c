/* Balatro PSP: native host. Boots Lua 5.1 and runs boot.lua next to the EBOOT. */
#include <pspkernel.h>
#include <pspdebug.h>
#include <pspdisplay.h>
#include <pspgu.h>
#include <pspgum.h>
#include <pspctrl.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

PSP_MODULE_INFO("Balatro", 0, 1, 0);
PSP_MAIN_THREAD_ATTR(THREAD_ATTR_USER | THREAD_ATTR_VFPU);
PSP_HEAP_SIZE_KB(-1024);
#include <pspgu.h>

int luaopen_bit(lua_State *L);

static FILE *logf_ = NULL;
/* crash forensics: append + close on every step so the line survives a hard power-off */
static void step(const char *m) { FILE *f = fopen("native_log.txt", "a"); if (f) { fprintf(f, "step %s\n", m); fclose(f); } }
void engine_gu_init(void);
int luaopen_native(lua_State *L);

static int exit_cb(int a1, int a2, void *c) { sceKernelExitGame(); return 0; }
static int cb_thread(SceSize args, void *argp) {
    int cb = sceKernelCreateCallback("exit", exit_cb, NULL);
    sceKernelRegisterExitCallback(cb);
    sceKernelSleepThreadCB();
    return 0;
}
static void setup_callbacks(void) {
    int t = sceKernelCreateThread("cb", cb_thread, 0x11, 0xFA0, 0, NULL);
    if (t >= 0) sceKernelStartThread(t, 0, NULL);
}

int main(int argc, char *argv[]) {
    setup_callbacks();
    /* run relative to the EBOOT directory so game files resolve */
    if (argc > 0 && argv[0]) {
        char dir[256]; strncpy(dir, argv[0], sizeof dir - 1); dir[sizeof dir - 1] = 0;
        char *s = strrchr(dir, '/'); if (s) { s[1] = 0; chdir(dir); }
    }
    logf_ = fopen("native_log.txt", "w");
    if (logf_) { fprintf(logf_, "boot argv0=%s\n", argc > 0 ? argv[0] : "?"); fflush(logf_); }
    if (logf_) { fclose(logf_); logf_ = NULL; }
    step("gu_init begin");
    engine_gu_init();
    step("gu_init done");
    lua_State *L = luaL_newstate();
    step("newstate");
    luaL_openlibs(L);
    luaopen_bit(L); lua_pop(L, 1);
    luaopen_native(L); lua_pop(L, 1);
    step("libs open; running boot.lua");

    if (luaL_dofile(L, "boot.lua") != 0) {
        const char *err = lua_tostring(L, -1);
        { FILE *f = fopen("native_log.txt", "a"); if (f) { fprintf(f, "boot.lua error: %s\n", err ? err : "?"); fclose(f); } }
        /* keep the screen alive so the failure is visible/screenshot-able */
        for (int i = 0; i < 600; i++) {
            sceDisplayWaitVblankStart();
        }
    }
    lua_close(L);
    if (logf_) fclose(logf_);
    sceKernelExitGame();
    return 0;
}
