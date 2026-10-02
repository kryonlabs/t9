#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
mkdir -p build/ziran
work=$(mktemp -d "$root/build/ziran/keys-test.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
entry=terminal_pane_keys_test:main
source=tests/terminal_pane_keys_test.zi

"$ziran" build --project $lock_flags --target=c --entry "$entry" --exe \
    -o "$work/c" "$source"
"$work/c/terminal_pane_keys_test"
"$ziran" build --project $lock_flags --target=cpp --entry "$entry" \
    -o "$work/cpp" "$source"
"${CXX:-c++}" -std=c++17 -O2 -I"$work/cpp" "$work/cpp"/*.cpp \
    -o "$work/cpp/test"
"$work/cpp/test"
"$ziran" ir --project $lock_flags --entry "$entry" -o "$work/ir" "$source"
"$ziran" build --project $lock_flags --target=c --root "$work/ir" \
    --entry "$entry" --exe -o "$work/ir-c" "$work/ir/terminal_pane_keys_test.zir"
"$work/ir-c/terminal_pane_keys_test"
"$ziran" build --project $lock_flags --target=plan9-c --entry "$entry" \
    -o "$work/plan9" "$source"
echo 'Terminal keyboard source, saved IR, C, C++, and Plan 9 generation passed'
