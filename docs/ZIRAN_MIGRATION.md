# T9 Ziran migration

T9's maintained source language is Ziran (`.zi`). Legacy `.kry` files are
migration input only: each one is removed after its behavior has a current
Ziran implementation and focused hosted/Plan 9 checks. No compatibility
compiler path, dual product module, or `.kry` restore is part of the target.

Current status: maintained Ziran sources include the pane modules,
clipboard storage/protocol handling, both platform process transports, and
the full terminal engine and its typed state, application configuration,
command-line options, sessions and their persistence, plus application state,
tab lifecycle, selection/clipboard routing, palette and profile changes,
commands, search dialogs, the context menu, application input routing and the
menu bar, graphical view, shared application host and standalone OS entrypoint.
No `.kry`, handwritten C product implementation or handwritten native header
remains. Native declarations are generated from the maintained Ziran modules.
The parser benchmark also runs the same implementation from Ziran; the obsolete
C fixtures and their mock old Kryon host have been retired.
Linux standalone builds use current Kryon frames and Raylib/SDL2; the native
entrypoint uses current Libdraw. Rill's actual host integration, native
whole-application graphics and retained font fallback behavior remain
unfinished. The migration is complete only when these behavior gates and all
Linux, Rill, native Plan 9, installation and release routes are verified.

## Build boundary and consolidation

The canonical repository is `taijiosnet/t9`. Its history includes Kapsule's
original terminal sources and local compatibility fixes; those older C
implementations are not restored alongside the maintained ports.

`make pane-ziran-test` runs the engine, configuration, sessions, launch options,
application state, tab lifecycle and input routing,
widget, theme/profile, clipboard, selection, keyboard, OSC,
pane sizing, and Linux PTY suites without the legacy application. Keyboard protocol and current
Kryon session input are
checked as native C/C++ and from saved IR. `make keys-plan9-test` with
`TAIJI_DIR` set to the canonical Taiji checkout compiles and executes the
same keyboard fixture from source and saved IR under native Plan 9 8c/8l.
Raw-buffer pane APIs are native code; portable bundle coverage is not claimed.
`make clipboard-plan9-c` emits the clipboard fixture's Plan 9 C output;
`make clipboard-plan9-test selection-plan9-test` compiles and executes the
selection, clipboard actions, and OSC52/paste fixtures with native 8c/8l. The
clipboard port keeps primary-selection preference, soft-wrap copying,
host sync/flush, paste callback routing, and scroll reset behavior.

The standalone application now uses only the current `.zi` implementation.
Rill's legacy desktop entrypoint still calls the removed Kryon C host API and
must migrate to the package's `t9/app_host` export. Independent pane checks do
not certify that integration or a native whole-application graphical session.

`terminal_clipboard.zi` owns clipboard bytes, OSC52 queries and writes, and
paste filtering. It imports `kryon/clipboard` for source selection and pending
write policy, and `kryon/system_clipboard` for host reads and writes. The pane
and selection ports call this implementation directly; they no longer declare
removed Kryon clipboard-provider functions as foreign symbols. Hosted tests
simulate only Kryon's current three host clipboard operations. Primary text
is owned inside Terminal; external Linux primary-selection ownership and
complete application clipboard integration remain whole-application gates.

## Keyboard input boundary

`terminal_pane_keys.zi` owns xterm key and UTF-8 encoding and callback routing.
`terminal_keyboard.zi` reads current Kryon session input through
`kryon/session` and `kryon/tree_input`; it converts Control/Alt modifier
bits explicitly. Application shortcuts consume their physical and typed
input before terminal writes. Input frames distinguish fresh/repeated events
from held keys so Control input repeats without flooding held snapshots.
The remaining application hosts must migrate to this explicit frame API;
removed global input polling functions are not restored in Kryon.

