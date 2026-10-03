#!/bin/sh
# Run the actual executable from source and saved IR in C and C++.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS SESSION_MANAGER
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
mkdir -p build/ziran
work=$(mktemp -d "$root/build/ziran/standalone-test.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
archive=${RAYLIB_A:-"$root/build/linux-$(uname -m)/raylib/raylib/libraylib.a"}
test -f "$archive"
"$ziran" ir --project $lock_flags --entry app_main:main -o "$work/ir" src/app/app_main.zi
for form in source saved; do
    input=src/app/app_main.zi
    if test "$form" = saved; then input=$work/ir/app_main.zir; fi
    for target in c cpp; do
        output=$work/$form-$target
        ZIRAN="$ziran" RAYLIB_A="$archive" sh scripts/build.sh "$target" "$output" "$input"
        env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY -u DBUS_SESSION_BUS_ADDRESS -u SESSION_MANAGER \
            LP_NUM_THREADS=1 OMP_NUM_THREADS=1 xvfb-run -a -s '-screen 0 1024x768x24' \
            env T9_PRIVATE_XVFB=1 python3 tests/standalone_window_test.py "$output/bin/t9"
    done
done
echo 'Terminal executable source and saved IR passed real C/C++ window and child-process checks'
