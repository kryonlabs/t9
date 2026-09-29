# T9 Ziran migration

T9's maintained source language is Ziran (`.zi`). Legacy `.kry` files are
migration input only: each one is removed after its behavior has a current
Ziran implementation and focused hosted/Plan 9 checks. No compatibility
compiler path, dual product module, or `.kry` restore is part of the target.

Current status: 10 pane modules are Ziran sources and 44 legacy `.kry`
inputs remain across the pane, engine, app, and runtime boundaries. The current
boundary is the legacy C-header/K2C API. Remaining modules must be
expressed as Ziran types and explicit foreign/host bindings, then linked to the
current Ziran-based Kryon library. The migration is complete only when no
`.kry` product source remains and Linux, Rill, and native Plan 9 builds use the
same `.zi` implementation.

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

`tests/ziran_migration_test.sh` rejects the obsolete rewrite document and any
future module restored alongside its `.zi` replacement.
