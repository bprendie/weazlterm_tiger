#include "terminal.h"

static uint32_t indexed(int index)
{
    static const uint32_t palette[16] = {
        0x101419, 0xcc6666, 0xb5bd68, 0xf0c674,
        0x81a2be, 0xb294bb, 0x8abeb7, 0xc5c8c6,
        0x666666, 0xff8b8b, 0xd5ed88, 0xffe694,
        0xa1c2de, 0xd2b4db, 0xaadeD7, 0xffffff
    };
    static const int cube[6] = { 0, 95, 135, 175, 215, 255 };
    if (index < 16) return palette[index];
    if (index >= 232) {
        uint32_t v = (uint32_t)(8 + (index - 232) * 10);
        return (v << 16) | (v << 8) | v;
    }
    index -= 16;
    return ((uint32_t)cube[index / 36] << 16) |
           ((uint32_t)cube[index / 6 % 6] << 8) | (uint32_t)cube[index % 6];
}

void wt_sgr(WTTerminal *t)
{
    int i;
    for (i = 0; i < t->param_count; ++i) {
        int p = t->params[i];
        if (p == 0) {
            t->pen.fg = WT_DEFAULT_FG;
            t->pen.bg = WT_DEFAULT_BG;
            t->pen.flags = 0;
        } else if (p == 1) t->pen.flags |= WT_BOLD;
        else if (p == 4) t->pen.flags |= WT_UNDERLINE;
        else if (p == 7) t->pen.flags |= WT_INVERSE;
        else if (p == 22) t->pen.flags &= ~WT_BOLD;
        else if (p == 24) t->pen.flags &= ~WT_UNDERLINE;
        else if (p == 27) t->pen.flags &= ~WT_INVERSE;
        else if (p == 39) t->pen.fg = WT_DEFAULT_FG;
        else if (p == 49) t->pen.bg = WT_DEFAULT_BG;
        else if (p >= 30 && p <= 37) t->pen.fg = indexed(p - 30);
        else if (p >= 40 && p <= 47) t->pen.bg = indexed(p - 40);
        else if (p >= 90 && p <= 97) t->pen.fg = indexed(p - 90 + 8);
        else if (p >= 100 && p <= 107) t->pen.bg = indexed(p - 100 + 8);
        else if (p == 38 || p == 48) {
            uint32_t color;
            if (i + 2 < t->param_count && t->params[i + 1] == 5) {
                int value = t->params[i + 2];
                i += 2;
                if (value > 255) continue;
                color = indexed(value);
            } else if (i + 4 < t->param_count && t->params[i + 1] == 2) {
                int r = t->params[i + 2], g = t->params[i + 3], b = t->params[i + 4];
                i += 4;
                if (r > 255 || g > 255 || b > 255) continue;
                color = ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
            } else break;
            if (p == 38) t->pen.fg = color;
            else t->pen.bg = color;
        }
    }
}
