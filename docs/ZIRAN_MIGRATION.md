# T9 Ziran migration

T9's maintained source language is Ziran (`.zi`). Legacy `.kry` files are
migration input only: each one is removed after its behavior has a current
Ziran implementation and focused hosted/Plan 9 checks. No compatibility
compiler path, dual product module, or `.kry` restore is part of the target.

Current status: 42 maintained Ziran sources include 21 pane modules,
clipboard storage/protocol handling, both platform process transports, and
the full terminal engine and its typed state. There are 19 legacy `.kry`
inputs and two handwritten C implementations remaining at the pane and app
boundaries. The current
boundary is the legacy C-header/K2C API. Remaining modules must be
expressed as Ziran types and explicit foreign/host bindings, then linked to the
current Ziran-based Kryon library. The migration is complete only when no
`.kry` product source remains and Linux, Rill, and native Plan 9 builds use the
same `.zi` implementation.

## Build boundary and consolidation

The canonical repository is `taijiosnet/t9`. Its history includes Kapsule's
original terminal sources and local compatibility fixes; those older C
implementations are not restored alongside the maintained ports.

`make pane-ziran-test` runs the engine, clipboard, selection, keyboard, OSC,
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

Full application, Rill host, and whole-application Plan 9 builds still use
legacy application/widget sources and Kryon C headers. Current Kryon no longer exposes that API,
so these builds are not established by the independent pane checks. Keep
the existing application pipeline until the remaining app/runtime modules move
to Ziran and current Kryon bindings.

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
The remaining legacy application must migrate to this explicit frame API;
removed global input polling functions are not restored in Kryon.

The dependency lock is generated with Ziran package commands against canonical
Kryon (`be96f1f7`) and compiler (`4164aff7`) master commits. These current
commits are local; their publication remains necessary for fresh locked builds.
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
these Ziran declarations; old handwritten headers are migration inputs for
the remaining application consumers and must be removed with those consumers.

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

The next source boundary is the terminal widget and application state. Migrate
their consumers to `Terminal` and the current pane/clipboard contracts, then
migrate app
entrypoints to Kryon sessions and frames, remove k2c and the remaining C
product files, and establish complete Linux/Plan 9, Rill, installation, and
release gates. Independent module checks remain separate evidence until
those whole-application gates pass.

## Completed modules

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

`tests/ziran_migration_test.sh` rejects the obsolete rewrite document and any
future module restored alongside its `.zi` replacement.
