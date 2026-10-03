#!/bin/sh
# Compile the real executable with native 8c/8l and run its non-graphical routes.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY
form=${1:-source}
case "$form" in source|saved) ;; *) echo "Unknown Terminal source form: $form" >&2; exit 2 ;; esac
taiji=$(CDPATH= cd -- "${TAIJI_DIR:?Set TAIJI_DIR to the canonical Taiji checkout}" && pwd)
ziran=${ZIRAN:-"$root/scripts/ziran.sh"}
lock_flags=
if test ! -f ziran.local.toml; then lock_flags=--locked; fi
mkdir -p build/ziran "$taiji/usr/glenda/tmp"
exec 9>build/ziran/pane-native-plan9.lock
flock -n 9 || { echo 'A Terminal native Plan 9 test is already running' >&2; exit 1; }
work=$(mktemp -d "$root/build/ziran/standalone-native.XXXXXX")
stage=$(mktemp -d "$taiji/usr/glenda/tmp/t9-standalone.XXXXXX")
guest=/usr/glenda/tmp/${stage##*/}
vm_pid=
cleanup() {
    if test -n "$vm_pid"; then
        kill -TERM -"$vm_pid" 2>/dev/null || kill -TERM "$vm_pid" 2>/dev/null || true
        wait "$vm_pid" 2>/dev/null || true
    fi
    if test -f "$work/native-plan9.log"; then
        cp "$work/native-plan9.log" "$root/build/ziran/standalone-$form-native-plan9.log"
    fi
    rm -rf "$work" "$stage"
}
trap cleanup EXIT HUP INT TERM
cat > "$work/qemu" <<'QEMU'
#!/bin/sh
exec "$T9_PLAN9_QEMU" -accel tcg,tb-size=32 "$@"
QEMU
chmod 700 "$work/qemu"
if test "$form" = source; then
    "$ziran" build --project $lock_flags --target=plan9-c --no-main \
        -o "$stage/source" src/app/app_main.zi
else
    "$ziran" ir --project $lock_flags --define PLAN9 --entry app_main:threadmain \
        -o "$work/ir" src/app/app_main.zi
    "$ziran" build --project $lock_flags --target=plan9-c --no-main --root "$work/ir" \
        -o "$stage/saved" "$work/ir/app_main.zir"
fi
command="
failed=0
for(form in $form) {
    if(~ \$failed 0) {
        cd $guest/\$form
        for(source in *.c) {
            if(! 8c -FTVw \$source > compile.txt >[2=1]) {
                cat compile.txt
                echo t9-standalone-plan9-compile-failed
                failed=1
            }
        }
        if(~ \$failed 0) {
            if(! 8l -o t9 *.8 -ldraw -lmemdraw -lthread -lflate) {
                echo t9-standalone-plan9-link-failed
                failed=1
            }
        }
        if(~ \$failed 0) {
            if(! ./t9 --help > help.txt || ! grep 'usage: t9' help.txt) failed=1
            if(! ./t9 --version > version.txt || ! grep 't9 0.1' version.txt) failed=1
            if(! ./t9 --color-table > colors.txt || ! test -s colors.txt) failed=1
            if(./t9 --geometry bad >[2]error.txt) failed=1
            if(! grep 'invalid geometry' error.txt) failed=1
            echo existing > control.txt
            rillctl=$guest/\$form/control.txt ./t9
            if(! grep '^existing' control.txt || ! grep '^open t9' control.txt) failed=1
            if(~ \$failed 0) echo t9-standalone-plan9-suite-ok \$form
            if not echo t9-standalone-plan9-run-failed
        }
    }
}
if(~ \$failed 0) echo t9-standalone-plan9-ok
fshalt
"
limit=${T9_PLAN9_TIMEOUT:-120}
log=$work/native-plan9.log
setsid --wait env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY \
    Q9_BOOT_TIMEOUT="$limit" Q9_TMPDIR="$work" Q9_MEM=256M Q9_SMP=1 \
    Q9_CHECKPOINT=0 Q9_BUILD_DESKTOP=0 T9_PLAN9_QEMU="${QEMU:-qemu-system-x86_64}" \
    QEMU="$work/qemu" "$taiji/q9" --raw tty-run "$command" > "$log" 2>&1 &
vm_pid=$!
started=$(date +%s)
while test "$(( $(date +%s) - started ))" -lt "$limit"; do
    if rg -q '^t9-standalone-plan9-ok' "$log"; then
        echo "Terminal executable $form passed native Plan 9 build, CLI and Rill forwarding checks"
        exit 0
    fi
    if rg -q '^t9-standalone-plan9-(compile|link|run)-failed|Operation not permitted|cannot init 9P|can.t init 9P' "$log"; then
        tail -50 "$log" >&2
        exit 1
    fi
    if ! kill -0 "$vm_pid" 2>/dev/null; then
        echo 'The Terminal native VM exited before its result' >&2
        tail -50 "$log" >&2
        exit 1
    fi
    sleep 2
done
echo 'Terminal executable native Plan 9 test timed out' >&2
tail -50 "$log" >&2
exit 1
