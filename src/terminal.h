#ifndef WEAZL_TERMINAL_H
#define WEAZL_TERMINAL_H

#include <stddef.h>
#include <stdint.h>

#define WT_DEFAULT_FG 0xd8dee9u
#define WT_DEFAULT_BG 0x101419u
#define WT_BOLD 1
#define WT_INVERSE 2
#define WT_UNDERLINE 4
#define WT_MAX_PARAMS 16
#define WT_MAX_COLS 512
#define WT_MAX_ROWS 256
#define WT_HISTORY_LINES 2000

typedef struct {
    uint32_t codepoint, fg, bg;
    unsigned char flags;
} WTCell;

typedef struct {
    int cols, rows, x, y, saved_x, saved_y;
    int top, bottom, wrap, wrap_pending, cursor_visible, application_cursor;
    int alternate, bracketed_paste, dirty;
    WTCell *cells, *primary, *secondary;
    unsigned char *primary_wrap, *secondary_wrap, *line_wrap;
    WTCell **history;
    unsigned short history_cols[WT_HISTORY_LINES];
    unsigned char history_wrap[WT_HISTORY_LINES];
    int history_start, history_count;
    uint64_t history_total;
    WTCell pen;
    int primary_x, primary_y;
    unsigned char state, private_mode, invalid_csi;
    int params[WT_MAX_PARAMS], param_count;
    uint32_t utf_value, utf_min;
    int utf_left;
} WTTerminal;

int wt_init(WTTerminal *t, int cols, int rows);
void wt_destroy(WTTerminal *t);
void wt_reset(WTTerminal *t);
int wt_resize(WTTerminal *t, int cols, int rows);
void wt_feed(WTTerminal *t, const void *bytes, size_t length);
const WTCell *wt_cell(const WTTerminal *t, int x, int y);

/* Row zero is the oldest retained history row (or alternate-screen row zero). */
int wt_text_rows(const WTTerminal *t);
const WTCell *wt_text_line(const WTTerminal *t, int row);
int wt_text_columns(const WTTerminal *t, int row);
int wt_text_wrapped(const WTTerminal *t, int row);
char *wt_copy_text(const WTTerminal *t, int first_row, int first_col,
                   int last_row, int last_col, size_t *length);
void wt_history_push(WTTerminal *t, int rows);

/* Internal operations shared by the parser and screen modules. */
void wt_clear(WTTerminal *t, int first, int end);
void wt_scroll(WTTerminal *t, int top, int bottom, int lines);
void wt_linefeed(WTTerminal *t);
void wt_put(WTTerminal *t, uint32_t codepoint);
void wt_csi(WTTerminal *t, unsigned char final);
void wt_sgr(WTTerminal *t);
void wt_alternate(WTTerminal *t, int enabled);

#endif
