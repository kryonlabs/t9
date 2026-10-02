#ifndef KTREM_TERMINAL_PTY_H
#define KTREM_TERMINAL_PTY_H

/*
 * Native process boundary. These calls are the only places t9 talks
 * to operating-system process and file-descriptor services for the
 * terminal. Implementations are current Ziran: terminal_pty_linux.zi and
 * terminal_pty_plan9.zi. This declaration-only header serves the remaining
 * legacy engine during its migration; generated output is built from .zi.
 */

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Fork a child on a fresh pseudo terminal. Returns the master fd and
 * the child pid, or -1 when the spawn failed. The child runs `command`
 * through `shell` when given, otherwise an interactive shell. */
int TerminalPtyOpen(const char *cwd, const char *shell,
                    const char *command, int cols, int rows,
                    int *out_pid);

/* Write bytes to the child; returns the written count (>= 0). */
int TerminalPtyWrite(int fd, const void *data, int size);

/* Read pending output into buffer. Returns the byte count, 0 when
 * nothing is ready, and -1 when the child side closed or failed. */
int TerminalPtyRead(int fd, void *buffer, int buffer_size);

/* Push a new window size to the pseudo terminal. */
void TerminalPtyResize(int fd, int cols, int rows);

/* Non-blocking reap check: 1 when the child exited, 0 when alive. */
int TerminalPtyChildExited(int pid);

/* Signal the child's process group (falling back to the child). */
void TerminalPtySignal(int pid, int signal_number);

/* Wait up to timeout_ms for the child to exit: 1 when gone. */
int TerminalPtyWaitExit(int pid, int timeout_ms);

/* Close a master descriptor. */
void TerminalPtyClose(int fd);

#ifdef __cplusplus
}
#endif

#endif
