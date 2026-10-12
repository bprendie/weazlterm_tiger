#define _DEFAULT_SOURCE
#include "session.h"
#include <errno.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/wait.h>
#include <unistd.h>

void wt_session_run(WTSession *s, WTOutput output, void *context)
{
    unsigned char buffer[16384];
    int maxfd = s->fd > s->wake[0] ? s->fd : s->wake[0];
    for (;;) {
        fd_set reads, writes;
        int stopping, pending, result;
        ssize_t count;
        pthread_mutex_lock(&s->lock);
        stopping = s->stopping;
        pending = s->input_length > 0 || s->paste != NULL;
        pthread_mutex_unlock(&s->lock);
        if (stopping) break;
        FD_ZERO(&reads);
        FD_ZERO(&writes);
        FD_SET(s->fd, &reads);
        FD_SET(s->wake[0], &reads);
        if (pending) FD_SET(s->fd, &writes);
        result = select(maxfd + 1, &reads, &writes, NULL, NULL);
        if (result < 0) {
            if (errno == EINTR) continue;
            s->io_error = errno;
            break;
        }
        if (FD_ISSET(s->wake[0], &reads)) {
            while (read(s->wake[0], buffer, sizeof(buffer)) > 0) {}
        }
        if (FD_ISSET(s->fd, &reads)) {
            count = read(s->fd, buffer, sizeof(buffer));
            if (count > 0) output(context, buffer, (size_t)count);
            else if (!count || (count < 0 && errno == EIO)) break;
            else if (errno != EINTR && errno != EAGAIN) { s->io_error = errno; break; }
        }
        if (FD_ISSET(s->fd, &writes)) {
            pthread_mutex_lock(&s->lock);
            if (s->input_length) {
                count = write(s->fd, s->input, s->input_length);
                if (count > 0) {
                    s->input_length -= (size_t)count;
                    memmove(s->input, s->input + count, s->input_length);
                }
            } else if (s->paste) {
                size_t length = s->paste_length - s->paste_offset;
                if (length > sizeof(buffer)) length = sizeof(buffer);
                count = write(s->fd, s->paste + s->paste_offset, length);
                if (count > 0) {
                    s->paste_offset += (size_t)count;
                    if (s->paste_offset == s->paste_length) {
                        free(s->paste);
                        s->paste = NULL;
                    }
                }
            } else count = 0;
            pthread_mutex_unlock(&s->lock);
            if (count < 0 && errno != EINTR && errno != EAGAIN) {
                s->io_error = errno;
                break;
            }
        }
    }
    /* PTY EOF normally follows child exit. Shutdown must not hang on a child
       that ignores HUP or closes its terminal but keeps running. */
    pthread_mutex_lock(&s->lock);
    if (waitpid(s->pid, &s->status, WNOHANG) == 0) {
        kill(-s->pid, SIGHUP);
        kill(s->pid, SIGKILL);
        while (waitpid(s->pid, &s->status, 0) < 0 && errno == EINTR) {}
    }
    free(s->paste);
    s->paste = NULL;
    s->exited = 1;
    pthread_mutex_unlock(&s->lock);
}