The dependency lock is generated with Ziran package commands against canonical
Kryon (`88b59a18`) and compiler (`83e25588`) master commits. The complete
fresh locked application build remains unverified.
Local development uses the canonical organization-root overrides; when that
file is absent, the test and build routes require the committed lock. Fresh
locked application builds remain part of the unfinished migration gate.

## OSC, metrics, and process transports

Clipboard checks now run the product implementation in C/C++ from source and
saved IR. They preserve independent primary/system values, primary preference,
pending writes, host retry and fallback, selection copy, and scroll reset.
OSC52 rejects malformed, noncanonical, oversized and embedded-NUL payloads
without replacing clipboard state. Paste filtering removes raw and UTF-8 C1
controls and terminal sequences, preserves ordinary UTF-8 text, and handles
partial writes. Storage contains bytes and lengths, so moving a tab cannot
retain a string view into the tab's former address.

`terminal_pane_osc.zi` replaces the old OSC module. Color and palette parsing,
bounded replies, sanitized title/hyperlink text, title-stack operations, and
file-URI decoding pass C/C++ and saved-IR behavior checks. `make osc-plan9-test`
also compiles, links, and executes both fixtures with actual Plan 9 8c/8l.

`terminal_pane_metrics.zi` replaces `runtime/terminal_pane.kry` and its old C
policy test. Sizing, clamping, content bounds, and scroll-indicator placement
pass source and saved-IR checks in C, C++, Go, and portable bundles.
`make metrics-plan9-test` also passes native 8c/8l execution for both fixtures.

`terminal_pty_linux.zi` and `terminal_pty_plan9.zi` replace the handwritten C
transports. Linux retains pseudoterminal setup, shell argument selection,
working-directory and environment setup, nonblocking I/O, resizing, child
reaping, and bounded process-group shutdown. Plan 9 uses private child note
groups and namespaces and a reader-owned spool so polling does not block the
UI thread. Private namespaces allow group-note delivery even when the host
inherits Plan 9's protected initial namespace.
Transport sessions are keyed by descriptors, so moving tabs does not require
rebinding pointers to application state. Both use the shared engine/process
driver; Rill's Plan 9 build no longer supplies a second process implementation.

`make pty-test` exercises real Linux child I/O, resize, exit, and group signals
from C/C++ source and saved IR, using a controlled shell without owner startup
files. `make pty-plan9-test` exercises real child I/O, EOF, exit, and notes from
source and saved IR under native Plan 9. Native gates use one CPU, 256 MB, and
a 120-second limit, with desktop displays scrubbed and desktop boot disabled.
`make pty-native` builds the Linux transport objects used by the app; `make
pty-plan9-c` emits the corresponding Plan 9 library output. These focused
checks do not certify the remaining legacy application or Rill integration.

## Terminal engine

`src/terminal.zi` owns `Terminal`, `Cell`, graphics, and search records and loads
the 16 migrated engine modules plus native storage/report helpers. The old
engine `.kry` implementations are removed. Native headers are generated from
these Ziran declarations. There is no second handwritten native interface.

`make terminal-test` executes the actual parser, screen, scrollback, resize,
search, graphics, title/color/clipboard protocols, terminal reports, keyboard,
mouse, focus, paste, and real child-process driver in C and C++ from source
and saved IR. `make terminal-plan9-test` executes the same fixture under actual
Plan 9 8c/8l from both forms. Its report/input sink uses an owned child transport
session; native pipes need explicit newline mode for LF-only rc output.
Clipboard host I/O is simulated, while product clipboard policy remains real.

Boundary checks cover chunked Unicode titles, atomic oversized OSC rejection,
clipboard payloads larger than 512 bytes, saturated CSI parameters, full
hyperlink tables, and preserving newest rows while changing a wrapped history
ring's limit. Screen/history allocation replaces buffers only after success;
width changes allocate a fresh history ring even when the previous ring is empty.

