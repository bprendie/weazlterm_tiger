#ifndef WEAZL_SESSION_H
#define WEAZL_SESSION_H

#include "clipboard.h"
#include <pthread.h>
#include <stddef.h>
#include <sys/types.h>

#define WT_INPUT_CAPACITY 65536
typedef void (*WTOutput)(void *context, const void *data, size_t length);
typedef struct {
    int fd, wake[2], stopping, exited, status, io_error;
    pid_t pid;
    pthread_mutex_t lock;
    unsigned char input[WT_INPUT_CAPACITY];
    size_t input_length;
    unsigned char *paste;
    size_t paste_length, paste_offset;
} WTSession;

int wt_session_open(WTSession *s, const char *path, char *const argv[],
                    int cols, int rows);
int wt_session_send(WTSession *s, const void *data, size_t length);
/* Atomically admit a whole paste; the I/O worker streams it without interleaving. */
int wt_session_paste(WTSession *s, const void *data, size_t length);
int wt_session_resize(WTSession *s, int cols, int rows);
void wt_session_stop(WTSession *s);
/* Runs on a worker. Output callback must provide bounded backpressure. */
void wt_session_run(WTSession *s, WTOutput output, void *context);
/* Call only after the worker returns. */
void wt_session_close(WTSession *s);

#endif
