#define _DEFAULT_SOURCE
#include "session.h"
#include <assert.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

typedef struct {
    WTSession session;
    pthread_mutex_t lock;
    pthread_cond_t ready;
    char output[4096];
    size_t used;
    int waiting;
} Fixture;

static void capture(void *context, const void *data, size_t length)
{
    Fixture *f = context;
    pthread_mutex_lock(&f->lock);
    assert(length < sizeof(f->output) - f->used);
    memcpy(f->output + f->used, data, length);
    f->used += length;
    f->output[f->used] = 0;
    if (strstr(f->output, "READY")) {
        f->waiting = 1;
        pthread_cond_signal(&f->ready);
    }
    pthread_mutex_unlock(&f->lock);
}
static void *run(void *context)
{
    Fixture *f = context;
    wt_session_run(&f->session, capture, f);
    return NULL;
}
static void init(Fixture *f)
{
    memset(f, 0, sizeof(*f));
    assert(!pthread_mutex_init(&f->lock, NULL));
    assert(!pthread_cond_init(&f->ready, NULL));
}
static void wait_ready(Fixture *f)
{
    pthread_mutex_lock(&f->lock);
    while (!f->waiting) pthread_cond_wait(&f->ready, &f->lock);
    pthread_mutex_unlock(&f->lock);
}
static void destroy(Fixture *f)
{
    wt_session_close(&f->session);
    pthread_cond_destroy(&f->ready);
    pthread_mutex_destroy(&f->lock);
}
int main(void)
{
    Fixture first, second;
    pthread_t a, b;
    char *first_args[] = { "/bin/sh", "-c", "printf FIRST_READY; exec sleep 100", NULL };
    char *second_args[] = { "/bin/sh", "-c",
        "stty -echo; printf SECOND_READY; IFS= read -r line; printf '\nGOT:%s\n' \"$line\"; stty size", NULL };
    alarm(10);
    init(&first); init(&second);
    assert(!wt_session_open(&first.session, first_args[0], first_args, 80, 24));
    assert(!pthread_create(&a, NULL, run, &first));
    wait_ready(&first);
    /* Open another terminal while the first terminal's worker is active. */
    assert(!wt_session_open(&second.session, second_args[0], second_args, 90, 30));
    assert(first.session.pid != second.session.pid);
    assert(!pthread_create(&b, NULL, run, &second));
    wait_ready(&second);
    assert(!wt_session_resize(&second.session, 110, 35));
    wt_session_stop(&first.session);
    assert(!pthread_join(a, NULL));
    assert(first.session.exited);
    destroy(&first);
    /* Closing one terminal must leave the other shell and its input alive. */
    assert(!wt_session_send(&second.session, "second only\n", 12));
    assert(!pthread_join(b, NULL));
    assert(strstr(second.output, "GOT:second only"));
    assert(strstr(second.output, "35 110"));
    assert(!strstr(first.output, "SECOND"));
    assert(!strstr(second.output, "FIRST"));
    assert(second.session.exited && !second.session.io_error);
    assert(WIFEXITED(second.session.status) && !WEXITSTATUS(second.session.status));
    destroy(&second);
    alarm(0);
    puts("sessions: concurrent PTYs, independent output/resize, close isolation passed");
    return 0;
}
