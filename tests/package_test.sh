#!/bin/sh
# Generated consumer output, not a checkout or a copy of Terminal product code.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS ENV BASH_ENV
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
compiler=$("$ziran" pkg path ziran $lock_flags)/build/bin/ziran
kryon=$("$ziran" pkg path kryon $lock_flags)
mkdir -p build/ziran
work=$(mktemp -d "$root/build/ziran/package-test.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/src"
cp tests/package_consumer.zi "$work/src/consumer.zi"
cp tests/terminal_pane_widget_host.zi tests/terminal_clipboard_host.zi "$work/src/"
cat > "$work/ziran.toml" <<'MANIFEST'
[package]
name = "terminal_consumer"
entry = "src/consumer.zi"
module_roots = ["src"]

[toolchain]
git = "https://github.com/ziranlang/ziran.git"
ref = "master"

[dependencies.kryon]
git = "https://github.com/kryonlabs/kryon.git"
ref = "master"
MANIFEST
python3 - "$work/ziran.local.toml" "$root" "$compiler" "$kryon" <<'PY'
import json
import pathlib
import sys
path, terminal, compiler, kryon = sys.argv[1:]
toolchain = str(pathlib.Path(compiler).parents[2])
pathlib.Path(path).write_text('[overrides]\n' + ''.join(
    f'{name} = {json.dumps(value)}\n'
    for name, value in [('ziran', toolchain), ('t9', terminal), ('kryon', kryon)]))
PY
cd "$work"
"$compiler" add https://github.com/taijiosnet/t9.git
"$compiler" check --project src/consumer.zi
"$compiler" ir --project --entry consumer:main -o ir src/consumer.zi
for form in source saved; do
    input=src/consumer.zi
    if test "$form" = saved; then input=ir/consumer.zir; fi
    "$compiler" build --project --target=c --entry consumer:main --exe -o "$form-c" "$input"
    timeout --kill-after=2s 15s "./$form-c/consumer"
    "$compiler" build --project --target=cpp --entry consumer:main -o "$form-cpp" "$input"
    "${CXX:-c++}" -std=c++17 -O1 -I"$form-cpp" "$form-cpp"/*.cpp -o "$form-cpp/run"
    timeout --kill-after=2s 15s "./$form-cpp/run"
done
echo 'External t9 package consumer passed C/C++ from source and saved IR'
