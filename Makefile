CC ?= cc
.DEFAULT_GOAL := all
ZIRAN ?= ./scripts/ziran.sh
LOCK_FLAGS := $(if $(wildcard ziran.local.toml),,--locked)
ENGINE_DIR ?= $(shell $(ZIRAN) pkg path kryon $(LOCK_FLAGS))
ZIRAN_DIR ?= $(shell $(ZIRAN) pkg path ziran $(LOCK_FLAGS))
BUILD_ROOT ?= build
KRYON_BACKEND ?= raylib
PLAN9PORT_DIR ?= $(PLAN9)
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
KRYON_FONT_PATH ?= $(firstword $(wildcard $(ENGINE_DIR)/assets/fonts/LiberationSans-Regular.ttf $(ENGINE_DIR)/fonts/noto/NotoSans-Regular.ttf))
PANE_C_FILES := $(sort $(wildcard src/terminal_pane/*.c))
PANE_C_OBJS := $(patsubst src/%.c,$(BUILD_DIR)/src/%.o,$(PANE_C_FILES))
PANE_KRY := $(sort $(wildcard src/terminal_pane/*.kry))
PANE_KRY_C := $(patsubst src/%.kry,$(BUILD_DIR)/generated/src/%.c,$(PANE_KRY))
PANE_KRY_H := $(PANE_KRY_C:.c=.h)
PANE_KRY_OBJS := $(PANE_KRY_C:.c=.o)
PANE_ZI := $(sort $(wildcard src/terminal_pane/*.zi))
PANE_ZI_C := $(patsubst src/%.zi,$(BUILD_DIR)/generated/src/%.c,$(PANE_ZI))
PANE_ZI_H := $(PANE_ZI_C:.c=.h)
PANE_ZI_OBJS := $(PANE_ZI_C:.c=.o)
PANE_OBJS = $(PANE_C_OBJS) $(PANE_KRY_OBJS) $(PANE_ZI_OBJS)
PTY_GEN := $(BUILD_DIR)/generated/pty
PTY_MODULES := terminal_pty_linux std_byte_text_linux std_c_string
PTY_C := $(addprefix $(PTY_GEN)/,$(addsuffix .c,$(PTY_MODULES)))
PTY_OBJS := $(PTY_C:.c=.o)
TERMINAL_GEN := $(BUILD_DIR)/generated/terminal
TERMINAL_LIB := $(BUILD_DIR)/lib/libt9_terminal.a
PANE_GEN := $(BUILD_DIR)/generated/pane
PANE_LIB := $(BUILD_DIR)/lib/libt9_pane.a
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
PANE_SELECTION_TEST = $(BUILD_DIR)/tests/terminal_pane_selection_test
PANE_TEXT_TEST = $(BUILD_DIR)/tests/terminal_pane_text_test
PANE_TEXT_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_text
PANE_TEXT_TEST_C = $(PANE_TEXT_TEST_GEN)/terminal_pane_text.c \
	$(PANE_TEXT_TEST_GEN)/terminal_pane_text_test.c
PANE_SGR_TEST = $(BUILD_DIR)/tests/terminal_pane_sgr_test
PANE_SGR_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_sgr
PANE_SGR_TEST_C = $(PANE_SGR_TEST_GEN)/terminal_pane_sgr.c \
	$(PANE_SGR_TEST_GEN)/terminal_pane_sgr_test.c
PANE_CSI_TEST = $(BUILD_DIR)/tests/terminal_pane_csi_test
PANE_CSI_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_csi
PANE_CSI_TEST_C = $(PANE_CSI_TEST_GEN)/terminal_pane_csi.c \
	$(PANE_CSI_TEST_GEN)/terminal_pane_csi_test.c
PANE_MODES_TEST = $(BUILD_DIR)/tests/terminal_pane_modes_test
PANE_MODES_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_modes
PANE_MODES_TEST_C = $(PANE_MODES_TEST_GEN)/terminal_pane_modes.c \
	$(PANE_MODES_TEST_GEN)/terminal_pane_modes_test.c
PANE_MOUSE_TEST = $(BUILD_DIR)/tests/terminal_pane_mouse_test
PANE_MOUSE_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_mouse
PANE_MOUSE_TEST_C = $(PANE_MOUSE_TEST_GEN)/terminal_pane_mouse.c \
	$(PANE_MOUSE_TEST_GEN)/terminal_pane_mouse_test.c
PANE_DCS_TEST = $(BUILD_DIR)/tests/terminal_pane_dcs_test
PANE_DCS_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_dcs
PANE_DCS_TEST_C = $(PANE_DCS_TEST_GEN)/terminal_pane_dcs.c \
	$(PANE_DCS_TEST_GEN)/terminal_pane_dcs_test.c
PANE_SIXEL_TEST = $(BUILD_DIR)/tests/terminal_pane_sixel_test
PANE_SIXEL_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_sixel
PANE_SIXEL_TEST_C = $(PANE_SIXEL_TEST_GEN)/terminal_pane_profile_types.c \
	$(PANE_SIXEL_TEST_GEN)/terminal_pane_profile_colors.c \
	$(PANE_SIXEL_TEST_GEN)/terminal_pane_sixel.c \
	$(PANE_SIXEL_TEST_GEN)/terminal_pane_sixel_test.c
PANE_PROFILE_COLORS_TEST = $(BUILD_DIR)/tests/terminal_pane_profile_colors_test
PANE_PROFILE_COLORS_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_profile_colors
PANE_PROFILE_COLORS_TEST_C = $(PANE_PROFILE_COLORS_TEST_GEN)/terminal_pane_profile_types.c \
	$(PANE_PROFILE_COLORS_TEST_GEN)/terminal_pane_profile_colors.c \
	$(PANE_PROFILE_COLORS_TEST_GEN)/terminal_pane_profile_colors_test.c
PANE_PROFILE_TEST = $(BUILD_DIR)/tests/terminal_pane_profile_test
PANE_PROFILE_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_profile
PANE_PROFILE_TEST_C = $(PANE_PROFILE_TEST_GEN)/terminal_pane_profile_types.c \
	$(PANE_PROFILE_TEST_GEN)/terminal_pane_profile_colors.c \
	$(PANE_PROFILE_TEST_GEN)/terminal_pane_profile.c \
	$(PANE_PROFILE_TEST_GEN)/terminal_pane_profile_test.c
PANE_PROFILE_PROMPT_TEST = $(BUILD_DIR)/tests/terminal_pane_profile_prompt_test
PANE_PROFILE_PROMPT_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_profile_prompt
PANE_PROFILE_PROMPT_TEST_C = $(PANE_PROFILE_PROMPT_TEST_GEN)/terminal_pane_profile_types.c \
	$(PANE_PROFILE_PROMPT_TEST_GEN)/terminal_pane_profile_colors.c \
	$(PANE_PROFILE_PROMPT_TEST_GEN)/terminal_pane_profile.c \
	$(PANE_PROFILE_PROMPT_TEST_GEN)/terminal_pane_profile_settings.c \
	$(PANE_PROFILE_PROMPT_TEST_GEN)/terminal_pane_profile_prompt.c \
	$(PANE_PROFILE_PROMPT_TEST_GEN)/terminal_pane_profile_prompt_test.c
PANE_PROFILE_SETTINGS_TEST = $(BUILD_DIR)/tests/terminal_pane_profile_settings_test
PANE_PROFILE_SETTINGS_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_profile_settings
PANE_PROFILE_SETTINGS_TEST_C = $(PANE_PROFILE_SETTINGS_TEST_GEN)/terminal_pane_profile_types.c \
	$(PANE_PROFILE_SETTINGS_TEST_GEN)/terminal_pane_profile_colors.c \
	$(PANE_PROFILE_SETTINGS_TEST_GEN)/terminal_pane_profile.c \
	$(PANE_PROFILE_SETTINGS_TEST_GEN)/terminal_pane_profile_settings.c \
	$(PANE_PROFILE_SETTINGS_TEST_GEN)/terminal_pane_profile_settings_test.c
PANE_SESSION_TEST = $(BUILD_DIR)/tests/terminal_pane_session_test
PANE_SESSION_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_session
PANE_SESSION_TEST_C = $(PANE_SESSION_TEST_GEN)/terminal_pane_session.c \
	$(PANE_SESSION_TEST_GEN)/terminal_pane_session_test.c
PANE_REFLOW_TEST = $(BUILD_DIR)/tests/terminal_pane_reflow_test
PANE_REFLOW_TEST_GEN = $(BUILD_DIR)/generated/tests/terminal_pane_reflow
PANE_REFLOW_TEST_C = $(PANE_REFLOW_TEST_GEN)/terminal_pane_reflow.c \
	$(PANE_REFLOW_TEST_GEN)/terminal_pane_reflow_test.c
PROCESS_TEST = $(BUILD_DIR)/tests/process_test
PARSER_BENCH = $(BUILD_DIR)/benchmarks/parser_replay
SRC_FILES := $(wildcard src/*.c)
OBJS = $(patsubst src/%.c,$(BUILD_DIR)/src/%.o,$(SRC_FILES)) $(PTY_OBJS) $(PANE_OBJS) $(APP_KRY_OBJS)
HOST_SRC_FILES := $(filter-out src/main.c,$(SRC_FILES))
HOST_OBJS = $(patsubst src/%.c,$(BUILD_DIR)/src/%.o,$(HOST_SRC_FILES)) $(PTY_OBJS) $(PANE_OBJS) $(APP_KRY_OBJS)
# Remaining legacy application tests stay unavailable until their typed
# application state and UI are migrated alongside the current Terminal API.
mod_obj = $(if $(wildcard src/app/$(1).kry),$(BUILD_DIR)/generated/src/app/$(1).o,$(BUILD_DIR)/src/$(1).o)
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
	$(PTY_OBJS) \
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
	$(PTY_OBJS) \
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
	-DKTREM_KRYON_FONT_PATH=\"$(KRYON_FONT_PATH)\" \
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
	@test -f "$(ENGINE_DIR)/include/kryon.h" || \
		{ printf '%s\n' 't9: full application builds still require legacy Kryon/k2c APIs.' \
		'Use make pane-ziran-test with current Ziran; see docs/ZIRAN_MIGRATION.md.' >&2; exit 1; }
	$(MAKE) -C $(ENGINE_DIR) KRYON_BACKEND=$(KRYON_BACKEND) \
		BUILD_ROOT=$(ENGINE_BUILD_ROOT) $(ENGINE_LIB) $(ENGINE_K2C)

$(PANE_KRY_C) $(PANE_KRY_H) $(APP_KRY_C) $(APP_KRY_H) &: $(PANE_KRY) $(APP_KRY) $(PANE_ZI_H) | engine
	$(ENGINE_K2C) --no-main --root src -o $(BUILD_DIR)/generated/src $(PANE_KRY) $(APP_KRY)

$(PANE_ZI_C) $(PANE_ZI_H) &: $(PANE_ZI)
	@mkdir -p $(BUILD_DIR)/generated/src
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --no-main --root src \
		-o $(BUILD_DIR)/generated/src $(PANE_ZI)

$(PTY_C) &: src/terminal_pty_linux.zi ziran.lock $(ZIRAN)
	env -u DISPLAY -u WAYLAND_DISPLAY $(ZIRAN) build --project $(LOCK_FLAGS) \
		--target=c --no-main --root src -o $(PTY_GEN) src/terminal_pty_linux.zi

$(PTY_GEN)/%.o: $(PTY_GEN)/%.c
	$(CC) $(CFLAGS) -I$(PTY_GEN) -fPIC -c $< -o $@

.PHONY: pty-native
pty-native: $(PTY_OBJS)

$(BUILD_DIR)/generated/src/%.o: $(BUILD_DIR)/generated/src/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CPPFLAGS) -fPIC -c $< -o $@

$(PANE_TEXT_TEST_C) &: tests/terminal_pane_text_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_TEXT_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_TEXT_TEST_GEN) tests/terminal_pane_text_test.zi

$(PANE_TEXT_TEST): $(PANE_TEXT_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_TEXT_TEST_GEN) $(PANE_TEXT_TEST_C) -o $@

$(PANE_SGR_TEST_C) &: tests/terminal_pane_sgr_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_SGR_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_SGR_TEST_GEN) tests/terminal_pane_sgr_test.zi

$(PANE_SGR_TEST): $(PANE_SGR_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_SGR_TEST_GEN) $(PANE_SGR_TEST_C) -o $@

$(PANE_CSI_TEST_C) &: tests/terminal_pane_csi_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_CSI_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_CSI_TEST_GEN) tests/terminal_pane_csi_test.zi

$(PANE_CSI_TEST): $(PANE_CSI_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_CSI_TEST_GEN) $(PANE_CSI_TEST_C) -o $@

$(PANE_MODES_TEST_C) &: tests/terminal_pane_modes_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_MODES_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_MODES_TEST_GEN) tests/terminal_pane_modes_test.zi

$(PANE_MODES_TEST): $(PANE_MODES_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_MODES_TEST_GEN) $(PANE_MODES_TEST_C) -o $@

$(PANE_MOUSE_TEST_C) &: tests/terminal_pane_mouse_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_MOUSE_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_MOUSE_TEST_GEN) tests/terminal_pane_mouse_test.zi

$(PANE_MOUSE_TEST): $(PANE_MOUSE_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_MOUSE_TEST_GEN) $(PANE_MOUSE_TEST_C) -o $@

$(PANE_DCS_TEST_C) &: tests/terminal_pane_dcs_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_DCS_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_DCS_TEST_GEN) tests/terminal_pane_dcs_test.zi

$(PANE_DCS_TEST): $(PANE_DCS_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_DCS_TEST_GEN) $(PANE_DCS_TEST_C) -o $@

$(PANE_SIXEL_TEST_C) &: tests/terminal_pane_sixel_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_SIXEL_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_SIXEL_TEST_GEN) tests/terminal_pane_sixel_test.zi

$(PANE_SIXEL_TEST): $(PANE_SIXEL_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_SIXEL_TEST_GEN) \
		$(PANE_SIXEL_TEST_GEN)/*.c -o $@

$(PANE_PROFILE_COLORS_TEST_C) &: tests/terminal_pane_profile_colors_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_PROFILE_COLORS_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_PROFILE_COLORS_TEST_GEN) \
		tests/terminal_pane_profile_colors_test.zi

$(PANE_PROFILE_COLORS_TEST): $(PANE_PROFILE_COLORS_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_PROFILE_COLORS_TEST_GEN) \
		$(PANE_PROFILE_COLORS_TEST_GEN)/*.c -o $@

$(PANE_PROFILE_PROMPT_TEST_C) &: tests/terminal_pane_profile_prompt_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_PROFILE_PROMPT_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_PROFILE_PROMPT_TEST_GEN) \
		tests/terminal_pane_profile_prompt_test.zi

$(PANE_PROFILE_PROMPT_TEST): $(PANE_PROFILE_PROMPT_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_PROFILE_PROMPT_TEST_GEN) \
		$(PANE_PROFILE_PROMPT_TEST_GEN)/*.c -o $@

$(PANE_PROFILE_SETTINGS_TEST_C) &: tests/terminal_pane_profile_settings_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_PROFILE_SETTINGS_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_PROFILE_SETTINGS_TEST_GEN) \
		tests/terminal_pane_profile_settings_test.zi

$(PANE_PROFILE_SETTINGS_TEST): $(PANE_PROFILE_SETTINGS_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_PROFILE_SETTINGS_TEST_GEN) \
		$(PANE_PROFILE_SETTINGS_TEST_GEN)/*.c -o $@

$(PANE_PROFILE_TEST_C) &: tests/terminal_pane_profile_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_PROFILE_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_PROFILE_TEST_GEN) \
		tests/terminal_pane_profile_test.zi

$(PANE_PROFILE_TEST): $(PANE_PROFILE_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_PROFILE_TEST_GEN) \
		$(PANE_PROFILE_TEST_GEN)/*.c -o $@

$(PANE_SESSION_TEST_C) &: tests/terminal_pane_session_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_SESSION_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_SESSION_TEST_GEN) tests/terminal_pane_session_test.zi

$(PANE_SESSION_TEST): $(PANE_SESSION_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_SESSION_TEST_GEN) $(PANE_SESSION_TEST_C) -o $@

$(PANE_REFLOW_TEST_C) &: tests/terminal_pane_reflow_test.zi $(PANE_ZI)
	@mkdir -p $(PANE_REFLOW_TEST_GEN)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --root tests \
		-o $(PANE_REFLOW_TEST_GEN) tests/terminal_pane_reflow_test.zi

$(PANE_REFLOW_TEST): $(PANE_REFLOW_TEST_C) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) -I$(PANE_REFLOW_TEST_GEN) \
		$(PANE_REFLOW_TEST_C) -o $@

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

$(PROCESS_TEST): engine $(BUILD_DIR)/tests/process_test.o \
	$(ENGINE_CLIPBOARD_OBJ) \
	$(call mod_obj,app_config) $(call mod_obj,app_launch_options) \
	$(PTY_OBJS) \
	$(PANE_OBJS) $(ENGINE_LIB) $(BACKEND_LIBS) | $(BUILD_DIR)/tests
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ \
		$(BUILD_DIR)/tests/process_test.o $(ENGINE_CLIPBOARD_OBJ) \
		$(call mod_obj,app_config) $(call mod_obj,app_launch_options) \
		$(PTY_OBJS) \
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

ZIRAN_MIGRATION_TEST = tests/ziran_migration_test.sh

.PHONY: ziran-migration-check
ziran-migration-check:
	$(ZIRAN_MIGRATION_TEST)

# Hosted pane tests use isolated clipboard providers and never need the
# application's legacy Kryon/k2c engine or a desktop display.
.PHONY: clipboard-test clipboard-protocol-test clipboard-plan9-test selection-test selection-plan9-test keys-test keys-plan9-test osc-test osc-plan9-test metrics-test metrics-plan9-test pty-test pty-plan9-test pane-ziran-test clipboard-plan9-c
clipboard-test:
	sh tests/clipboard_test.sh clipboard
	sh tests/clipboard_test.sh protocol

clipboard-protocol-test:
	sh tests/clipboard_test.sh protocol

clipboard-plan9-test:
	sh tests/pane_plan9_test.sh clipboard
	sh tests/pane_plan9_test.sh protocol

selection-test:
	sh tests/clipboard_test.sh selection

selection-plan9-test:
	sh tests/pane_plan9_test.sh selection

keys-test:
	sh tests/keys_test.sh

keys-plan9-test:
	sh tests/pane_plan9_test.sh keys

osc-test:
	sh tests/osc_test.sh

osc-plan9-test:
	sh tests/pane_plan9_test.sh osc

metrics-test:
	sh tests/metrics_test.sh

metrics-plan9-test:
	sh tests/pane_plan9_test.sh metrics

pty-test:
	sh tests/pty_test.sh

pty-plan9-test:
	sh tests/pane_plan9_test.sh pty

.PHONY: terminal-test terminal-plan9-test terminal-native terminal-plan9-c config-test config-plan9-test
config-test:
	sh tests/config_test.sh

config-plan9-test:
	sh tests/pane_plan9_test.sh config

terminal-test:
	sh tests/terminal_engine_test.sh

terminal-plan9-test:
	sh tests/pane_plan9_test.sh engine

terminal-native:
	env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY $(ZIRAN) build --project $(LOCK_FLAGS) \
		--target=c --no-main -o $(TERMINAL_GEN) src/terminal.zi
	mkdir -p $(BUILD_DIR)/lib
	set -e; for source in $(TERMINAL_GEN)/*.c; do \
		$(CC) -std=c11 -O2 -fPIC -I$(TERMINAL_GEN) -c "$$source" -o "$${source%.c}.o"; \
	done
	rm -f $(TERMINAL_LIB)
	$(AR) rcs $(TERMINAL_LIB) $(TERMINAL_GEN)/*.o

terminal-plan9-c:
	env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY $(ZIRAN) build --project $(LOCK_FLAGS) \
		--target=plan9-c --no-main -o $(PLAN9_GENERATED)/terminal src/terminal.zi

.PHONY: widget-test widget-plan9-test profile-test session-test session-plan9-test launch-test launch-plan9-test pane-native pane-plan9-c
widget-test:
	sh tests/widget_test.sh

widget-plan9-test:
	sh tests/pane_plan9_test.sh widget

profile-test:
	sh tests/profile_test.sh

session-test:
	sh tests/session_test.sh

session-plan9-test:
	sh tests/pane_plan9_test.sh session

launch-test:
	sh tests/launch_options_test.sh

launch-plan9-test:
	sh tests/pane_plan9_test.sh launch

pane-native:
	env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY $(ZIRAN) build --project $(LOCK_FLAGS) \
		--target=c --no-main -o $(PANE_GEN) src/terminal_pane/terminal_pane_widget.zi
	mkdir -p $(BUILD_DIR)/lib
	set -e; for source in $(PANE_GEN)/*.c; do \
		$(CC) -std=c11 -O1 -fPIC -I$(PANE_GEN) -c "$$source" -o "$${source%.c}.o"; \
	done
	rm -f $(PANE_LIB)
	$(AR) rcs $(PANE_LIB) $(PANE_GEN)/*.o

pane-plan9-c:
	env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY $(ZIRAN) build --project $(LOCK_FLAGS) \
		--target=plan9-c --no-main -o $(PLAN9_GENERATED)/pane src/terminal_pane/terminal_pane_widget.zi

pane-ziran-test: terminal-test config-test widget-test profile-test session-test launch-test clipboard-test selection-test keys-test osc-test metrics-test pty-test ziran-migration-check

clipboard-plan9-c:
	env -u DISPLAY -u WAYLAND_DISPLAY $(ZIRAN) build --project $(LOCK_FLAGS) --target=plan9-c \
		--root tests \
		-o $(BUILD_ROOT)/plan9/clipboard-test tests/terminal_pane_clipboard_test.zi

test: $(TEST) widget-test $(PANE_SELECTION_TEST) \
	$(PANE_TEXT_TEST) $(PANE_SGR_TEST) $(PANE_CSI_TEST) \
	$(PANE_MODES_TEST) $(PANE_MOUSE_TEST) \
	$(PANE_DCS_TEST) $(PANE_SIXEL_TEST) \
	selection-test clipboard-test \
	$(PANE_PROFILE_COLORS_TEST) $(PANE_SESSION_TEST) \
	$(PANE_REFLOW_TEST) \
	$(PANE_PROFILE_PROMPT_TEST) $(PANE_PROFILE_SETTINGS_TEST) \
	$(PANE_PROFILE_TEST) $(PROCESS_TEST) metrics-test osc-test pty-test ziran-migration-check
	$(TEST)
	$(PANE_SELECTION_TEST)
	$(PANE_TEXT_TEST)
	$(PANE_SGR_TEST)
	$(PANE_CSI_TEST)
	$(PANE_MODES_TEST)
	$(PANE_MOUSE_TEST)
	$(PANE_DCS_TEST)
	$(PANE_SIXEL_TEST)
	$(PANE_PROFILE_COLORS_TEST)
	$(PANE_SESSION_TEST)
	$(PANE_REFLOW_TEST)
	$(PANE_PROFILE_PROMPT_TEST)
	$(PANE_PROFILE_SETTINGS_TEST)
	$(PANE_PROFILE_TEST)
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

# Native Plan 9 preparation. The guest compiler cannot run k2c or Ziran,
# so the .kry and .zi app modules are emitted ahead of time as 8c-safe C into
# build/plan9/generated with the file list the mkfile consumes. Run on
# the host whenever any .kry changes before a native build (and prepare
# the Kryon library's own build/plan9 with `make kry-c-plan9` there).
PLAN9_PREP_DIR = build/plan9
PLAN9_GENERATED = $(PLAN9_PREP_DIR)/generated
PLAN9_FILE_LIST = $(PLAN9_PREP_DIR)/generated-c-files.txt

.PHONY: kry-c-plan9 pty-plan9-c
pty-plan9-c:
	env -u DISPLAY -u WAYLAND_DISPLAY $(ZIRAN) build --project $(LOCK_FLAGS) \
		--target=plan9-c --no-main --root src \
		-o $(PLAN9_GENERATED)/native src/terminal_pty_plan9.zi

kry-c-plan9: engine
	rm -rf $(PLAN9_GENERATED)
	mkdir -p $(PLAN9_PREP_DIR)
	$(ENGINE_K2C) --plan9 --no-main --root $(abspath src) \
		-o $(PLAN9_GENERATED) $(PANE_KRY) $(APP_KRY)
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=plan9-c --no-main --root src \
		-o $(PLAN9_GENERATED)/src $(PANE_ZI)
	$(MAKE) pty-plan9-c
	(cd $(PLAN9_GENERATED) && find . -type f -name '*.c' | \
	sed -e 's@^\./@@') | LC_ALL=C sort > $(PLAN9_FILE_LIST)
