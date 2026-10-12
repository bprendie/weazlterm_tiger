#define _DEFAULT_SOURCE
#include "session.h"
#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

typedef struct {
    WTSession *session;
    char *paste;
    char output[512];
    size_t used;
    int sent, cancel, cancelled;
} Capture;

static int receiver(int cancel)
{
    struct termios modes;
    unsigned char bytes[4096];
    unsigned char tail[7] = {0};
    int requested = 0;
    size_t offset = 0, total = 6 + 6 + WT_PASTE_LIMIT + 6;
    assert(!tcgetattr(0, &modes));
    cfmakeraw(&modes);
    assert(!tcsetattr(0, TCSANOW, &modes));
    assert(write(1, "READY", 5) == 5);
    while (offset < total) {
        ssize_t count = read(0, bytes, sizeof(bytes));
        size_t i;
        if (count < 0 && errno == EINTR) continue;
        assert(count > 0);
        for (i = 0; i < (size_t)count; ++i, ++offset) {
            unsigned char expected;
            assert(offset < total);
            if (cancel) {
                memmove(tail, tail + 1, 6); tail[6] = bytes[i];
                if (bytes[i] == 3) {
                    assert(!memcmp(tail, "\033[201~\003", 7));
                    assert(offset < WT_PASTE_LIMIT);
                    assert(write(1, "COMPLETE", 8) == 8);
                    return 0;
                }
                continue;
            }
            if (offset < 6) expected = (unsigned char)"before"[offset];
            else if (offset < 12) expected = (unsigned char)"\033[200~"[offset - 6];
            else if (offset < 12 + WT_PASTE_LIMIT) expected = (unsigned char)('a' + (offset - 12) % 26);
            else expected = (unsigned char)"\033[201~"[offset - 12 - WT_PASTE_LIMIT];
            assert(bytes[i] == expected);
        }
        if (cancel && !requested) {
            assert(write(1, "CANCEL_NOW", 10) == 10);
            requested = 1;
        }
        usleep(1000); /* Force queue backpressure and partial PTY writes. */
    }
    assert(write(1, "COMPLETE", 8) == 8);
    return 0;
}
static void capture(void *context, const void *bytes, size_t length)
{
    Capture *c = context;
    assert(c->used + length < sizeof(c->output));
    memcpy(c->output + c->used, bytes, length);
    c->used += length; c->output[c->used] = 0;
    if (!c->sent && strstr(c->output, "READY")) {
        assert(!wt_session_send(c->session, "before", 6));
        assert(!wt_session_paste(c->session, c->paste, WT_PASTE_LIMIT + 12));
        assert(wt_session_paste(c->session, "x", 1) == -1);
        assert(wt_session_send(c->session, "MUST NOT INTERLEAVE", 19) == -1);
        c->sent = 1;
    }
    if (c->cancel && !c->cancelled && strstr(c->output, "CANCEL_NOW")) {
        assert(!wt_session_send(c->session, "\003", 1));
        c->cancelled = 1;
    }
}
int main(int argc, char **argv)
{
    WTSession session;
    Capture c = {0};
    char path[PATH_MAX];
    char *args[] = {path, "--receiver", NULL};
    size_t i;
    if (argc > 1) return receiver(!strcmp(argv[1], "--cancel"));
    alarm(20);
    assert(realpath(argv[0], path));
    c.paste = malloc(WT_PASTE_LIMIT + 12);
    assert(c.paste);
    memcpy(c.paste, "\033[200~", 6);
    for (i = 0; i < WT_PASTE_LIMIT; ++i) c.paste[6 + i] = (char)('a' + i % 26);
    memcpy(c.paste + 6 + WT_PASTE_LIMIT, "\033[201~", 6);
    assert(!wt_session_open(&session, path, args, 80, 24));
    c.session = &session;
    assert(wt_session_paste(&session, "x", WT_PASTE_LIMIT + 13) == -1);
    wt_session_run(&session, capture, &c);
    assert(strstr(c.output, "COMPLETE"));
    assert(WIFEXITED(session.status) && !WEXITSTATUS(session.status));
    assert(!session.paste);
    wt_session_close(&session);
    c.used = 0; c.output[0] = 0; c.sent = 0; c.cancel = 1;
    args[1] = "--cancel";
    assert(!wt_session_open(&session, path, args, 80, 24));
    wt_session_run(&session, capture, &c);
    assert(c.cancelled && strstr(c.output, "COMPLETE"));
    assert(WIFEXITED(session.status) && !WEXITSTATUS(session.status));
    assert(!session.paste);
    wt_session_close(&session);
    free(c.paste);
    alarm(0);
    puts("paste: full 1 MiB through PTY, backpressure, ordering, complete brackets, no interleaving, Ctrl-C cancellation passed");
    return 0;
}