`make terminal-native` builds `libt9_terminal.a` with all generated native
dependencies. `make terminal-plan9-c` emits the corresponding Plan 9 library
sources. These library gates do not establish a working complete application.

## Application configuration

`src/app/app_config.zi` replaces `app_config.kry`. It uses the existing
`TerminalPaneProfileSettings` record directly and imports standard Ziran file
modules for Linux and native Plan 9. The defaults, limits, XDG/home path rules,
escaped text, colors, and all 26 persisted settings are retained. The reader
handles maximum-length escaped commands across file chunks and ignores an
oversized setting line as a whole; failed serialization cannot truncate a file.

`make config-test` verifies source/saved-IR C and C++ execution, and
`make config-plan9-test` verifies actual native 8c/8l execution for both forms.
Every file fixture lives inside its disposable generated-output folder.
The remaining app consumers must use this module's `Defaults`, `Apply`,
`Load`, `Save`, and `EffectiveScrollback` APIs with the canonical settings type.

## Embedded pane and themes

`terminal_pane_widget.zi` uses explicit Kryon sessions, input frames and queued
paint. Embedded panes use the application's `Terminal` engine; the second
handwritten simple-terminal parser and state are removed. Rendering preserves
Unicode, combining characters and wide-cell positions, clips glyphs and cursors,
and supports a complete 240-by-120 grid without borrowing temporary cell text.
Theme colors come from current Kryon palette/style rules; test-only legacy
theme and rendering implementations are removed.

`make widget-test profile-test` checks source and saved-IR C/C++ behavior,
including real child-process keyboard input and current theme rules. `make
widget-plan9-test` passes the same widget fixture under native 8c/8l. `make
pane-native pane-plan9-c` produces the migrated pane's native library/output.

## Sessions and launch options

`app_session.zi` owns each tab's typed `Terminal`, launch text, title and
scroll offset. It preserves dynamic-title modes, explicit title overrides,
OSC working-directory updates and Linux process-directory lookup. Launch text
is copied before restarting a tab; process sessions remain valid when tab
records move. The configured scrollback limit is applied after engine startup.

`app_session_store.zi` uses standard file modules on both platforms. It keeps
the escaped tab format and XDG/home paths, reads full records across file
chunks, skips whole oversized lines and prepares serialization before opening
an existing file for replacement. Signed persisted values saturate without
overflow and tiny title buffers remain terminated.

`app_launch_options.zi` replaces the legacy option parser, retaining per-tab
launch specifications, terminal settings and supported desktop option aliases.
Missing required values now report an error. Execute arguments use POSIX shell
quoting on Linux and rc quoting on native Plan 9.

`make session-test launch-test` checks source and saved-IR C/C++ execution;
`make session-plan9-test launch-plan9-test` checks actual native 8c/8l execution.
Sessions exercise real child I/O after a tab move and execute arguments
containing spaces and apostrophes through the actual platform shell. File
fixtures stay inside disposable test-output directories. Native QEMU gates
also cap the translation buffer at 32 MB.

## Application state and tab lifecycle

`app_state.zi` owns the application's typed state on the heap.
`app_sessions.zi` uses the canonical `Session` records and process transports
for launch tabs, active focus, reordering, closing and replacement, exit,
save and restore. Closing a moved tab clears the vacated record so application
disposal cannot close the remaining tab's process twice. Chrome sizing uses
current Kryon tab metrics and explicit scale.

`app_selection.zi` and `app_clipboard.zi` route selection, copy, paste and host
sync through Terminal's existing controllers and clipboard policy.
`terminal_clipboard.PasteText` consumes a bounded Ziran string view, including
unterminated slices, with the same control filtering and bracketed-paste
framing as the raw-buffer API. There is one paste-policy implementation.

`app_palette.zi` reads the installed Kryon style rules;
`app_profile.zi` applies configuration and theme defaults while retaining
terminal-provided color overrides. Profile prompts propagate scrollback,
width and color changes to existing tabs, and report font-file changes for
the application host to load. The six corresponding `.kry` implementations
are removed.

