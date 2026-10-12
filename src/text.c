#include "terminal.h"
#include <stdlib.h>
#include <string.h>

void wt_history_push(WTTerminal *t, int rows)
{
    int y;
    for (y = 0; y < rows; ++y) {
        int slot = (t->history_start + t->history_count) % WT_HISTORY_LINES;
        WTCell *row = t->history[slot];
        if (t->history_cols[slot] != t->cols)
            row = realloc(row, (size_t)t->cols * sizeof(WTCell));
        if (!row) {
            int i;
            /* Drop history on allocation failure, keeping absolute row IDs
               consistent with the screen that will still scroll. */
            for (i = 0; i < WT_HISTORY_LINES; ++i) {
                free(t->history[i]); t->history[i] = NULL; t->history_cols[i] = 0;
            }
            t->history_count = t->history_start = 0;
            ++t->history_total;
            continue;
        }
        t->history[slot] = row;
        t->history_cols[slot] = (unsigned short)t->cols;
        memcpy(row, t->cells + y * t->cols, (size_t)t->cols * sizeof(WTCell));
        t->history_wrap[slot] = t->line_wrap[y];
        if (t->history_count < WT_HISTORY_LINES) ++t->history_count;
        else t->history_start = (t->history_start + 1) % WT_HISTORY_LINES;
        ++t->history_total;
    }
}
int wt_text_rows(const WTTerminal *t)
{
    return t->rows + (t->alternate ? 0 : t->history_count);
}
const WTCell *wt_text_line(const WTTerminal *t, int row)
{
    int history = t->alternate ? 0 : t->history_count;
    if (row < 0 || row >= wt_text_rows(t)) return NULL;
    if (row < history)
        return t->history[(t->history_start + row) % WT_HISTORY_LINES];
    return t->cells + (row - history) * t->cols;
}
int wt_text_columns(const WTTerminal *t, int row)
{
    if (row < 0 || row >= wt_text_rows(t)) return 0;
    if (!t->alternate && row < t->history_count)
        return t->history_cols[(t->history_start + row) % WT_HISTORY_LINES];
    return t->cols;
}
int wt_text_wrapped(const WTTerminal *t, int row)
{
    int history = t->alternate ? 0 : t->history_count;
    if (row < 0 || row >= wt_text_rows(t)) return 0;
    if (row < history) return t->history_wrap[(t->history_start + row) % WT_HISTORY_LINES];
    return t->line_wrap[row - history];
}
static size_t utf8(char *out, uint32_t c)
{
    if (c > 0x10ffff || (c >= 0xd800 && c <= 0xdfff)) c = 0xfffd;
    if (c < 0x80) { out[0] = (char)c; return 1; }
    if (c < 0x800) {
        out[0] = (char)(0xc0 | (c >> 6)); out[1] = (char)(0x80 | (c & 63)); return 2;
    }
    if (c < 0x10000) {
        out[0] = (char)(0xe0 | (c >> 12)); out[1] = (char)(0x80 | ((c >> 6) & 63));
        out[2] = (char)(0x80 | (c & 63)); return 3;
    }
    out[0] = (char)(0xf0 | (c >> 18)); out[1] = (char)(0x80 | ((c >> 12) & 63));
    out[2] = (char)(0x80 | ((c >> 6) & 63)); out[3] = (char)(0x80 | (c & 63)); return 4;
}
char *wt_copy_text(const WTTerminal *t, int first_row, int first_col,
                   int last_row, int last_col, size_t *length)
{
    char *text;
    size_t used = 0;
    int row;
    if (!length) return NULL;
    *length = 0;
    if (first_row < 0 || last_row >= wt_text_rows(t) || first_row > last_row ||
        first_col < 0 || first_col > t->cols || last_col < 0 || last_col > t->cols ||
        (first_row == last_row && first_col > last_col)) return NULL;
    text = malloc((size_t)(last_row - first_row + 1) * (WT_MAX_COLS * 4 + 1) + 1);
    if (!text) return NULL;
    for (row = first_row; row <= last_row; ++row) {
        const WTCell *cells = wt_text_line(t, row);
        int start = row == first_row ? first_col : 0;
        int columns = wt_text_columns(t, row);
        int end = row == last_row && last_col < t->cols ? last_col : columns;
        int wrapped = wt_text_wrapped(t, row);
        int x;
        if (start > columns) start = columns;
        if (end > columns) end = columns;
        if (!wrapped) while (end > start && cells[end - 1].codepoint == ' ') --end;
        for (x = start; x < end; ++x) used += utf8(text + used, cells[x].codepoint);
        if (row < last_row && !wrapped) text[used++] = '\n';
    }
    text[used] = 0;
    *length = used;
    return text;
}
