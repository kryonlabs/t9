CC ?= cc
ENGINE_DIR ?= ../kryon
BUILD_ROOT ?= build
KRYON_BACKEND ?= raylib
PLAN9PORT_DIR ?= /mnt/storage/Projects/plan9port
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
RILL_APP_HOSTDIR ?= $(PREFIX)/lib/rill/apps
APPDIR ?= $(PREFIX)/share/applications
INSTALL ?= install

UNAME_S := $(shell uname -s 2>/dev/null)
UNAME_M := $(shell uname -m 2>/dev/null)
ifeq ($(UNAME_M),amd64)
    ARCH := x86_64
else
    ARCH := $(UNAME_M)
endif
ifeq ($(UNAME_S),Linux)
    PLATFORM := linux
else ifeq ($(UNAME_S),FreeBSD)
    PLATFORM := freebsd
else ifeq ($(UNAME_S),Darwin)
    PLATFORM := macos
else
    PLATFORM := $(UNAME_S)
endif

BUILD_DIR ?= $(BUILD_ROOT)/$(PLATFORM)-$(ARCH)
ENGINE_BUILD_ROOT ?= $(ENGINE_DIR)/build
ENGINE_BUILD_DIR ?= $(ENGINE_BUILD_ROOT)/$(PLATFORM)-$(ARCH)
ENGINE_LIB = $(ENGINE_BUILD_DIR)/libkryon.a
ENGINE_K2C = $(ENGINE_BUILD_DIR)/bin/k2c
PANE_C_FILES := $(sort $(wildcard src/terminal_pane/*.c))
PANE_C_OBJS := $(patsubst src/%.c,$(BUILD_DIR)/src/%.o,$(PANE_C_FILES))
PANE_KRY := $(sort $(wildcard src/terminal_pane/*.kry))
PANE_KRY_C := $(patsubst src/%.kry,$(BUILD_DIR)/generated/src/%.c,$(PANE_KRY))
PANE_KRY_H := $(PANE_KRY_C:.c=.h)
PANE_KRY_OBJS := $(PANE_KRY_C:.c=.o)
PANE_RUNTIME_C = $(BUILD_DIR)/generated/src/runtime/terminal_pane.c
PANE_RUNTIME_H = $(PANE_RUNTIME_C:.c=.h)
PANE_RUNTIME_OBJ = $(PANE_RUNTIME_C:.c=.o)
PANE_OBJS = $(PANE_C_OBJS) $(PANE_KRY_OBJS) $(PANE_RUNTIME_OBJ)
ENGINE_KRY := $(sort $(wildcard src/engine/*.kry))
ENGINE_KRY_C := $(patsubst src/%.kry,$(BUILD_DIR)/generated/src/%.c,$(ENGINE_KRY))
ENGINE_KRY_H := $(ENGINE_KRY_C:.c=.h)
ENGINE_KRY_OBJS := $(ENGINE_KRY_C:.c=.o)
APP_KRY := $(sort $(wildcard src/app/*.kry))
APP_KRY_C := $(patsubst src/%.kry,$(BUILD_DIR)/generated/src/%.c,$(APP_KRY))
APP_KRY_H := $(APP_KRY_C:.c=.h)
APP_KRY_OBJS := $(APP_KRY_C:.c=.o)
RAYLIB_A = $(ENGINE_BUILD_DIR)/raylib/libraylib.a
LIBOQS_A = $(ENGINE_BUILD_DIR)/vendor/liboqs/lib/liboqs.a
CURL_A = $(ENGINE_BUILD_DIR)/vendor/curl/lib/libcurl.a
CMARK_A = $(ENGINE_BUILD_DIR)/vendor/cmark-gfm/src/libcmark-gfm.a
CMARK_EXT_A = $(ENGINE_BUILD_DIR)/vendor/cmark-gfm/extensions/libcmark-gfm-extensions.a
BOX2D_A = $(ENGINE_BUILD_DIR)/vendor/box2d/src/libbox2d.a

APP = $(BUILD_DIR)/bin/t9
HOST_LIB = $(BUILD_DIR)/lib/libt9_host.a
HOST_SO = $(BUILD_DIR)/lib/t9-host.so
TEST = $(BUILD_DIR)/tests/terminal_test
SIMPLE_TEST = $(BUILD_DIR)/tests/simple_terminal_test
PANE_POLICY_TEST = $(BUILD_DIR)/tests/terminal_pane_policy_test
PANE_SELECTION_TEST = $(BUILD_DIR)/tests/terminal_pane_selection_test
PROCESS_TEST = $(BUILD_DIR)/tests/process_test
PARSER_BENCH = $(BUILD_DIR)/benchmarks/parser_replay
SRC_FILES := $(filter-out src/terminal_pty_plan9.c,$(wildcard src/*.c))
OBJS = $(patsubst src/%.c,$(BUILD_DIR)/src/%.o,$(SRC_FILES)) $(PANE_OBJS) $(ENGINE_KRY_OBJS) $(APP_KRY_OBJS)
HOST_SRC_FILES := $(filter-out src/main.c,$(SRC_FILES))
HOST_OBJS = $(patsubst src/%.c,$(BUILD_DIR)/src/%.o,$(HOST_SRC_FILES)) $(PANE_OBJS) $(ENGINE_KRY_OBJS) $(APP_KRY_OBJS)
# Pick a module's object from its .kry port when present, else its C file.
mod_obj = $(if $(wildcard src/engine/$(1).kry),$(BUILD_DIR)/generated/src/engine/$(1).o,$(if $(wildcard src/app/$(1).kry),$(BUILD_DIR)/generated/src/app/$(1).o,$(BUILD_DIR)/src/$(1).o))
TEST_OBJS = $(BUILD_DIR)/tests/terminal_test.o $(call mod_obj,app_config) \
	$(call mod_obj,app_launch_options) \
	$(call mod_obj,terminal_state) \
	$(call mod_obj,csi) \
	$(call mod_obj,modes) \
	$(call mod_obj,keys) $(call mod_obj,paste) \
	$(call mod_obj,mouse) $(call mod_obj,search) \
	$(call mod_obj,view) $(call mod_obj,osc) \
	$(call mod_obj,sixel) $(call mod_obj,dcs) \
	$(call mod_obj,sgr) $(call mod_obj,screen) \
	$(call mod_obj,text) \
	$(call mod_obj,parser) \
	$(BUILD_DIR)/src/terminal_pty.o \
	$(call mod_obj,process) \
	$(call mod_obj,app_session) \
	$(call mod_obj,app_input) $(call mod_obj,app_selection) \
	$(call mod_obj,app_session_store) $(call mod_obj,app_profile) \
	$(call mod_obj,app_palette) $(call mod_obj,app_sessions) \
	$(call mod_obj,app_chrome) $(call mod_obj,app_commands) \
	$(call mod_obj,app_clipboard) $(call mod_obj,app_search)
PARSER_BENCH_OBJS = $(BUILD_DIR)/benchmarks/parser_replay.o \
	$(call mod_obj,terminal_state) \
	$(call mod_obj,csi) \
	$(call mod_obj,modes) \
	$(call mod_obj,keys) $(call mod_obj,paste) \
	$(call mod_obj,mouse) $(call mod_obj,search) \
	$(call mod_obj,view) $(call mod_obj,osc) \
	$(call mod_obj,sixel) $(call mod_obj,dcs) \
	$(call mod_obj,sgr) $(call mod_obj,screen) \
	$(call mod_obj,text) \
	$(call mod_obj,parser) \
	$(BUILD_DIR)/src/terminal_pty.o \
	$(call mod_obj,process)

RAY_SDL_CFLAGS ?= $(shell pkg-config --cflags sdl2 2>/dev/null)
RAY_SDL_LDLIBS ?= $(shell pkg-config --libs sdl2 2>/dev/null)
RAY_GL_CFLAGS ?= $(shell pkg-config --cflags libdrm gbm egl glesv2 2>/dev/null)
RAY_GL_LDLIBS ?= $(shell pkg-config --libs libdrm gbm egl glesv2 2>/dev/null)
RAY_LDLIBS ?= $(strip $(RAY_SDL_LDLIBS) $(RAY_GL_LDLIBS))
ifeq ($(KRYON_BACKEND),raylib)
BACKEND_CFLAGS = $(RAY_SDL_CFLAGS) $(RAY_GL_CFLAGS)
BACKEND_LIBS = $(RAYLIB_A)
BACKEND_LDLIBS = $(RAY_LDLIBS)
else ifeq ($(KRYON_BACKEND),libdraw)
BACKEND_CFLAGS = -DKRYON_BACKEND_LIBDRAW -I$(PLAN9PORT_DIR)/include
BACKEND_LIBS =
BACKEND_LDLIBS = -L$(PLAN9PORT_DIR)/lib -ldraw -lmemdraw -lmux -lthread -l9
else
$(error Unknown KRYON_BACKEND '$(KRYON_BACKEND)' (expected raylib or libdraw))
endif
SYSTEM_THEME_PKG := $(shell if pkg-config --exists gtk+-3.0 2>/dev/null; then printf '%s' gtk+-3.0; fi)
SYSTEM_THEME_CFLAGS := $(shell if [ -n "$(SYSTEM_THEME_PKG)" ]; then pkg-config --cflags $(SYSTEM_THEME_PKG); fi)
SYSTEM_THEME_LDLIBS := $(shell if [ -n "$(SYSTEM_THEME_PKG)" ]; then pkg-config --libs $(SYSTEM_THEME_PKG); fi)
CURL_CODEC_LDLIBS ?= $(strip \
  $(shell pkg-config --libs libbrotlidec 2>/dev/null) \
  $(shell pkg-config --libs libbrotlicommon 2>/dev/null) \
  $(shell pkg-config --libs libzstd 2>/dev/null))
ifeq ($(PLATFORM),linux)
PLATFORM_LDLIBS ?= -ldl -lrt
else
PLATFORM_LDLIBS ?=
endif

CFLAGS ?= -Wall -Wextra -O2
ifeq ($(PLATFORM),linux)
  CFLAGS += -fPIC
endif
CPPFLAGS += -Isrc -I$(ENGINE_DIR)/include -I$(ENGINE_DIR)/src/ui \
	-I$(ENGINE_DIR)/vendor/utf8proc \
	-I$(BUILD_DIR)/generated/src -I$(ENGINE_BUILD_DIR)/generated/src \
	-I$(ENGINE_BUILD_DIR)/generated/src/runtime \
	-I$(ENGINE_BUILD_DIR)/generated/include \
	$(BACKEND_CFLAGS) $(SYSTEM_THEME_CFLAGS) \
	-DKTREM_KRYON_FONT_PATH=\"$(abspath $(ENGINE_DIR))/fonts/noto/NotoSans-Regular.ttf\" \
	-DHAS_LIBOQS=1 -I$(ENGINE_BUILD_DIR)/vendor/liboqs/include \
	-DHAS_LIBCURL=1 -DCURL_STATICLIB -I$(ENGINE_BUILD_DIR)/vendor/curl/include \
	-DKRYON_HAS_CMARK_GFM=1 \
	-I$(ENGINE_DIR)/vendor/cmark-gfm/src -I$(ENGINE_DIR)/vendor/cmark-gfm/extensions \
	-I$(ENGINE_BUILD_DIR)/vendor/cmark-gfm/src -I$(ENGINE_BUILD_DIR)/vendor/cmark-gfm/extensions
LDLIBS += $(BACKEND_LIBS) $(BOX2D_A) $(BACKEND_LDLIBS) $(LIBOQS_A) \
	$(CURL_A) -lssl -lcrypto -lpthread $(CMARK_EXT_A) $(CMARK_A) \
	$(SYSTEM_THEME_LDLIBS) $(CURL_CODEC_LDLIBS) -lz -lm $(PLATFORM_LDLIBS)

.PHONY: all run test benchmark-parser clean install engine

all: $(APP) $(HOST_LIB) $(HOST_SO)

engine:
	$(MAKE) -C $(ENGINE_DIR) KRYON_BACKEND=$(KRYON_BACKEND) \
		BUILD_ROOT=$(ENGINE_BUILD_ROOT) $(ENGINE_LIB) $(ENGINE_K2C)

$(PANE_RUNTIME_C) $(PANE_RUNTIME_H) &: runtime/terminal_pane.kry | engine
	$(ENGINE_K2C) --strict --no-main --root . -o $(BUILD_DIR)/generated/src $<

$(PANE_KRY_C) $(PANE_KRY_H) $(ENGINE_KRY_C) $(ENGINE_KRY_H) $(APP_KRY_C) $(APP_KRY_H) &: $(PANE_KRY) $(ENGINE_KRY) $(APP_KRY) $(PANE_RUNTIME_H) | engine
	$(ENGINE_K2C) --no-main --root src -o $(BUILD_DIR)/generated/src $(PANE_KRY) $(ENGINE_KRY) $(APP_KRY)

$(BUILD_DIR)/generated/src/%.o: $(BUILD_DIR)/generated/src/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CPPFLAGS) -fPIC -c $< -o $@

$(APP): engine $(OBJS) $(ENGINE_LIB) $(BACKEND_LIBS) | $(BUILD_DIR)/bin
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ $(OBJS) \
		-Wl,--whole-archive $(ENGINE_LIB) -Wl,--no-whole-archive \
		$(LDLIBS)

$(HOST_LIB): engine $(HOST_OBJS) | $(BUILD_DIR)/lib
	ar rcs $@ $(HOST_OBJS)

$(HOST_SO): engine $(HOST_OBJS) | $(BUILD_DIR)/lib
	$(CC) $(CFLAGS) -shared -o $@ $(HOST_OBJS)

# The engine test stubs the pane widget's theme entry points so it runs
# headless; keep the real widget object out of that link. Other pane objects
# pull libkryon members that also define the clipboard/input/theme functions
# the test stubs; link order keeps the test's stubs authoritative.
PANE_TEST_OBJS = $(filter-out %/terminal_pane_widget.o,$(PANE_OBJS))

$(TEST): engine $(TEST_OBJS) $(PANE_TEST_OBJS) $(ENGINE_LIB) $(BACKEND_LIBS) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) $(CPPFLAGS) -Wl,--allow-multiple-definition -o $@ \
		$(TEST_OBJS) \
		$(PANE_TEST_OBJS) $(ENGINE_LIB) $(LDLIBS)

$(SIMPLE_TEST): engine $(BUILD_DIR)/tests/simple_terminal_test.o \
	$(BUILD_DIR)/src/terminal_pane/simple_terminal.o | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ $(BUILD_DIR)/tests/simple_terminal_test.o \
		$(BUILD_DIR)/src/terminal_pane/simple_terminal.o

$(PANE_POLICY_TEST): engine $(BUILD_DIR)/tests/terminal_pane_policy_test.o \
	$(PANE_OBJS) $(ENGINE_LIB) $(BACKEND_LIBS) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ \
		$(BUILD_DIR)/tests/terminal_pane_policy_test.o \
		$(PANE_OBJS) -Wl,--whole-archive $(ENGINE_LIB) \
		-Wl,--no-whole-archive $(LDLIBS)

$(PROCESS_TEST): engine $(BUILD_DIR)/tests/process_test.o \
	$(ENGINE_CLIPBOARD_OBJ) \
	$(call mod_obj,app_config) $(call mod_obj,app_launch_options) \
	$(ENGINE_KRY_OBJS) $(BUILD_DIR)/src/terminal_pty.o \
	$(PANE_OBJS) $(ENGINE_LIB) $(BACKEND_LIBS) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ \
		$(BUILD_DIR)/tests/process_test.o $(ENGINE_CLIPBOARD_OBJ) \
		$(call mod_obj,app_config) $(call mod_obj,app_launch_options) \
		$(ENGINE_KRY_OBJS) $(BUILD_DIR)/src/terminal_pty.o \
		$(PANE_OBJS) $(ENGINE_LIB) $(LDLIBS)

$(PANE_SELECTION_TEST): engine $(BUILD_DIR)/tests/terminal_pane_selection_test.o \
	$(PANE_OBJS) $(ENGINE_LIB) $(BACKEND_LIBS) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ \
		$(BUILD_DIR)/tests/terminal_pane_selection_test.o \
		$(PANE_OBJS) \
		-Wl,--whole-archive $(ENGINE_LIB) \
		-Wl,--no-whole-archive $(LDLIBS)

$(PARSER_BENCH): engine $(PARSER_BENCH_OBJS) $(PANE_OBJS) $(ENGINE_LIB) $(BACKEND_LIBS) | $(BUILD_DIR)/benchmarks
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ $(PARSER_BENCH_OBJS) $(PANE_OBJS) \
		-Wl,--whole-archive $(ENGINE_LIB) -Wl,--no-whole-archive \
		$(LDLIBS)

$(BUILD_DIR)/src/%.o: src/%.c src/*.h | $(BUILD_DIR)/src
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

$(BUILD_DIR)/tests/%.o: tests/%.c src/terminal.h | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

$(BUILD_DIR)/benchmarks/%.o: benchmarks/%.c src/terminal.h | $(BUILD_DIR)/benchmarks
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

$(BUILD_DIR)/bin $(BUILD_DIR)/lib $(BUILD_DIR)/src $(BUILD_DIR)/tests $(BUILD_DIR)/benchmarks:
	mkdir -p $@

run: $(APP)
	$(APP)

test: $(TEST) $(SIMPLE_TEST) $(PANE_POLICY_TEST) $(PANE_SELECTION_TEST) $(PROCESS_TEST)
	$(TEST)
	$(SIMPLE_TEST)
	$(PANE_POLICY_TEST)
	$(PANE_SELECTION_TEST)
	$(PROCESS_TEST)

benchmark-parser: $(PARSER_BENCH)
	$(PARSER_BENCH)

install: $(APP) $(HOST_SO)
	mkdir -p $(DESTDIR)$(BINDIR) $(DESTDIR)$(RILL_APP_HOSTDIR) $(DESTDIR)$(APPDIR)
	$(INSTALL) -m 755 $(APP) $(DESTDIR)$(BINDIR)/t9
	$(INSTALL) -m 755 $(HOST_SO) $(DESTDIR)$(RILL_APP_HOSTDIR)/t9-host.so
	{ \
		printf '%s\n' '[Desktop Entry]'; \
		printf '%s\n' 'Type=Application'; \
		printf '%s\n' 'Name=Terminal'; \
		printf '%s\n' 'Comment=Kryon terminal emulator'; \
		printf '%s\n' 'Exec=$(BINDIR)/t9'; \
		printf '%s\n' 'Icon=utilities-terminal'; \
		printf '%s\n' 'Terminal=false'; \
		printf '%s\n' 'Categories=System;TerminalEmulator;'; \
		printf '%s\n' 'Keywords=terminal;shell;t9;'; \
		printf '%s\n' 'StartupNotify=true'; \
	} > $(DESTDIR)$(APPDIR)/t9.desktop
	if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database $(DESTDIR)$(APPDIR); fi

clean:
	rm -rf $(BUILD_ROOT)

# Native Plan 9 preparation. The guest compiler cannot run k2c, so the
# .kry app modules are emitted ahead of time as 8c-safe C into
# build/plan9/generated with the file list the mkfile consumes. Run on
# the host whenever any .kry changes before a native build (and prepare
# the Kryon library's own build/plan9 with `make kry-c-plan9` there).
PLAN9_PREP_DIR = build/plan9
PLAN9_GENERATED = $(PLAN9_PREP_DIR)/generated
PLAN9_FILE_LIST = $(PLAN9_PREP_DIR)/generated-c-files.txt

.PHONY: kry-c-plan9
kry-c-plan9: engine
	rm -rf $(PLAN9_GENERATED)
	mkdir -p $(PLAN9_PREP_DIR)
	$(ENGINE_K2C) --plan9 --strict --no-main --root $(abspath .) \
		-o $(PLAN9_GENERATED) runtime/terminal_pane.kry
	$(ENGINE_K2C) --plan9 --no-main --root $(abspath src) \
		-o $(PLAN9_GENERATED) $(PANE_KRY) $(ENGINE_KRY) $(APP_KRY)
	find $(PLAN9_GENERATED) -type f -name '*.c' | LC_ALL=C sort > $(PLAN9_FILE_LIST)
