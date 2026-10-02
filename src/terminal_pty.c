#if !defined(_POSIX_C_SOURCE)
#define _POSIX_C_SOURCE 200809L
#endif
#if !defined(_XOPEN_SOURCE)
#define _XOPEN_SOURCE 600
#endif
#if !defined(_DEFAULT_SOURCE)
#define _DEFAULT_SOURCE
#endif

#include "terminal_pty.h"

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

static int wait_for_child_exit(int pid, int timeout_ms)
{
    int elapsed = 0;
    int status;

    if(pid <= 0)
        return 1;
    for(;;) {
        int result = waitpid(pid, &status, WNOHANG);

        if(result > 0 || (result < 0 && errno == ECHILD))
            return 1;
        if(result < 0 && errno == EINTR)
            continue;
        if(result < 0)
            return 1;
        if(elapsed >= timeout_ms)
            return 0;
        usleep(10000);
        elapsed += 10;
    }
}

static void signal_terminal_process_group(int pid, int signal_number)
{
    if(pid <= 0)
        return;
    if(kill(-pid, signal_number) != 0)
        kill(pid, signal_number);
}

static void set_window_size(int fd, int cols, int rows)
{
    struct winsize size;

    memset(&size, 0, sizeof(size));
    size.ws_col = (unsigned short)cols;
    size.ws_row = (unsigned short)rows;
    ioctl(fd, TIOCSWINSZ, &size);
}

static int shell_is_bash(const char *shell)
{
    const char *name;

    if(shell == NULL)
        return 0;
    name = strrchr(shell, '/');
    name = name != NULL ? name + 1 : shell;
    return strcmp(name, "bash") == 0;
}

static int
path_segment_matches(const char *segment, size_t length, const char *value)
{
    size_t value_len;

    if(segment == NULL || value == NULL)
        return 0;
    value_len = strlen(value);
    return value_len == length && strncmp(segment, value, length) == 0;
}

static void
sanitize_terminal_child_path(void)
{
    const char *path = getenv("PATH");
    const char *plan9 = getenv("PLAN9");
    char plan9_bin[512];
    char clean[4096];
    const char *segment;
    size_t used = 0;
    int changed = 0;

    if(path == NULL || path[0] == '\0' ||
       plan9 == NULL || plan9[0] == '\0')
        return;
    snprintf(plan9_bin, sizeof(plan9_bin), "%s/bin", plan9);
    clean[0] = '\0';

    segment = path;
    while(segment != NULL) {
        const char *end = strchr(segment, ':');
        size_t len = end != NULL ? (size_t)(end - segment)
                                 : strlen(segment);

        if(path_segment_matches(segment, len, plan9_bin)) {
            changed = 1;
        } else if(used + len + 2 < sizeof(clean)) {
            if(used > 0)
                clean[used++] = ':';
            memcpy(clean + used, segment, len);
            used += len;
            clean[used] = '\0';
        }
        segment = end != NULL ? end + 1 : NULL;
    }

    if(changed && clean[0] != '\0')
        setenv("PATH", clean, 1);
}

int TerminalPtyOpen(const char *cwd, const char *shell, const char *command,
                    int cols, int rows, int *out_pid)
{
    int master;
    int pid;

    if(out_pid == NULL)
        return -1;
    *out_pid = -1;
    master = posix_openpt(O_RDWR | O_NOCTTY);
    if(master < 0)
        return -1;
    if(grantpt(master) != 0 || unlockpt(master) != 0) {
        close(master);
        return -1;
    }
    set_window_size(master, cols, rows);
    pid = fork();
    if(pid < 0) {
        close(master);
        return -1;
    }
    if(pid == 0) {
        const char *slave_name = ptsname(master);
        const char *run_shell;
        char slave_path[256];
        int slave;

        if(slave_name == NULL)
            _exit(127);
        snprintf(slave_path, sizeof(slave_path), "%s", slave_name);
        setsid();
        close(master);
        slave = open(slave_path, O_RDWR);
        if(slave < 0)
            _exit(127);
#ifdef TIOCSCTTY
        ioctl(slave, TIOCSCTTY, 0);
#endif
        dup2(slave, 0);
        dup2(slave, 1);
        dup2(slave, 2);
        if(slave > 2)
            close(slave);
        if(cwd != NULL && cwd[0] != '\0' && chdir(cwd) != 0)
            _exit(127);
        setenv("TERM", "xterm-256color", 1);
        setenv("COLORTERM", "truecolor", 1);
        sanitize_terminal_child_path();
        run_shell = shell;
        if(run_shell == NULL || run_shell[0] == '\0')
            run_shell = getenv("SHELL");
        if(run_shell == NULL || run_shell[0] == '\0')
            run_shell = "/bin/sh";
        if(command != NULL && command[0] != '\0') {
            if(shell_is_bash(run_shell))
                execl(run_shell, run_shell, "-i", "-c", command, (char *)NULL);
            else
                execl(run_shell, run_shell, "-lc", command, (char *)NULL);
        }
        else
            execl(run_shell, run_shell, "-i", (char *)NULL);
        _exit(127);
    }
    {
        int flags = fcntl(master, F_GETFL, 0);

        if(flags >= 0)
            fcntl(master, F_SETFL, flags | O_NONBLOCK);
    }
    *out_pid = pid;
    return master;
}

int TerminalPtyWrite(int fd, const void *data, int size)
{
    int written;

    if(fd < 0 || data == NULL || size <= 0)
        return 0;
    written = (int)write(fd, data, (size_t)size);
    return written > 0 ? written : 0;
}

int TerminalPtyRead(int fd, void *buffer, int buffer_size)
{
    int got;

    if(fd < 0 || buffer == NULL || buffer_size <= 0)
        return -1;
    got = (int)read(fd, buffer, (size_t)buffer_size);
    if(got > 0)
        return got;
    if(got == 0)
        return -1;
    if(errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK)
        return 0;
    return -1;
}

void TerminalPtyResize(int fd, int cols, int rows)
{
    if(fd >= 0)
        set_window_size(fd, cols, rows);
}

int TerminalPtyChildExited(int pid)
{
    int status;

    if(pid <= 0)
        return 1;
    return waitpid(pid, &status, WNOHANG) > 0;
}

void TerminalPtySignal(int pid, int signal_number)
{
    signal_terminal_process_group(pid, signal_number);
}

int TerminalPtyWaitExit(int pid, int timeout_ms)
{
    return wait_for_child_exit(pid, timeout_ms);
}

void TerminalPtyClose(int fd)
{
    if(fd >= 0)
        close(fd);
}
