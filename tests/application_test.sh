#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
suite=${1:-application}
case "$suite" in
    application) module=terminal_application_test ;;
    input) module=terminal_input_test ;;
    view) module=terminal_view_test ;;
    *) echo "Unknown Terminal application suite: $suite" >&2; exit 2 ;;
esac
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY ENV BASH_ENV
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
mkdir -p build/ziran
work=$(mktemp -d "$root/build/ziran/$suite-test.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat > "$work/shell" <<'SHELL'
#!/bin/sh
exec /bin/sh -c "$2"
SHELL
chmod 700 "$work/shell"
entry=$module:main
source=tests/$module.zi
"$ziran" ir --project $lock_flags --entry "$entry" -o "$work/ir" "$source"
for form in source saved; do
    input=$source
    if test "$form" = saved; then input=$work/ir/$module.zir; fi
    "$ziran" build --project $lock_flags --target=c --entry "$entry" \
        --exe -o "$work/$form-c" "$input"
    (cd "$work/$form-c" && T9_TEST_SHELL="$work/shell" timeout --kill-after=2s 15s "./$module")
    "$ziran" build --project $lock_flags --target=cpp --entry "$entry" \
        -o "$work/$form-cpp" "$input"
    "${CXX:-c++}" -std=c++17 -O1 -I"$work/$form-cpp" \
        "$work/$form-cpp"/*.cpp -o "$work/$form-cpp/run"
    (cd "$work/$form-cpp" && T9_TEST_SHELL="$work/shell" timeout --kill-after=2s 15s ./run)
done
echo "Terminal $suite source and saved IR passed C/C++ behavior checks"
