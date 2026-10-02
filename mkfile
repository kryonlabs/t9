< /$objtype/mkfile

# Native Plan 9 build of t9 with the Kryon libdraw backend.
#
# The terminal engine, pane, and app modules are authored in .kry and
# compiled ahead of time on the host (`make kry-c-plan9` in this tree
# emits 8c-safe C plus the generated-c-files.txt list; Ziran owns the
# migrated .zi modules). The remaining
# process transport is Ziran on both platforms. The executable entry
# shim remains C until the application entrypoint migrates.

TARG=t9
ROOT=/sys/src/t9

# The shared engine/process module uses the Ziran Plan 9 transport.
gensrc=`{cat $ROOT/build/plan9/generated-c-files.txt}
appsrc=\
	src/main.c\

APPCPPFLAGS=-I$ROOT/src -I$ROOT/build/plan9/generated/src -I$ROOT/build/plan9/generated

< /sys/src/kryon/mk/plan9-app.mk
