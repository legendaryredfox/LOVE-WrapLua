LUAFLOAT ?= -DPSP_LUA_FLOAT
OPT ?= -O2
TARGET = BALATRO
LUADIR = third_party/lua-5.1.5/src
LUA_SRCS = lapi lcode ldebug ldo ldump lfunc lgc llex lmem lobject lopcodes lparser lstate lstring ltable ltm lundump lvm lzio lauxlib lbaselib ldblib liolib lmathlib loslib ltablib lstrlib loadlib linit
OBJS = src/main.o src/engine.o src/audio.o src/lbit.o $(addprefix $(LUADIR)/,$(addsuffix .o,$(LUA_SRCS)))

INCDIR = $(LUADIR)
CFLAGS = $(OPT) -G0 -Wall -DLUA_ANSI $(LUAFLOAT)
CXXFLAGS = $(CFLAGS)
ASFLAGS = $(CFLAGS)
LIBDIR =
LIBS = -lvorbisidec -logg -lpspgu -lpspge -lpspdisplay -lpspctrl -lpsppower -lpspmp3 -lpspaudiocodec -lpspaudio -lpsprtc -lpspvram -lpspmath -lz -lm
LDFLAGS =

BUILD_PRX = 1
PSP_LARGE_MEMORY = 1
EXTRA_TARGETS = EBOOT.PBP
PSP_EBOOT_TITLE = Balatro

PSPSDK = $(shell psp-config --pspsdk-path)
include $(PSPSDK)/lib/build.mak
