#!/bin/sh
# Build and execute one pane suite with native 8c/8l in private QEMU.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
suite=${1:-keys}
case "$suite" in
    keys|osc|metrics|clipboard|selection) module=terminal_pane_${suite}_test ;;
    protocol) module=terminal_clipboard_test ;;
    pty) module=terminal_pty_plan9_test ;;
    engine) module=terminal_engine_test ;;
    *) echo "Unknown Terminal suite: $suite" >&2; exit 2 ;;
esac
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY
taiji=$(CDPATH= cd -- "${TAIJI_DIR:?Set TAIJI_DIR to the canonical Taiji checkout}" && pwd)
test -x "$taiji/q9"
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
mkdir -p build/ziran "$taiji/usr/glenda/tmp"
exec 9>build/ziran/pane-native-plan9.lock
if ! flock -n 9; then
    echo 'A Terminal pane native Plan 9 gate is already running' >&2
    exit 1
fi
work=$(mktemp -d "$root/build/ziran/$suite-native.XXXXXX")
stage=$(mktemp -d "$taiji/usr/glenda/tmp/t9-$suite.XXXXXX")
guest_stage=/usr/glenda/tmp/${stage##*/}
cleanup() {
    if test -f "$work/native-plan9.log"; then
        cp "$work/native-plan9.log" "$root/build/ziran/$suite-native-plan9.log"
    fi
    rm -rf "$work" "$stage"
}
trap cleanup EXIT HUP INT TERM
entry=$module:main
"$ziran" ir --project $lock_flags --define PLAN9 --entry "$entry" -o "$work/ir" \
    "tests/$module.zi"
"$ziran" build --project $lock_flags --target=plan9-c --entry "$entry" \
    -o "$stage/source" "tests/$module.zi"
"$ziran" build --project $lock_flags --target=plan9-c --root "$work/ir" \
    --entry "$entry" -o "$stage/saved" "$work/ir/$module.zir"
command="
failed=0
for(suite in source saved) {
    if(~ \$failed 0) {
        cd $guest_stage/\$suite
        echo t9-$suite-plan9-compile \$suite
        for(source in *.c) {
            if(! 8c -FTVw \$source) {
                echo t9-$suite-plan9-compile-failed
                failed=1
            }
        }
        if(~ \$failed 0) {
            if(8l -o run *.8) {
                echo t9-$suite-plan9-running \$suite
                if(./run) echo t9-$suite-plan9-suite-ok \$suite
                if not {
                    echo t9-$suite-plan9-run-failed \$status
                    failed=1
                }
            }
            if not {
                echo t9-$suite-plan9-link-failed
                failed=1
            }
        }
    }
}
if(~ \$failed 0) echo t9-$suite-plan9-ok
fshalt
"
log=$work/native-plan9.log
timeout=${T9_PLAN9_TIMEOUT:-120}
setsid --wait env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY Q9_BOOT_TIMEOUT="$timeout" Q9_TMPDIR="$work" \
    Q9_MEM="${T9_PLAN9_MEMORY:-256M}" Q9_SMP=1 Q9_CHECKPOINT=0 Q9_BUILD_DESKTOP=0 \
    "$taiji/q9" --raw tty-run "$command" >"$log" 2>&1 &
vm_pid=$!
stop_vm() {
    kill -TERM -"$vm_pid" 2>/dev/null || kill -TERM "$vm_pid" 2>/dev/null || true
    wait "$vm_pid" 2>/dev/null || true
}
trap 'stop_vm; cleanup' EXIT HUP INT TERM
start=$(date +%s)
while test "$(( $(date +%s) - start ))" -lt "$timeout"; do
    if rg -q "^t9-$suite-plan9-ok" "$log"; then
        stop_vm
        cp "$log" "$root/build/ziran/$suite-native-plan9.log"
        trap cleanup EXIT HUP INT TERM
        echo "Terminal $suite source and saved IR passed native Plan 9 8c/8l execution"
        exit 0
    fi
    if rg -q "^t9-$suite-plan9-(compile|link|run)-failed|Operation not permitted|cannot init 9P|can.t init 9P" "$log"; then
        tail -50 "$log" >&2
        exit 1
    fi
    if ! kill -0 "$vm_pid" 2>/dev/null; then
        echo "Terminal $suite VM exited before the result" >&2
        tail -50 "$log" >&2
        exit 1
    fi
    sleep 2
done
echo "Terminal $suite native Plan 9 test timed out" >&2
tail -50 "$log" >&2
exit 1