`make application-test` checks source and saved-IR C/C++ behavior using the
actual engine, configuration, clipboard and process transports. It covers
theme roles, profile updates, selection copying, tab moves and closes, live
child I/O after movement, persistence and restored child sessions, last-tab
replacement and exit. `make application-plan9-test` checks the same fixture
with actual native 8c/8l execution. Fixtures use controlled shells and keep
files inside their disposable generated-output folders. These checks do not
yet establish the full graphical application or its Rill host.

## Commands, search and context menu

`app_commands.zi` owns command dispatch and physical-key shortcut policy,
including tab navigation, font bounds, profile prompts and cursor choices.
`app_search.zi` uses the canonical engine search controller and current Kryon
sessions and text fields. Search retains wraparound and direction, Unicode
editing, clipboard paste, capacity limits and focus. `app_dialog.zi` owns only
the prompt's bounded storage and composition; Kryon owns text editing. The
dialog presents labeled Cancel/Find actions, and its close icon dismisses it.

`app_context_menu.zi` composes current Kryon context-menu widgets and routes
their activations through the same commands and clipboard controllers. Last-tab
close, copy without a selection and unavailable primary paste remain disabled.
Menus retain outside-click and Escape dismissal and consume their typed input
so an overlay cannot leave text queued for the terminal.

`make application-test application-plan9-test` covers source and saved-IR
C/C++ and native Plan 9 8c/8l execution, including actual retained-tree clicks
on dialog and menu actions, disabled rows and outside dismissal. The three
corresponding `.kry` implementations are removed. These checks do not yet
establish the graphical application or Rill.

## Application input routing

`app_input.zi` replaces the legacy global-polling input module with borrowed
device frames. It routes app shortcuts before terminal bytes, honors configured
Backspace/Delete bindings, emits both edges of a quick mouse click, and retains
mouse reporting, pixel motion, alternate-screen wheel keys, primary-selection
paste, word/line selection, edge scrolling, hyperlinks and focus reports.
Keyboard state belongs to the application. Repeated app shortcuts are consumed
without repeating their action, while repeated terminal Control keys still write.
The old held-shortcut flags are removed from the typed app state.

`make input-test input-plan9-test` executes source and saved-IR C/C++ and
native Plan 9 8c/8l behavior. It checks actual bytes through controlled child
processes, Unicode, held/repeated keys, selection, scroll limits, current Kryon
input capture, dialog ownership and pointer visibility decisions. Hosts supply
middle-button edges, time and focus and apply the returned hyperlink/cursor
decisions. Complete hosts must also distinguish fresh and repeated device keys;
the protocol fixture verifies that distinction at the explicit frame boundary.
These module checks do not certify the remaining graphical host or live OS input.

## Application menu bar

`app_menu.zi` composes Kryon's current session-based `Menu`. The six original
groups retain their commands, accelerators, separators, profile settings and
Cursor Style submenu. A single retained `MenuState` owns navigation; neither
the application nor Kryon retains pointers to the frame's item arrays.
Tall menus scroll so every setting remains accessible. Menu rendering,
pointer capture, nested navigation and disabled-item policy belong to Kryon;
Terminal routes activations through its existing command controller.

F10 focuses the menu without sending terminal bytes, Alt access keys open
their group, and F1 transfers focus to About. Their configuration switches
restore those keys to terminal input. Repeated F10 events are consumed without
toggling focus. Hosts pass the key's fresh/repeated status when composing
the menu; the remaining whole-application host gates must verify OS events.

`make application-test input-test` checks source/saved-IR C and C++ behavior,
including retained-tree clicks, cursor choices, tab lifecycle, Find, long-menu
scrolling and actual terminal bytes. `make application-plan9-test
input-plan9-test` checks the same fixtures with native Plan 9 8c/8l execution.
Kryon's generic menu also passes C/C++/Go and portable source/saved-IR checks.
The legacy menu implementation and handwritten header are removed. These
gates do not establish complete graphical
application or Rill builds.

