#!/bin/sh
# Build the maintained Ziran application; dependency source stays in its package.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY

target=${1:-c}
output=${2:-build/linux-$(uname -m)}
input=${3:-src/app/app_main.zi}
case "$target" in c|cpp|plan9-c) ;; *) echo "Unknown Terminal target: $target" >&2; exit 2 ;; esac
mkdir -p "$output"
output=$(CDPATH= cd -- "$output" && pwd)
case "$output" in "$root"/build/*) ;; *) echo 'Terminal build output must be under build/' >&2; exit 2 ;; esac
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
generated=$output/generated
"$ziran" build --project $lock_flags --target="$target" --no-main --prune-stale \
    --root src -o "$generated" "$input"

if test "$target" = plan9-c; then
    (cd "$generated" && printf '%s\n' *.c) > "$output/generated-c-files.txt"
    echo "Terminal native Plan 9 sources: $generated"
    exit 0
fi

jobs=${T9_BUILD_JOBS:-1}
case "$jobs" in 1|2|3|4) ;; *) echo 'T9_BUILD_JOBS must be between 1 and 4' >&2; exit 2 ;; esac
if test -n "${RAYLIB_A:-}"; then
    raylib_archive=$RAYLIB_A
else
    raylib=$("$ziran" pkg path raylib $lock_flags)
    cmake -S "$raylib" -B "$output/raylib" -DPLATFORM=SDL \
        -DCMAKE_DISABLE_FIND_PACKAGE_SDL3=ON -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_EXAMPLES=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    cmake --build "$output/raylib" --parallel "$jobs"
    raylib_archive=$output/raylib/raylib/libraylib.a
fi
test -f "$raylib_archive"
if test "$target" = c; then compiler=${CC:-cc}; standard=c11; extension=c
else compiler=${CXX:-c++}; standard=c++17; extension=cpp; fi
mkdir -p "$output/bin"
temporary=$(mktemp "$output/bin/t9.XXXXXX")
trap 'rm -f "$temporary"' EXIT HUP INT TERM
"$compiler" -std="$standard" -O1 -ffunction-sections -fdata-sections \
    -I"$generated" "$generated"/*."$extension" -Wl,--gc-sections "$raylib_archive" \
    $(pkg-config --libs sdl2) -lGL -ldl -lpthread -lm -o "$temporary"
chmod 755 "$temporary"
mv "$temporary" "$output/bin/t9"
trap - EXIT HUP INT TERM
echo "Terminal executable: $output/bin/t9"
