#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
mkdir -p build/ziran
work=$(mktemp -d "$root/build/ziran/profile-test.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
for suite in profile_colors profile profile_prompt profile_settings sixel; do
    module=terminal_pane_${suite}_test
    entry=$module:main
    source=tests/$module.zi
    "$ziran" ir --project $lock_flags --entry "$entry" -o "$work/$suite-ir" "$source"
    for form in source saved; do
        input=$source
        if test "$form" = saved; then input=$work/$suite-ir/$module.zir; fi
        "$ziran" build --project $lock_flags --target=c --entry "$entry" \
            --exe -o "$work/$suite-$form-c" "$input"
        timeout 10 "$work/$suite-$form-c/$module"
        "$ziran" build --project $lock_flags --target=cpp --entry "$entry" \
            -o "$work/$suite-$form-cpp" "$input"
        "${CXX:-c++}" -std=c++17 -O1 -I"$work/$suite-$form-cpp" \
            "$work/$suite-$form-cpp"/*.cpp -o "$work/$suite-$form-cpp/run"
        timeout 10 "$work/$suite-$form-cpp/run"
    done
done
echo 'Terminal theme, profiles and sixel policy passed source and saved-IR C/C++ execution'
