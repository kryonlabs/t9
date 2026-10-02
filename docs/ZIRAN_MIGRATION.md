# T9 Ziran migration

T9's maintained source language is Ziran (`.zi`). Legacy `.kry` files are
migration input only: each one is removed after its behavior has a current
Ziran implementation and focused hosted/Plan 9 checks. No compatibility
compiler path, dual product module, or `.kry` restore is part of the target.

Current status: 17 pane modules are Ziran sources and 38 legacy `.kry`
inputs remain across the pane, engine, app, and runtime boundaries. The current
boundary is the legacy C-header/K2C API. Remaining modules must be
expressed as Ziran types and explicit foreign/host bindings, then linked to the
current Ziran-based Kryon library. The migration is complete only when no
`.kry` product source remains and Linux, Rill, and native Plan 9 builds use the
same `.zi` implementation.

## Build boundary and consolidation

The canonical repository is `taijiosnet/t9`. Its history includes Kapsule's
original terminal sources and local compatibility fixes; those older C
implementations are not restored alongside the maintained ports.

`make pane-ziran-test` runs hosted clipboard and selection suites without
the legacy engine. `make clipboard-plan9-c` emits their Plan 9 C output;
native compilation, linking, and execution remain separate checks. The
clipboard port keeps primary-selection preference, soft-wrap copying,
host sync/flush, paste callback routing, and scroll reset behavior.

Full application, Rill host, and whole-application Plan 9 builds still use
legacy k2c and Kryon C headers. Current Kryon no longer exposes that API,
so these builds are not established by the independent pane checks. Keep
the existing pipeline until the remaining app/engine/runtime modules move
to Ziran and current Kryon bindings.

Kapsule's preserved OSC52 adapter changed the old four-argument
`HandleClipboardOSC52` callback API to its later three-argument form with
`ClipboardOSC52Write`/`ClipboardPasteWrite` host entrypoints. The transition
engine still calls the older API. During its migration, retain bounded
OSC52 queries/writes and paste filtering in t9, and bind clipboard transport
to current Kryon's `SystemClipboardText`/`SystemClipboardSet`. The pane's
foreign clipboard-provider names are likewise a transition ABI; hosted
tests supply them explicitly rather than claiming current Kryon implements
those legacy entrypoints.

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

`tests/ziran_migration_test.sh` rejects the obsolete rewrite document and any
future module restored alongside its `.zi` replacement.
