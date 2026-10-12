#include "terminal.h"
#include <string.h>

static int clamp(int value, int low, int high)
{
    return value < low ? low : value > high ? high : value;
}

static void modes(WTTerminal *t, int enabled)
{
    int i;
    for (i = 0; i < t->param_count; ++i) {
        switch (t->params[i]) {
        case 1: t->application_cursor = enabled; break;
        case 7: t->wrap = enabled; t->wrap_pending = 0; break;
        case 25: t->cursor_visible = enabled; break;
        case 1049: wt_alternate(t, enabled); break;
        case 2004: t->bracketed_paste = enabled; break;
        }
    }
}

void wt_csi(WTTerminal *t, unsigned char final)
{
    int p = t->params[0], n = p ? p : 1;
    int pos = t->y * t->cols + t->x;
    int end = (t->y + 1) * t->cols;
    if (t->private_mode) {
        if (final == 'h' || final == 'l') modes(t, final == 'h');
        t->dirty = 1;
        return;
    }
    switch (final) {
    case 'A': t->y -= n; break;
    case 'B': t->y += n; break;
    case 'C': t->x += n; break;
    case 'D': t->x -= n; break;
    case 'E': t->y += n; t->x = 0; break;
    case 'F': t->y -= n; t->x = 0; break;
    case 'G': t->x = n - 1; break;
    case 'd': t->y = n - 1; break;
    case 'H': case 'f':
        t->y = n - 1;
        t->x = (t->param_count > 1 && t->params[1] ? t->params[1] : 1) - 1;
        break;
    case 'J':
        if (p == 0) wt_clear(t, pos, t->rows * t->cols);
        else if (p == 1) wt_clear(t, 0, pos + 1);
        else if (p == 2) wt_clear(t, 0, t->rows * t->cols);
        break;
    case 'K':
        if (p == 0) wt_clear(t, pos, end);
        else if (p == 1) wt_clear(t, t->y * t->cols, pos + 1);
        else if (p == 2) wt_clear(t, t->y * t->cols, end);
        break;
    case 'X': wt_clear(t, pos, pos + clamp(n, 1, end - pos)); break;
    case 'P':
        n = clamp(n, 1, t->cols - t->x);
        memmove(t->cells + pos, t->cells + pos + n,
                (size_t)(end - pos - n) * sizeof(WTCell));
        wt_clear(t, end - n, end); break;
    case '@':
        n = clamp(n, 1, t->cols - t->x);
        memmove(t->cells + pos + n, t->cells + pos,
                (size_t)(end - pos - n) * sizeof(WTCell));
        wt_clear(t, pos, pos + n); break;
    case 'L': case 'M':
        if (t->y >= t->top && t->y <= t->bottom)
            wt_scroll(t, t->y, t->bottom, final == 'L' ? -n : n);
        break;
    case 'S': wt_scroll(t, t->top, t->bottom, n); break;
    case 'T': wt_scroll(t, t->top, t->bottom, -n); break;
    case 'r': {
        int top = n - 1;
        int bottom = t->param_count > 1 && t->params[1] ?
            t->params[1] - 1 : t->rows - 1;
        if (top >= 0 && top < bottom && bottom < t->rows) {
            t->top = top; t->bottom = bottom; t->x = t->y = 0;
        }
        break;
    }
    case 's': t->saved_x = t->x; t->saved_y = t->y; break;
    case 'u': t->x = t->saved_x; t->y = t->saved_y; break;
    case 'm': wt_sgr(t); t->dirty = 1; return;
    default: return;
    }
    t->x = clamp(t->x, 0, t->cols - 1);
    t->y = clamp(t->y, 0, t->rows - 1);
    t->wrap_pending = 0;
    t->dirty = 1;
}
