#!/bin/sh
set -eu

if [ -e docs/KRY_REWRITE_PLAN.md ]; then
    echo "docs/KRY_REWRITE_PLAN.md must not return; use docs/ZIRAN_MIGRATION.md" >&2
    exit 1
fi

status=0
for source in $(find src -type f -name '*.zi' | LC_ALL=C sort); do
    legacy="${source%.zi}.kry"
    if [ -e "$legacy" ]; then
        echo "both product sources exist: $legacy and $source" >&2
        status=1
    fi
done
exit "$status"
