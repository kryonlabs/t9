#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY ENV BASH_ENV
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
mkdir -p build/ziran
work=$(mktemp -d "$root/build/ziran/config-test.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
entry=terminal_config_test:main
source=tests/terminal_config_test.zi
"$ziran" ir --project $lock_flags --entry "$entry" -o "$work/ir" "$source"
for form in source saved; do
    input=$source
    if test "$form" = saved; then input=$work/ir/terminal_config_test.zir; fi
    "$ziran" build --project $lock_flags --target=c --entry "$entry" \
        --exe -o "$work/$form-c" "$input"
    (cd "$work/$form-c" && timeout --kill-after=2s 10s ./terminal_config_test)
    "$ziran" build --project $lock_flags --target=cpp --entry "$entry" \
        -o "$work/$form-cpp" "$input"
    "${CXX:-c++}" -std=c++17 -O2 -I"$work/$form-cpp" \
        "$work/$form-cpp"/*.cpp -o "$work/$form-cpp/run"
    (cd "$work/$form-cpp" && timeout --kill-after=2s 10s ./run)
done
echo 'Terminal configuration source and saved IR passed C and C++ execution'
