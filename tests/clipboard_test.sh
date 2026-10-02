#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
suite=${1:-clipboard}
case "$suite" in
    clipboard|selection) module=terminal_pane_${suite}_test ;;
    protocol) module=terminal_clipboard_test ;;
    *) echo "Unknown clipboard suite: $suite" >&2; exit 2 ;;
esac
mkdir -p build/ziran
work=$(mktemp -d "$root/build/ziran/$suite-test.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
# The imported fixture exports exactly Kryon's three native host symbols.
entry=$module:main
source=tests/$module.zi
"$ziran" ir --project $lock_flags --entry "$entry" -o "$work/ir" "$source"
for input in source saved; do
    file=$source
    if test "$input" = saved; then file=$work/ir/$module.zir; fi
    "$ziran" build --project $lock_flags --target=c --entry "$entry" \
        --exe -o "$work/$input-c" "$file"
    "$work/$input-c/$module"
    "$ziran" build --project $lock_flags --target=cpp --entry "$entry" \
        -o "$work/$input-cpp" "$file"
    "${CXX:-c++}" -std=c++17 -O2 -I"$work/$input-cpp" "$work/$input-cpp"/*.cpp \
        -o "$work/$input-cpp/run"
    "$work/$input-cpp/run"
done
"$ziran" build --project $lock_flags --target=plan9-c --entry "$entry" \
    -o "$work/plan9" "$source"
echo "Terminal $suite source and saved IR passed C and C++ execution"
