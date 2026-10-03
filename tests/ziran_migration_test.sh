#!/bin/sh
set -eu

if [ -e docs/KRY_REWRITE_PLAN.md ]; then
    echo "docs/KRY_REWRITE_PLAN.md must not return; use docs/ZIRAN_MIGRATION.md" >&2
    exit 1
fi

status=0
if rg --files src -g '*.kry' -g '*.c' -g '*.cpp' -g '*.h' -g '*.hpp' | rg -q .; then
    echo 'Terminal product source and native declarations must come from Ziran' >&2
    status=1
fi
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
if [ -e src/terminal_pane/simple_terminal.c ] || [ -e src/simple_terminal.h ]; then
    echo 'Embedded panes must use the canonical Ziran Terminal engine' >&2
    status=1
fi
if rg --files src/engine -g '*.kry' -g '*.c' | rg -q .; then
    echo 'Terminal engine implementations must use the loaded Ziran modules' >&2
    status=1
fi
if [ -e benchmarks/parser_replay.c ]; then
    echo 'Parser replay must use the maintained Ziran Terminal implementation' >&2
    status=1
fi
for legacy in tests/terminal_test.c tests/process_test.c tests/terminal_pane_selection_test.c; do
    if [ -e "$legacy" ]; then
        echo "Retired old-Kryon fixture must not return: $legacy" >&2
        status=1
    fi
done
exit "$status"
