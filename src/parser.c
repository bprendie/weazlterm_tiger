#include "terminal.h"
#include <string.h>

enum { GROUND, ESCAPE, CSI, STRING, STRING_ESCAPE, CHARSET };

static void control(WTTerminal *t, unsigned char c)
{
    switch (c) {
    case '\r': t->x = 0; t->wrap_pending = 0; break;
    case '\n': case '\v': case '\f': wt_linefeed(t); break;
    case '\b': if (t->x) --t->x; t->wrap_pending = 0; break;
    case '\t': t->x = (t->x / 8 + 1) * 8;
        if (t->x >= t->cols) t->x = t->cols - 1;
        t->wrap_pending = 0; break;
    }
    t->dirty = 1;
}

static void utf8(WTTerminal *t, unsigned char c)
{
    if (t->utf_left) {
        if ((c & 0xc0) == 0x80) {
            t->utf_value = (t->utf_value << 6) | (c & 0x3f);
            if (--t->utf_left == 0) {
                uint32_t value = t->utf_value;
                if (value < t->utf_min || value > 0x10ffff ||
                    (value >= 0xd800 && value <= 0xdfff)) value = 0xfffd;
                wt_put(t, value);
            }
            return;
        }
        t->utf_left = 0;
        wt_put(t, 0xfffd);
    }
    if (c < 0x80) wt_put(t, c);
    else if (c >= 0xc2 && c <= 0xdf) {
        t->utf_value = c & 0x1f; t->utf_min = 0x80; t->utf_left = 1;
    } else if (c >= 0xe0 && c <= 0xef) {
        t->utf_value = c & 0x0f; t->utf_min = 0x800; t->utf_left = 2;
    } else if (c >= 0xf0 && c <= 0xf4) {
        t->utf_value = c & 7; t->utf_min = 0x10000; t->utf_left = 3;
    } else wt_put(t, 0xfffd);
}

static void escape(WTTerminal *t, unsigned char c)
{
    t->state = GROUND;
    switch (c) {
    case '[':
        t->state = CSI;
        memset(t->params, 0, sizeof(t->params));
        t->param_count = 1;
        t->private_mode = t->invalid_csi = 0;
        break;
    case ']': case 'P': case '^': case '_': case 'X':
        t->state = STRING; break;
    case '(': case ')': case '*': case '+': t->state = CHARSET; break;
    case '7': t->saved_x = t->x; t->saved_y = t->y; break;
    case '8': t->x = t->saved_x; t->y = t->saved_y;
        t->wrap_pending = 0; break;
    case 'D': wt_linefeed(t); break;
    case 'E': t->x = 0; wt_linefeed(t); break;
    case 'M':
        if (t->y == t->top) wt_scroll(t, t->top, t->bottom, -1);
        else if (t->y) --t->y;
        t->wrap_pending = 0;
        break;
    case 'c': wt_reset(t); break;
    }
    t->dirty = 1;
}

void wt_feed(WTTerminal *t, const void *bytes, size_t length)
{
    const unsigned char *data = bytes;
    size_t i;
    for (i = 0; i < length; ++i) {
        unsigned char c = data[i];
        if (c == 0x18 || c == 0x1a) {
            t->state = GROUND;
            t->utf_left = 0;
            continue;
        }
        if (t->state == STRING || t->state == STRING_ESCAPE) {
            if (c == 7 || (t->state == STRING_ESCAPE && c == '\\'))
                t->state = GROUND;
            else t->state = c == 27 ? STRING_ESCAPE : STRING;
            continue;
        }
        if (c == 27) {
            if (t->utf_left) wt_put(t, 0xfffd);
            t->utf_left = 0;
            t->state = ESCAPE;
            continue;
        }
        if (c < 32 || c == 127) {
            if (t->utf_left) wt_put(t, 0xfffd);
            t->utf_left = 0;
            control(t, c);
            continue;
        }
        switch (t->state) {
        case GROUND: utf8(t, c); break;
        case ESCAPE: escape(t, c); break;
        case CHARSET: t->state = GROUND; break;
        case CSI:
            if (c >= '0' && c <= '9') {
                int *p = &t->params[t->param_count - 1];
                if (*p <= 9999) *p = *p * 10 + c - '0';
                else t->invalid_csi = 1;
            } else if (c == ';') {
                if (t->param_count < WT_MAX_PARAMS) ++t->param_count;
                else t->invalid_csi = 1;
            } else if (c == '?' && t->param_count == 1 && !t->params[0]
                       && !t->private_mode) t->private_mode = 1;
            else if (c >= 0x40 && c <= 0x7e) {
                if (!t->invalid_csi) wt_csi(t, c);
                t->state = GROUND;
            } else t->invalid_csi = 1;
            break;
        }
    }
}
