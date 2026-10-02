#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY ENV BASH_ENV
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
mkdir -p build/ziran
work=$(mktemp -d "$root/build/ziran/pty-test.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
# Exercise the real PTY and exec boundary without loading owner shell profiles.
cat > "$work/shell" <<'SHELL'
#!/bin/sh
exec /bin/sh -c "$2"
SHELL
chmod 700 "$work/shell"
entry=terminal_pty_linux_test:main
source=tests/terminal_pty_linux_test.zi
"$ziran" ir --project $lock_flags --entry "$entry" -o "$work/ir" "$source"
for input in source saved; do
    module=$source
    if test "$input" = saved; then module=$work/ir/terminal_pty_linux_test.zir; fi
    "$ziran" build --project $lock_flags --target=c --entry "$entry" \
        --exe -o "$work/$input-c" "$module"
    T9_TEST_SHELL="$work/shell" timeout --kill-after=2s 10s "$work/$input-c/terminal_pty_linux_test"
    "$ziran" build --project $lock_flags --target=cpp --entry "$entry" \
        -o "$work/$input-cpp" "$module"
    "${CXX:-c++}" -std=c++17 -O2 -I"$work/$input-cpp" "$work/$input-cpp"/*.cpp \
        -o "$work/$input-cpp/test"
    T9_TEST_SHELL="$work/shell" timeout --kill-after=2s 10s "$work/$input-cpp/test"
done
echo 'Terminal Linux PTY source and saved IR passed C and C++ execution'
