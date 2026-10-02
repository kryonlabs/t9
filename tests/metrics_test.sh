#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
mkdir -p build/ziran
work=$(mktemp -d "$root/build/ziran/metrics-test.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
entry=terminal_pane_metrics_test:main
source=tests/terminal_pane_metrics_test.zi
"$ziran" ir --project $lock_flags --entry "$entry" -o "$work/ir" "$source"
for input in source saved; do
    module=$source
    if test "$input" = saved; then module=$work/ir/terminal_pane_metrics_test.zir; fi
    "$ziran" build --project $lock_flags --target=c --entry "$entry" \
        --exe -o "$work/$input-c" "$module"
    "$work/$input-c/terminal_pane_metrics_test"
    "$ziran" build --project $lock_flags --target=cpp --entry "$entry" \
        -o "$work/$input-cpp" "$module"
    "${CXX:-c++}" -std=c++17 -O2 -I"$work/$input-cpp" "$work/$input-cpp"/*.cpp \
        -o "$work/$input-cpp/test"
    "$work/$input-cpp/test"
    "$ziran" build --project $lock_flags --target=go --pkg main --entry "$entry" \
        --exe -o "$work/$input-go" "$module"
    env GO111MODULE=off go run "$work/$input-go"/*.go
    "$ziran" bundle --project $lock_flags --entry "$entry" \
        -o "$work/$input.zib" "$module"
    test "$("$ziran" run "$work/$input.zib")" = 0
done
cmp "$work/source.zib" "$work/saved.zib"
"$ziran" build --project $lock_flags --target=plan9-c --entry "$entry" \
    -o "$work/plan9" "$source"
echo 'Terminal pane metrics source, saved IR, native targets, and portable bundles passed'
