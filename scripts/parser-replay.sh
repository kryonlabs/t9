#!/bin/sh
# Compile and run the Ziran parser benchmark without a graphics host.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY ENV BASH_ENV
target=${1:-c}
form=${2:-source}
case "$target" in c|cpp) ;; *) echo 'Expected c or cpp' >&2; exit 2 ;; esac
case "$form" in source|saved) ;; *) echo 'Expected source or saved' >&2; exit 2 ;; esac
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
mkdir -p build/ziran
work=$(mktemp -d "$root/build/ziran/parser-replay.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
input=benchmarks/parser_replay.zi
if test "$form" = saved; then
    "$ziran" ir --project $lock_flags --entry parser_replay:main -o "$work/ir" "$input"
    input=$work/ir/parser_replay.zir
fi
"$ziran" build --project $lock_flags --target="$target" --entry parser_replay:main \
    -o "$work/generated" "$input"
if test "$target" = c; then compiler=${CC:-cc}; standard=c11; extension=c
else compiler=${CXX:-c++}; standard=c++17; extension=cpp; fi
"$compiler" -std="$standard" -O2 -I"$work/generated" \
    "$work/generated"/*."$extension" -o "$work/run"
timeout --kill-after=2s "${T9_BENCH_TIMEOUT:-30}s" "$work/run"
