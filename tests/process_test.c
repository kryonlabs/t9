#include "terminal.h"

#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(void)
{
    TerminalState terminal;
    char line[256];
    int saw = 0;
    int i;
    int row;

    memset(&terminal, 0, sizeof(terminal));
    terminal_init(&terminal);
    if(!terminal_spawn(&terminal, "/", "/bin/sh", "printf PTY_SMOKE_OK; exit",
                       80, 24)) {
        fprintf(stderr, "spawn failed\n");
        return 1;
    }
    for(i = 0; i < 100 && !saw; i++) {
        terminal_poll(&terminal);
        for(row = 0; row < terminal.rows; row++) {
            terminal_line(&terminal, row, line, sizeof(line));
            if(strstr(line, "PTY_SMOKE_OK") != NULL)
                saw = 1;
        }
        if(!terminal_poll(&terminal))
            break;
        usleep(20000);
    }
    for(i = 0; i < 50 && terminal_poll(&terminal); i++)
        usleep(20000);
    terminal_close(&terminal);
    if(!saw) {
        fprintf(stderr, "did not see marker\n");
        return 1;
    }
    printf("ok process\n");
    return 0;
}
