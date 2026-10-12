#ifndef WEAZL_CLIPBOARD_H
#define WEAZL_CLIPBOARD_H
#include <stddef.h>
#define WT_PASTE_LIMIT (1024u * 1024u)
/* Caller frees the returned UTF-8 bytes. No partial result on failure. */
char *wt_prepare_paste(const void *bytes, size_t length, int bracketed,
                       size_t *output_length, int *multiline);
#endif
