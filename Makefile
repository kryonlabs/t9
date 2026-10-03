CC ?= cc
AR ?= ar
.DEFAULT_GOAL := all
ZIRAN ?= ./scripts/ziran.sh
LOCK_FLAGS := $(if $(wildcard ziran.local.toml),,--locked)
BUILD_ROOT ?= build
BUILD_DIR ?= $(BUILD_ROOT)/linux-$(shell uname -m)
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
APPDIR ?= $(PREFIX)/share/applications
INSTALL ?= install
APP := $(BUILD_DIR)/bin/t9
SOURCES := $(wildcard src/*.zi src/app/*.zi src/engine/*.zi src/terminal_pane/*.zi)
PACKAGE_INPUTS := ziran.toml ziran.lock $(wildcard ziran.local.toml)
TERMINAL_GEN := $(BUILD_DIR)/generated/terminal
TERMINAL_LIB := $(BUILD_DIR)/lib/libt9_terminal.a
PANE_GEN := $(BUILD_DIR)/generated/pane
PANE_LIB := $(BUILD_DIR)/lib/libt9_pane.a
PTY_GEN := $(BUILD_DIR)/generated/pty
PLAN9_PREP_DIR := $(BUILD_ROOT)/plan9
PLAN9_GENERATED := $(PLAN9_PREP_DIR)/generated
ZIRAN_MIGRATION_TEST := tests/ziran_migration_test.sh

.PHONY: all run test clean install install-test standalone-test standalone-window-test standalone-plan9-test plan9-c pty-native parser-replay parser-replay-test
all: $(APP)

$(APP): $(SOURCES) $(PACKAGE_INPUTS) scripts/build.sh scripts/ziran.sh Makefile
	ZIRAN="$(ZIRAN)" CC="$(CC)" sh scripts/build.sh c "$(BUILD_DIR)"

run: $(APP)
	$(APP)

standalone-window-test: $(APP)
	env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY -u DBUS_SESSION_BUS_ADDRESS -u SESSION_MANAGER \
		LP_NUM_THREADS=1 OMP_NUM_THREADS=1 xvfb-run -a -s '-screen 0 1024x768x24' \
		env T9_PRIVATE_XVFB=1 python3 tests/standalone_window_test.py "$(APP)"

standalone-test: $(APP)
	ZIRAN="$(ZIRAN)" RAYLIB_A="$(if $(RAYLIB_A),$(RAYLIB_A),$(abspath $(BUILD_DIR))/raylib/raylib/libraylib.a)" sh tests/standalone_test.sh

plan9-c:
	ZIRAN="$(ZIRAN)" sh scripts/build.sh plan9-c "$(PLAN9_PREP_DIR)"

standalone-plan9-test:
	ZIRAN="$(ZIRAN)" sh tests/standalone_plan9_test.sh source
	ZIRAN="$(ZIRAN)" sh tests/standalone_plan9_test.sh saved

parser-replay:
	ZIRAN="$(ZIRAN)" sh scripts/parser-replay.sh

parser-replay-test:
	ZIRAN="$(ZIRAN)" sh tests/parser_replay_test.sh

pty-native:
	env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY $(ZIRAN) build --project $(LOCK_FLAGS) \
		--target=c --no-main --prune-stale -o $(PTY_GEN) src/terminal_pty_linux.zi
	set -e; for source in $(PTY_GEN)/*.c; do \
		$(CC) -std=c11 -O1 -fPIC -I$(PTY_GEN) -c "$$source" -o "$${source%.c}.o"; \
	done

.PHONY: ziran-migration-check
ziran-migration-check:
	$(ZIRAN_MIGRATION_TEST)

# Module fixtures use isolated host effects and never need a desktop display.
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

.PHONY: application-test application-plan9-test input-test input-plan9-test view-test view-plan9-test host-test host-plan9-test
application-test:
	ZIRAN="$(ZIRAN)" sh tests/application_test.sh

application-plan9-test:
	ZIRAN="$(ZIRAN)" sh tests/pane_plan9_test.sh application

input-test:
	ZIRAN="$(ZIRAN)" sh tests/application_test.sh input

input-plan9-test:
	ZIRAN="$(ZIRAN)" sh tests/pane_plan9_test.sh input

view-test:
	ZIRAN="$(ZIRAN)" sh tests/application_test.sh view

view-plan9-test:
	ZIRAN="$(ZIRAN)" sh tests/pane_plan9_test.sh view

host-test:
	ZIRAN="$(ZIRAN)" sh tests/application_test.sh host

host-plan9-test:
	ZIRAN="$(ZIRAN)" sh tests/pane_plan9_test.sh host

pane-ziran-test: terminal-test config-test widget-test profile-test session-test launch-test application-test input-test view-test host-test clipboard-test selection-test keys-test osc-test metrics-test pty-test ziran-migration-check

clipboard-plan9-c:
	env -u DISPLAY -u WAYLAND_DISPLAY $(ZIRAN) build --project $(LOCK_FLAGS) --target=plan9-c \
		--root tests \
		-o $(BUILD_ROOT)/plan9/clipboard-test tests/terminal_pane_clipboard_test.zi

test: pane-ziran-test standalone-test install-test parser-replay-test

install: $(APP)
	mkdir -p "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(APPDIR)"
	$(INSTALL) -m 755 "$(APP)" "$(DESTDIR)$(BINDIR)/t9"
	{ \
		printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Terminal'; \
		printf '%s\n' 'Comment=Kryon terminal emulator' 'Exec=$(BINDIR)/t9'; \
		printf '%s\n' 'Icon=utilities-terminal' 'Terminal=false' 'Categories=System;TerminalEmulator;'; \
		printf '%s\n' 'Keywords=terminal;shell;t9;' 'StartupNotify=true'; \
	} > "$(DESTDIR)$(APPDIR)/t9.desktop"
	if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database "$(DESTDIR)$(APPDIR)"; fi

install-test: $(APP)
	@set -eu; mkdir -p build/ziran; stage=$$(mktemp -d "$(CURDIR)/build/ziran/install.XXXXXX"); \
		trap 'rm -rf "$$stage"' EXIT HUP INT TERM; \
		$(MAKE) --no-print-directory install DESTDIR="$$stage" PREFIX=/usr; \
		test -x "$$stage/usr/bin/t9"; test -f "$$stage/usr/share/applications/t9.desktop"; \
		env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY "$$stage/usr/bin/t9" --version; \
		if command -v desktop-file-validate >/dev/null 2>&1; then desktop-file-validate "$$stage/usr/share/applications/t9.desktop"; fi

pty-plan9-c:
	env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY $(ZIRAN) build --project $(LOCK_FLAGS) \
		--target=plan9-c --no-main --prune-stale -o $(PLAN9_GENERATED)/pty src/terminal_pty_plan9.zi

clean:
	rm -rf "$(BUILD_ROOT)"
