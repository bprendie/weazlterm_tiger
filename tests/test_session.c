#define _DEFAULT_SOURCE
#include "session.h"
#include <assert.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

typedef struct {
    WTSession *session;
    char output[4096];
    size_t used;
    int sent;
} Capture;

static void capture(void *context, const void *data, size_t length)
{
    Capture *c = context;
    assert(length < sizeof(c->output) - c->used);
    memcpy(c->output + c->used, data, length);
    c->used += length;
    c->output[c->used] = 0;
    if (!c->sent && strstr(c->output, "READY")) {
        assert(!wt_session_send(c->session, "prime nug\n", 10));
        c->sent = 1;
    }
}

int main(void)
{
    WTSession session;
    Capture c;
    char *args[] = { "/bin/sh", "-c",
        "stty -echo; printf READY; IFS= read -r line; printf '\nGOT:%s\n' \"$line\"; stty size", NULL };
    alarm(10);
    assert(!wt_session_open(&session, "/bin/sh", args, 80, 24));
    assert(!wt_session_resize(&session, 100, 40));
    assert(wt_session_send(&session, "", WT_INPUT_CAPACITY + 1) == -1);
    memset(&c, 0, sizeof(c));
    c.session = &session;
    wt_session_run(&session, capture, &c);
    assert(strstr(c.output, "GOT:prime nug"));
    assert(strstr(c.output, "40 100"));
    assert(session.exited && !session.io_error);
    assert(WIFEXITED(session.status) && WEXITSTATUS(session.status) == 0);
    assert(wt_session_send(&session, "x", 1) == -1);
    wt_session_close(&session);
    args[2] = "trap '' HUP; exec sleep 100";
    assert(!wt_session_open(&session, "/bin/sh", args, 80, 24));
    wt_session_stop(&session);
    wt_session_run(&session, capture, &c);
    assert(session.exited);
    wt_session_close(&session);
    alarm(0);
    puts("session: real PTY, input, resize, queue bound, EOF, shutdown passed");
    return 0;
}
