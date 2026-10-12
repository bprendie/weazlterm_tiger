#define _DEFAULT_SOURCE
#include "session.h"
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/wait.h>
#include <unistd.h>
#ifdef __APPLE__
#include <util.h>
#include <crt_externs.h>
#define WT_ENVIRON (*_NSGetEnviron())
#else
#include <pty.h>
extern char **environ;
#define WT_ENVIRON environ
#endif

static int nonblocking(int fd)
{
    int flags = fcntl(fd, F_GETFL, 0);
    return flags == -1 ? -1 : fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

int wt_session_open(WTSession *s, const char *path, char *const argv[],
                    int cols, int rows)
{
    struct winsize size;
    int err;
    size_t env_count = 0, i, j;
    char **child_env = NULL;
    memset(s, 0, sizeof(*s));
    s->fd = s->wake[0] = s->wake[1] = -1;
    if (!path || path[0] != '/' || cols < 1 || cols > 512 || rows < 1 || rows > 256) {
        errno = EINVAL;
        return -1;
    }
    err = pthread_mutex_init(&s->lock, NULL);
    if (err) { errno = err; return -1; }
    while (WT_ENVIRON[env_count]) ++env_count;
    child_env = calloc(env_count + 3, sizeof(char *));
    if (!child_env) goto fail;
    for (i = j = 0; i < env_count; ++i) {
        if (strncmp(WT_ENVIRON[i], "TERM=", 5) && strncmp(WT_ENVIRON[i], "COLORTERM=", 10))
            child_env[j++] = WT_ENVIRON[i];
    }
    child_env[j++] = "TERM=xterm-256color";
    child_env[j] = "COLORTERM=truecolor";
    if (pipe(s->wake) < 0) goto fail;
    if (nonblocking(s->wake[0]) || nonblocking(s->wake[1])) goto fail;
    if (fcntl(s->wake[0], F_SETFD, FD_CLOEXEC) == -1 ||
        fcntl(s->wake[1], F_SETFD, FD_CLOEXEC) == -1) goto fail;
    memset(&size, 0, sizeof(size));
    size.ws_col = (unsigned short)cols;
    size.ws_row = (unsigned short)rows;
    s->pid = forkpty(&s->fd, NULL, NULL, &size);
    if (s->pid < 0) goto fail;
    if (!s->pid) {
        close(s->wake[0]);
        close(s->wake[1]);
        signal(SIGPIPE, (void (*)(int))SIG_DFL);
        signal(SIGHUP, (void (*)(int))SIG_DFL);
        signal(SIGINT, (void (*)(int))SIG_DFL);
        signal(SIGQUIT, (void (*)(int))SIG_DFL);
        signal(SIGTERM, (void (*)(int))SIG_DFL);
        signal(SIGCHLD, (void (*)(int))SIG_DFL);
        execve(path, argv, child_env);
        {
            static const char message[] = "weazlterm: unable to start session\r\n";
            ssize_t ignored = write(STDERR_FILENO, message, sizeof(message) - 1);
            (void)ignored;
        }
        _exit(127);
    }
    if (s->fd >= FD_SETSIZE || s->wake[0] >= FD_SETSIZE ||
        nonblocking(s->fd) || fcntl(s->fd, F_SETFD, FD_CLOEXEC) == -1) {
        kill(s->pid, SIGKILL);
        while (waitpid(s->pid, NULL, 0) < 0 && errno == EINTR) {}
        goto fail;
    }
    free(child_env);
    return 0;
fail:
    err = errno;
    free(child_env);
    if (s->fd >= 0) close(s->fd);
    if (s->wake[0] >= 0) close(s->wake[0]);
    if (s->wake[1] >= 0) close(s->wake[1]);
    pthread_mutex_destroy(&s->lock);
    errno = err;
    return -1;
}

static void wake(WTSession *s)
{
    ssize_t result;
    do { result = write(s->wake[1], "w", 1); } while (result < 0 && errno == EINTR);
    /* A full pipe already contains a wake event. */
}

int wt_session_send(WTSession *s, const void *data, size_t length)
{
    pthread_mutex_lock(&s->lock);
    /* Ctrl-C may cancel a queued paste. Finish any partially sent bracket
       before the interrupt; discard bytes that have not reached the PTY. */
    if (!s->stopping && !s->exited && s->paste && length == 1 &&
        ((const unsigned char *)data)[0] == 3) {
        size_t offset = s->paste_offset;
        s->input_length = 0;
        if (offset && s->paste_length >= 12 && !memcmp(s->paste, "\033[200~", 6)) {
            if (offset < 6) {
                memcpy(s->input, s->paste + offset, 6 - offset);
                s->input_length = 6 - offset;
            }
            if (offset > s->paste_length - 6) {
                size_t remaining = s->paste_length - offset;
                memcpy(s->input + s->input_length, s->paste + offset, remaining);
                s->input_length += remaining;
            } else {
                memcpy(s->input + s->input_length, "\033[201~", 6);
                s->input_length += 6;
            }
        }
        s->input[s->input_length++] = 3;
        free(s->paste);
        s->paste = NULL;
        wake(s);
        pthread_mutex_unlock(&s->lock);
        return 0;
    }
    if (s->stopping || s->exited || s->paste || length > WT_INPUT_CAPACITY - s->input_length) {
        pthread_mutex_unlock(&s->lock);
        errno = EAGAIN;
        return -1;
    }
    memcpy(s->input + s->input_length, data, length);
    s->input_length += length;
    wake(s);
    pthread_mutex_unlock(&s->lock);
    return 0;
}

int wt_session_paste(WTSession *s, const void *data, size_t length)
{
    unsigned char *copy;
    if (!length || length > WT_PASTE_LIMIT + 12) { errno = EINVAL; return -1; }
    copy = malloc(length);
    if (!copy) return -1;
    memcpy(copy, data, length);
    pthread_mutex_lock(&s->lock);
    if (s->stopping || s->exited || s->paste) {
        pthread_mutex_unlock(&s->lock);
        free(copy);
        errno = EAGAIN;
        return -1;
    }
    s->paste = copy;
    s->paste_length = length;
    s->paste_offset = 0;
    wake(s);
    pthread_mutex_unlock(&s->lock);
    return 0;
}

int wt_session_resize(WTSession *s, int cols, int rows)
{
    struct winsize size;
    if (cols < 1 || cols > 512 || rows < 1 || rows > 256) { errno = EINVAL; return -1; }
    memset(&size, 0, sizeof(size));
    size.ws_col = (unsigned short)cols;
    size.ws_row = (unsigned short)rows;
    return ioctl(s->fd, TIOCSWINSZ, &size);
}

void wt_session_stop(WTSession *s)
{
    pthread_mutex_lock(&s->lock);
    s->stopping = 1;
    if (!s->exited) {
        kill(-s->pid, SIGHUP);
        kill(s->pid, SIGHUP);
    }
    wake(s);
    pthread_mutex_unlock(&s->lock);
}

void wt_session_close(WTSession *s)
{
    free(s->paste);
    close(s->fd);
    close(s->wake[0]);
    close(s->wake[1]);
    pthread_mutex_destroy(&s->lock);
}
