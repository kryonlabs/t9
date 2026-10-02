#!/bin/sh
set -eu

if [ -e docs/KRY_REWRITE_PLAN.md ]; then
    echo "docs/KRY_REWRITE_PLAN.md must not return; use docs/ZIRAN_MIGRATION.md" >&2
    exit 1
fi

status=0
for source in $(rg --files src -g '*.zi' | LC_ALL=C sort); do
    for extension in kry c; do
        legacy="${source%.zi}.$extension"
        if [ -e "$legacy" ]; then
            echo "both product sources exist: $legacy and $source" >&2
            status=1
        fi
    done
done
if [ -e runtime/terminal_pane.kry ]; then
    echo 'Legacy pane sizing must not return; use terminal_pane_metrics.zi' >&2
    status=1
fi
if [ -e src/terminal_pty.c ] || [ -e src/terminal_pty_plan9.c ]; then
    echo 'Terminal process transports must use their Ziran implementation' >&2
    status=1
fi
if rg --files src/engine -g '*.kry' -g '*.c' | rg -q .; then
    echo 'Terminal engine implementations must use the loaded Ziran modules' >&2
    status=1
fi
exit "$status"
