#include "terminal.h"
#include "clipboard.h"
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

static void feed(WTTerminal *t, const char *text) { wt_feed(t, text, strlen(text)); }
static void check(WTTerminal *t, int r1, int c1, int r2, int c2, const char *expected)
{
    size_t length;
    char *text = wt_copy_text(t, r1, c1, r2, c2, &length);
    assert(text);
    assert(length == strlen(expected));
    assert(!memcmp(text, expected, length));
    free(text);
}
int main(void)
{
    WTTerminal t;
    char *paste, *large;
    size_t length;
    int multiline, i;
    assert(!wt_init(&t, 8, 3));
    feed(&t, "abcdefghij\r\n  code\r\nnext");
    assert(t.history_count == 1);
    check(&t, 0, 0, 3, 4, "abcdefghij\n  code\nnext");
    check(&t, 0, 3, 1, 2, "defghij");
    check(&t, 2, 0, 2, 6, "  code");
    wt_alternate(&t, 1);
    feed(&t, "ALT");
    assert(wt_text_rows(&t) == 3);
    check(&t, 0, 0, 0, 3, "ALT");
    wt_alternate(&t, 0);
    check(&t, 0, 0, 3, 4, "abcdefghij\n  code\nnext");
    assert(!wt_resize(&t, 8, 4));
    check(&t, 0, 0, 3, 4, "abcdefghij\n  code\nnext");
    assert(!wt_resize(&t, 10, 4));
    /* Historical rows retain their full text and wrap metadata after resize. */
    check(&t, 0, 0, 3, 4, "abcdefghij\n  code\nnext");
    assert(!wt_resize(&t, 4, 4));
    check(&t, 0, 0, 0, 4, "abcdefgh");
    assert(!wt_resize(&t, 10, 4));
    wt_reset(&t);
    feed(&t, "caf\xc3\xa9 \xf0\x9f\x98\x80");
    check(&t, 0, 0, 0, 6, "caf\xc3\xa9 \xf0\x9f\x98\x80");
    wt_reset(&t);
    for (i = 0; i < WT_HISTORY_LINES + 20; ++i) feed(&t, "x\r\n");
    assert(t.history_count == WT_HISTORY_LINES);
    assert(t.history_total > WT_HISTORY_LINES);
    check(&t, 0, 0, 0, 1, "x");
    assert(!wt_resize(&t, 6, 3));
    check(&t, 0, 0, 0, 1, "x");
    assert(!wt_copy_text(&t, -1, 0, 0, 0, &length));
    wt_destroy(&t);
    paste = wt_prepare_paste("a\r\nb\nc\rd\t\033[201~\003\177", sizeof("a\r\nb\nc\rd\t\033[201~\003\177") - 1, 1, &length, &multiline);
    assert(paste && multiline);
    assert(!strcmp(paste, "\033[200~a\rb\rc\rd\t[201~\033[201~"));
    free(paste);
    paste = wt_prepare_paste("caf\xc3\xa9", 5, 0, &length, &multiline);
    assert(paste && !multiline && length == 5 && !memcmp(paste, "caf\xc3\xa9", 5));
    free(paste);
    large = malloc(WT_PASTE_LIMIT + 1);
    assert(large); memset(large, 'a', WT_PASTE_LIMIT + 1);
    paste = wt_prepare_paste(large, WT_PASTE_LIMIT, 1, &length, &multiline);
    assert(paste && length == WT_PASTE_LIMIT + 12);
    assert(!memcmp(paste + length - 6, "\033[201~", 6));
    free(paste);
    assert(!wt_prepare_paste(large, WT_PASTE_LIMIT + 1, 1, &length, &multiline));
    free(large);
    puts("clipboard: history, wrap joins, indentation, UTF-8, resize, alternate screen, paste controls/limits passed");
    return 0;
}
