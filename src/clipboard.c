#include "clipboard.h"
#include <stdlib.h>
#include <string.h>

char *wt_prepare_paste(const void *bytes, size_t length, int bracketed,
                       size_t *output_length, int *multiline)
{
    const unsigned char *source = bytes;
    char *out;
    size_t i, used = 0;
    if (!output_length || !multiline) return NULL;
    *output_length = 0; *multiline = 0;
    if (length > WT_PASTE_LIMIT || (!source && length)) return NULL;
    out = malloc(length + 13);
    if (!out) return NULL;
    if (bracketed) { memcpy(out, "\033[200~", 6); used = 6; }
    for (i = 0; i < length; ++i) {
        unsigned char c = source[i];
        if (c == '\r' || c == '\n') {
            if (c == '\r' && i + 1 < length && source[i + 1] == '\n') ++i;
            out[used++] = '\r';
            *multiline = 1;
        } else if (c == '\t' || (c >= 32 && c != 127)) {
            /* Preserve UTF-8 and indentation; drop terminal C0/DEL controls,
               especially ESC, so pasted text cannot terminate its bracket. */
            out[used++] = (char)c;
        }
    }
    if (bracketed) { memcpy(out + used, "\033[201~", 6); used += 6; }
    out[used] = 0;
    *output_length = used;
    return out;
}
