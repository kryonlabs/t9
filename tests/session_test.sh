#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY ENV BASH_ENV
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
mkdir -p build/ziran
work=$(mktemp -d "$root/build/ziran/session-test.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat > "$work/shell" <<'SHELL'
#!/bin/sh
exec /bin/sh -c "$2"
SHELL
chmod 700 "$work/shell"
entry=terminal_session_test:main
source=tests/terminal_session_test.zi
"$ziran" ir --project $lock_flags --entry "$entry" -o "$work/ir" "$source"
for form in source saved; do
    input=$source
    if test "$form" = saved; then input=$work/ir/terminal_session_test.zir; fi
    "$ziran" build --project $lock_flags --target=c --entry "$entry" \
        --exe -o "$work/$form-c" "$input"
    (cd "$work/$form-c" && T9_TEST_SHELL="$work/shell" timeout --kill-after=2s 15s ./terminal_session_test)
    "$ziran" build --project $lock_flags --target=cpp --entry "$entry" \
        -o "$work/$form-cpp" "$input"
    "${CXX:-c++}" -std=c++17 -O1 -I"$work/$form-cpp" \
        "$work/$form-cpp"/*.cpp -o "$work/$form-cpp/run"
    (cd "$work/$form-cpp" && T9_TEST_SHELL="$work/shell" timeout --kill-after=2s 15s ./run)
done
echo 'Terminal sessions source and saved IR passed C/C++ metadata, persistence and real child I/O'
