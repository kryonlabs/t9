#!/bin/sh
# Build and execute this suite with native 8c/8l inside Taiji's private QEMU.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY
taiji=$(CDPATH= cd -- "${TAIJI_DIR:?Set TAIJI_DIR to the canonical Taiji checkout}" && pwd)
test -x "$taiji/q9"
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
mkdir -p build/ziran "$taiji/usr/glenda/tmp"
exec 9>build/ziran/keys-native-plan9.lock
if ! flock -n 9; then
    echo 'A Terminal keyboard native Plan 9 gate is already running' >&2
    exit 1
fi
work=$(mktemp -d "$root/build/ziran/keys-native.XXXXXX")
stage=$(mktemp -d "$taiji/usr/glenda/tmp/t9-keys.XXXXXX")
guest_stage=/usr/glenda/tmp/${stage##*/}
cleanup() { rm -rf "$work" "$stage"; }
trap cleanup EXIT HUP INT TERM
entry=terminal_pane_keys_test:main
"$ziran" ir --project $lock_flags --entry "$entry" -o "$work/ir" \
    tests/terminal_pane_keys_test.zi
"$ziran" build --project $lock_flags --target=plan9-c --entry "$entry" \
    -o "$stage/source" tests/terminal_pane_keys_test.zi
"$ziran" build --project $lock_flags --target=plan9-c --root "$work/ir" \
    --entry "$entry" -o "$stage/saved" "$work/ir/terminal_pane_keys_test.zir"
command="
failed=0
for(suite in source saved) {
    if(~ \$failed 0) {
        cd $guest_stage/\$suite
        for(source in *.c) {
            if(! 8c -FTVw \$source) {
                echo t9-keys-plan9-compile-failed
                failed=1
            }
        }
        if(~ \$failed 0) {
            if(8l -o run *.8) {
                if(./run) echo t9-keys-plan9-suite-ok \$suite
                if not {
                    echo t9-keys-plan9-run-failed
                    failed=1
                }
            }
            if not {
                echo t9-keys-plan9-link-failed
                failed=1
            }
        }
    }
}
if(~ \$failed 0) echo t9-keys-plan9-ok
fshalt
"
log=$work/native-plan9.log
timeout=${T9_PLAN9_TIMEOUT:-300}
setsid env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY Q9_BOOT_TIMEOUT="$timeout" Q9_TMPDIR="$work" \
    "$taiji/q9" --raw tty-run "$command" >"$log" 2>&1 &
vm_pid=$!
stop_vm() {
    kill -TERM -"$vm_pid" 2>/dev/null || kill -TERM "$vm_pid" 2>/dev/null || true
    wait "$vm_pid" 2>/dev/null || true
}
trap 'stop_vm; cleanup' EXIT HUP INT TERM
start=$(date +%s)
while test "$(( $(date +%s) - start ))" -lt "$timeout"; do
    if rg -q '^t9-keys-plan9-ok' "$log"; then
        stop_vm
        cp "$log" "$root/build/ziran/keys-native-plan9.log"
        trap cleanup EXIT HUP INT TERM
        echo 'Terminal keyboard source and saved IR passed native Plan 9 8c/8l execution'
        exit 0
    fi
    if rg -q '^t9-keys-plan9-(compile|link|run)-failed|Operation not permitted|cannot init 9P|can.t init 9P' "$log"; then
        tail -50 "$log" >&2
        exit 1
    fi
    if ! kill -0 "$vm_pid" 2>/dev/null; then
        echo 'Terminal keyboard VM exited before the result' >&2
        tail -50 "$log" >&2
        exit 1
    fi
    sleep 2
done
echo 'Terminal keyboard native Plan 9 test timed out' >&2
tail -50 "$log" >&2
exit 1
