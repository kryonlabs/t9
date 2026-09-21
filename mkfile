< /$objtype/mkfile

# Native Plan 9 build of t9 with the Kryon libdraw backend.
#
# The terminal engine, pane, and app modules are authored in .kry and
# compiled ahead of time on the host (`make kry-c-plan9` in this tree
# emits 8c-safe C plus the generated-c-files.txt list). The remaining
# handwritten C is the process boundary: terminal_pty_plan9.c owns the
# Plan 9 files/processes side of terminal_pty.h, and main.c is the
# executable entry shim.

TARG=t9
ROOT=/sys/src/t9

# engine/process.c drives the Linux PTY boundary; Plan 9 keeps its own
# integrated process implementation in terminal_pty_plan9.c until that
# side converges on terminal_pty.h, so the generated process module is
# excluded to avoid duplicate engine symbols.
gensrc=`{cat $ROOT/build/plan9/generated-c-files.txt | grep -v 'engine/process.c' }
appsrc=\
	src/main.c\
	src/terminal_pty_plan9.c\

APPCPPFLAGS=-I$ROOT/src -I$ROOT/build/plan9/generated/src -I$ROOT/build/plan9/generated

< /sys/src/kryon/mk/plan9-app.mk
