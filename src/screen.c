#include "terminal.h"
#include <stdlib.h>
#include <string.h>

static int dimensions(int cols, int rows)
{
    return cols > 0 && rows > 0 && cols <= WT_MAX_COLS && rows <= WT_MAX_ROWS;
}

static WTCell blank(WTTerminal *t)
{
    WTCell cell = t->pen;
    cell.codepoint = ' ';
    cell.flags = 0;
    return cell;
}

void wt_clear(WTTerminal *t, int first, int end)
{
    WTCell cell = blank(t);
    int i;
    for (i = first; i < end; ++i) {
        t->cells[i] = cell;
        if (i % t->cols == t->cols - 1) t->line_wrap[i / t->cols] = 0;
    }
    t->dirty = 1;
}

int wt_init(WTTerminal *t, int cols, int rows)
{
    memset(t, 0, sizeof(*t));
    if (!dimensions(cols, rows)) return -1;
    t->primary = calloc((size_t)cols * rows, sizeof(WTCell));
    t->secondary = calloc((size_t)cols * rows, sizeof(WTCell));
    t->primary_wrap = calloc((size_t)rows, 1);
    t->secondary_wrap = calloc((size_t)rows, 1);
    t->history = calloc(WT_HISTORY_LINES, sizeof(WTCell *));
    if (!t->primary || !t->secondary || !t->primary_wrap ||
        !t->secondary_wrap || !t->history) {
        wt_destroy(t);
        return -1;
    }
    t->cols = cols;
    t->rows = rows;
    wt_reset(t);
    return 0;
}

void wt_destroy(WTTerminal *t)
{
    int i;
    if (t->history) for (i = 0; i < WT_HISTORY_LINES; ++i) free(t->history[i]);
    free(t->primary);
    free(t->secondary);
    free(t->primary_wrap);
    free(t->secondary_wrap);
    free(t->history);
    memset(t, 0, sizeof(*t));
}

void wt_reset(WTTerminal *t)
{
    t->pen.codepoint = ' ';
    t->pen.fg = WT_DEFAULT_FG;
    t->pen.bg = WT_DEFAULT_BG;
    t->pen.flags = 0;
    t->x = t->y = t->saved_x = t->saved_y = 0;
    t->primary_x = t->primary_y = 0;
    t->top = 0;
    t->bottom = t->rows - 1;
    t->wrap = t->cursor_visible = 1;
    t->wrap_pending = t->alternate = t->application_cursor = 0;
    t->bracketed_paste = t->state = t->utf_left = 0;
    t->cells = t->secondary;
    t->line_wrap = t->secondary_wrap;
    wt_clear(t, 0, t->cols * t->rows);
    t->cells = t->primary;
    t->line_wrap = t->primary_wrap;
    t->history_start = t->history_count = 0;
    t->history_total = 0;
    wt_clear(t, 0, t->cols * t->rows);
}

int wt_resize(WTTerminal *t, int cols, int rows)
{
    WTTerminal next;
    int y, width, height;
    WTCell *primary, *secondary;
    if (!dimensions(cols, rows)) return -1;
    if (cols == t->cols && rows == t->rows) return 0;
    if (wt_init(&next, cols, rows)) return -1;
    width = cols < t->cols ? cols : t->cols;
    height = rows < t->rows ? rows : t->rows;
    for (y = 0; y < height; ++y) {
        memcpy(next.primary + y * cols, t->primary + y * t->cols,
               (size_t)width * sizeof(WTCell));
        memcpy(next.secondary + y * cols, t->secondary + y * t->cols,
               (size_t)width * sizeof(WTCell));
    }
    if (cols == t->cols) {
        memcpy(next.primary_wrap, t->primary_wrap, (size_t)height);
        memcpy(next.secondary_wrap, t->secondary_wrap, (size_t)height);
    }
    free(next.history); /* Historical rows keep their original width and text. */
    free(t->primary_wrap);
    free(t->secondary_wrap);
    t->primary_wrap = next.primary_wrap;
    t->secondary_wrap = next.secondary_wrap;
    t->line_wrap = t->alternate ? t->secondary_wrap : t->primary_wrap;
    primary = next.primary;
    secondary = next.secondary;
    free(t->primary);
    free(t->secondary);
    t->primary = primary;
    t->secondary = secondary;
    t->cells = t->alternate ? secondary : primary;
    t->cols = cols;
    t->rows = rows;
    if (t->x >= cols) t->x = cols - 1;
    if (t->y >= rows) t->y = rows - 1;
    if (t->saved_x >= cols) t->saved_x = cols - 1;
    if (t->saved_y >= rows) t->saved_y = rows - 1;
    if (t->primary_x >= cols) t->primary_x = cols - 1;
    if (t->primary_y >= rows) t->primary_y = rows - 1;
    t->top = 0;
    t->bottom = rows - 1;
    t->wrap_pending = 0;
    t->dirty = 1;
    return 0;
}

void wt_scroll(WTTerminal *t, int top, int bottom, int lines)
{
    int height = bottom - top + 1;
    int count = lines < 0 ? -lines : lines;
    size_t length;
    if (count > height) count = height;
    length = (size_t)(height - count) * t->cols * sizeof(WTCell);
    if (lines > 0) {
        if (!t->alternate && top == 0 && bottom == t->rows - 1)
            wt_history_push(t, count);
        memmove(t->line_wrap + top, t->line_wrap + top + count, (size_t)(height - count));
        memmove(t->cells + top * t->cols,
                t->cells + (top + count) * t->cols, length);
        wt_clear(t, (bottom + 1 - count) * t->cols, (bottom + 1) * t->cols);
    } else {
        memmove(t->line_wrap + top + count, t->line_wrap + top, (size_t)(height - count));
        memmove(t->cells + (top + count) * t->cols,
                t->cells + top * t->cols, length);
        wt_clear(t, top * t->cols, (top + count) * t->cols);
    }
    t->dirty = 1;
}

static void advance_line(WTTerminal *t)
{
    t->wrap_pending = 0;
    if (t->y == t->bottom) wt_scroll(t, t->top, t->bottom, 1);
    else if (t->y < t->rows - 1) ++t->y;
    t->dirty = 1;
}

void wt_linefeed(WTTerminal *t)
{
    t->line_wrap[t->y] = 0;
    advance_line(t);
}

void wt_put(WTTerminal *t, uint32_t codepoint)
{
    if (t->wrap_pending && t->wrap) {
        t->line_wrap[t->y] = 1;
        t->x = 0;
        advance_line(t);
    }
    t->pen.codepoint = codepoint;
    t->cells[t->y * t->cols + t->x] = t->pen;
    if (t->x < t->cols - 1) ++t->x;
    else t->wrap_pending = 1;
    t->dirty = 1;
}

void wt_alternate(WTTerminal *t, int enabled)
{
    if (!!enabled == t->alternate) return;
    if (enabled) {
        t->primary_x = t->x;
        t->primary_y = t->y;
        t->cells = t->secondary;
        t->line_wrap = t->secondary_wrap;
        wt_clear(t, 0, t->cols * t->rows);
        t->x = t->y = 0;
    } else {
        t->cells = t->primary;
        t->line_wrap = t->primary_wrap;
        t->x = t->primary_x;
        t->y = t->primary_y;
    }
    t->alternate = !!enabled;
    t->wrap_pending = 0;
    t->dirty = 1;
}

const WTCell *wt_cell(const WTTerminal *t, int x, int y)
{
    if (x < 0 || y < 0 || x >= t->cols || y >= t->rows) return NULL;
    return &t->cells[y * t->cols + x];
}