## Application graphical view

`app_terminal_view.zi` composes the menu, tabs, terminal grid, images and
dialogs through current Kryon sessions, widgets and queued paint. The legacy
view implementation is removed. Glyph text and background image paths are
owned by the frame, including the complete 240-by-120 grid. Terminal colors,
selection, wide and combining cells, bold and faint styles, decorations,
blinking, Sixel pixel runs, cursor styles, scroll indicators and bell overlays
retain their application behavior. Glyphs and Sixel runs are clipped to the
terminal viewport. Background images use asset-backed `ImageProps`.

Tabs retain activation, closing, configured middle-click closing,
double-click renaming and reordering through Kryon's retained `TabBar`.
Dialogs retain keyboard and button actions; applying a font-file setting
reports the change to the host so it can load the new source.

`make view-test` checks source and saved-IR execution in C and C++;
`make view-plan9-test` checks the same fixture with actual native Plan 9
8c/8l execution. The fixtures verify queued glyph and image ownership,
rendering, clipping, cursor and scroll behavior, tab lifecycle and dialog
actions. These checks do not establish whole-application graphics, host font
loading or OS input.

## Shared application host

`app_host.zi` owns the lifecycle shared by the standalone application and
Rill's embedded Terminal. It exports preparation, startup, polling,
composition, title notifications and closing. Preparation parses options
before creating a child. Startup uses the canonical sessions and transports;
standalone restoration and embedded shell startup keep their separate
policies. Closing saves sessions when requested and disposes only owned
Terminal state and processes. The old embedded `.kry` host is removed.

The caller owns the Kryon frame, device polling, fonts and window operations.
Composition captures only the input left by the current widgets and preserves
fresh versus repeated keys. Closing a modal consumes its complete device
frame. Polling updates metadata, bell feedback and clipboard writes, retains
hold behavior and reports when the last child exits. Embedded views use the
containing application's installed theme rules. Hosts can import the
package's `t9/app_host` export; Terminal code remains in this repository.

`make host-test` checks source and saved-IR execution in C and C++;
`make host-plan9-test` checks actual native Plan 9 8c/8l execution. They use
controlled real child processes to verify focus reports, Unicode input,
Control-key repeats, held-key suppression, modal input ownership, title and
clipboard updates, exit and hold behavior, middle-click positions, saved
sessions and restored child I/O. These checks do not establish the standalone
OS host, Rill's actual embedded integration or installation/release routes.

## Standalone OS host

`app_main.zi` owns the Linux and native Plan 9 entrypoints and runs the shared
Terminal lifecycle. `app_window.zi` gathers OS input and manages only its own
window, fonts, title, cursor and configured capture. Linux uses current Kryon
Raylib over SDL2; native Plan 9 uses current Libdraw and libthread. Geometry,
window flags, held/repeated keyboard events, frame rates, font configuration,
CLI routes and native forwarding to Rill retain their explicit host boundary.
The legacy entrypoint and C entry shim are removed, and the Makefile no longer
invokes k2c or the removed Kryon C library build.

`make standalone-test` verifies the actual executable in C and C++ from source
and saved IR on private Xvfb displays. It covers CLI routes, a rendered frame,
real child input, held-key suppression, Control repeats, menu ownership and
owned-window closing. `make install-test` verifies a disposable staged install.
`make standalone-plan9-test` compiles and links the complete executable with
actual native 8c/8l, then exercises its CLI and Rill forwarding from both forms.
The native gate uses one CPU, 256 MB RAM, a 32 MB translation buffer and a
120-second limit, with desktop boot disabled.

