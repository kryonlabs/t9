# AGENTS.md — t9

t9 is the Terminal application in the Taiji OS organization, built on Kryon.
Its canonical checkout is `taijiosnet/t9`; Kapsule's history belongs here.

- Keep terminal emulator code in this repository.
- Do not add t9 product code, parser behavior, terminal UI, or app state to
  Kryon. Reusable Kryon changes belong in its canonical `kryonlabs/kryon`
  repository, never a dependency copy.
- Add code to Kryon only when it is a small reusable primitive that more than
  one project needs.
- Use direct names for t9 APIs and types: `Terminal`, `Cell`, `Session`,
  `Palette`. Do not add artificial `Kry*` prefixes.
- Resolve dependencies with `scripts/ziran.sh`, `ziran.toml`, and `ziran.lock`.
  Canonical local paths belong only in ignored `ziran.local.toml` overrides.
- Continue the Ziran migration in `docs/ZIRAN_MIGRATION.md`; retain one product
  implementation per module. Focused pane tests work without legacy Kryon.
- Run display-affecting tests only on a private Xvfb display, with inherited
  `DISPLAY` and `WAYLAND_DISPLAY` scrubbed and window operations scoped to
  the tested process.

## Bend

When using Bend:
- run `bend guide` to learn it
- use `LAWS.bend` to keep important rules
- run `bend PROOF.bend` before committing
- parallelize the code whenever possible