These checks do not establish native graphical input/rendering, broad glyph
fallback, Rill's actual embedded integration or fresh locked release builds.
Finish those gates before claiming the full migration complete. The `.zi` application is the
single maintained implementation while this remaining work proceeds.

## Native interfaces and parser benchmarks

Embedded hosts can paint while unfocused without consuming their containing
desktop's key, text, wheel or retained pointer activation. Closing an embedded
host preserves the standalone application's saved tabs. `make host-test`
checks background menus and input preservation, controlled child I/O, and
standalone session restoration after embedded disposal in C/C++ from source
and saved IR. Rill owns window placement and closing; Terminal owns its child
processes and tab state.

The old handwritten headers and unbuilt combined C fixtures are removed.
Their current behavior checks live in `terminal_engine_test.zi`,
`terminal_pty_linux_test.zi`, the pane fixtures and the application,
configuration, launch, session, input, view and host fixtures. Each consumes
the maintained product modules rather than a mock legacy UI library.

`make parser-replay` runs all 13 historical parser workloads against that same
engine. `make parser-replay-test` executes reduced runs in C and C++ from source
and saved IR. Golden row and byte counts were derived from the original C
payloads before retiring it; they verify Unicode, padding, hex formatting and
control sequences without treating benchmark timings as performance claims.
No display or owner shell startup is needed. Native output is disposable under
`build/ziran/`, and execution has a 30-second limit.

## Completed modules

- `src/app/app_terminal_view.zi`
- `src/app/app_host.zi`
- `src/app/app_main.zi`
- `src/app/app_window.zi`

- `src/terminal_pane/terminal_pane_text.zi`
- `src/terminal_pane/terminal_pane_sgr.zi`
- `src/terminal_pane/terminal_pane_csi.zi`
- `src/terminal_pane/terminal_pane_modes.zi`
- `src/terminal_pane/terminal_pane_mouse.zi`
- `src/terminal_pane/terminal_pane_profile_colors.zi`
- `src/terminal_pane/terminal_pane_session.zi`
- `src/terminal_pane/terminal_pane_render.zi`
- `src/terminal_pane/terminal_pane_reflow.zi`
- `src/terminal_pane/terminal_pane_profile_prompt.zi`
- `src/terminal_pane/terminal_pane_profile.zi`
- `src/terminal_pane/terminal_pane_profile_settings.zi`
- `src/terminal_pane/terminal_pane_profile_types.zi`
- `src/terminal_pane/terminal_pane_dcs.zi`
- `src/terminal_pane/terminal_pane_sixel.zi`
- `src/terminal_pane/terminal_pane_selection.zi`
- `src/terminal_pane/terminal_pane_clipboard.zi`
- `src/terminal_pane/terminal_pane_keys.zi`
- `src/terminal_pane/terminal_keyboard.zi`
- `src/terminal_pane/terminal_pane_osc.zi`
- `src/terminal_pane/terminal_pane_metrics.zi`
- `src/terminal_clipboard.zi`
- `src/terminal_pty_linux.zi`
- `src/terminal_pty_plan9.zi`
- `src/terminal.zi` and its loaded `src/engine/*.zi` modules
- `src/app/app_config.zi`
- `src/terminal_pane/terminal_pane_widget.zi`
- `src/app/app_session.zi`
- `src/app/app_session_store.zi`
- `src/app/app_launch_options.zi`
- `src/app/app_state.zi`
- `src/app/app_sessions.zi`
- `src/app/app_selection.zi`
- `src/app/app_clipboard.zi`
- `src/app/app_palette.zi`
- `src/app/app_profile.zi`
- `src/app/app_chrome.zi`
- `src/app/app_commands.zi`
- `src/app/app_search.zi`
- `src/app/app_dialog.zi`
- `src/app/app_context_menu.zi`
- `src/app/app_input.zi`
- `src/app/app_menu.zi`

`tests/ziran_migration_test.sh` rejects the obsolete rewrite document and any
future module restored alongside its `.zi` replacement.
