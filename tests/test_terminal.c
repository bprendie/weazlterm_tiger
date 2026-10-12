#include "terminal.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static void feed(WTTerminal *t, const char *text) { wt_feed(t, text, strlen(text)); }
static uint32_t at(WTTerminal *t, int x, int y) { return wt_cell(t, x, y)->codepoint; }

static void screen_tests(void)
{
    WTTerminal t;
    assert(wt_init(&t, 4, 3) == 0);
    feed(&t, "abcd");
    assert(t.x == 3 && t.y == 0 && t.wrap_pending);
    feed(&t, "e");
    assert(at(&t, 0, 1) == 'e' && t.x == 1);
    feed(&t, "\rZ\033[3;1H1234\r\n!");
    assert(at(&t, 0, 0) == 'Z' && at(&t, 0, 1) == '1' && at(&t, 0, 2) == '!');
    feed(&t, "\033[2J\033[Hhi\033[?1049hALT\033[?1049l");
    assert(at(&t, 0, 0) == 'h' && t.x == 2 && !t.alternate);
    assert(wt_resize(&t, 2, 2) == 0);
    assert(at(&t, 1, 0) == 'i' && t.x == 1);
    assert(wt_resize(&t, 0, 4) == -1 && t.cols == 2);
    feed(&t, "\033[99999;99999H");
    assert(t.x == 1 && t.y == 1);
    wt_destroy(&t);
}

static void editing_tests(void)
{
    WTTerminal t;
    assert(!wt_init(&t, 6, 4));
    feed(&t, "abcdef\033[1;2H\033[2P");
    assert(at(&t, 1, 0) == 'd' && at(&t, 4, 0) == ' ');
    feed(&t, "\033[2@XY");
    assert(at(&t, 0, 0) == 'a' && at(&t, 1, 0) == 'X' && at(&t, 3, 0) == 'd');
    feed(&t, "\033[2J\033[Htop\033[2;1Hone\033[3;1Htwo\033[4;1Hlast");
    feed(&t, "\033[2;3r\033[3;1H\n");
    assert(at(&t, 0, 0) == 't' && at(&t, 0, 1) == 't');
    assert(at(&t, 0, 2) == ' ' && at(&t, 0, 3) == 'l');
    feed(&t, "\033[?7l\033[1;6Hab");
    assert(at(&t, 5, 0) == 'b' && t.y == 0);
    wt_destroy(&t);
}

static void color_utf_tests(void)
{
    WTTerminal t;
    assert(!wt_init(&t, 30, 3));
    feed(&t, "\033[38;2;1;2;3;48;5;196;1mA");
    assert(wt_cell(&t, 0, 0)->fg == 0x010203);
    assert(wt_cell(&t, 0, 0)->bg == 0xff0000);
    assert(wt_cell(&t, 0, 0)->flags == WT_BOLD);
    feed(&t, "\033[0m\xc3");
    feed(&t, "\xa9\xf0\x9f");
    feed(&t, "\x98\x80\xed\xa0\x80\xe2X");
    assert(at(&t, 1, 0) == 0xe9 && at(&t, 2, 0) == 0x1f600);
    assert(at(&t, 3, 0) == 0xfffd && at(&t, 4, 0) == 0xfffd && at(&t, 5, 0) == 'X');
    feed(&t, "\033]52;c;clipboard payload\033\\B\033Pignored\033\\C");
    assert(at(&t, 6, 0) == 'B' && at(&t, 7, 0) == 'C');
    feed(&t, "\033[99999999999999999999999999999HZ");
    assert(at(&t, 8, 0) == 'Z');
    wt_destroy(&t);
}

static void fragmentation_tests(void)
{
    const char *stream = "abc\r\n\033[2;3H\033[38;5;123m\xe2\x98\x83"
        "\033]0;title\033\\\033[?1049hother\033[?1049l!";
    WTTerminal expected, actual;
    size_t split, length = strlen(stream);
    assert(!wt_init(&expected, 12, 4));
    feed(&expected, stream);
    for (split = 0; split <= length; ++split) {
        int i;
        assert(!wt_init(&actual, 12, 4));
        wt_feed(&actual, stream, split);
        wt_feed(&actual, stream + split, length - split);
        assert(actual.x == expected.x && actual.y == expected.y);
        for (i = 0; i < actual.cols * actual.rows; ++i) {
            assert(actual.cells[i].codepoint == expected.cells[i].codepoint);
            assert(actual.cells[i].fg == expected.cells[i].fg);
            assert(actual.cells[i].bg == expected.cells[i].bg);
            assert(actual.cells[i].flags == expected.cells[i].flags);
        }
        wt_destroy(&actual);
    }
    wt_destroy(&expected);
}

static void hostile_input_tests(void)
{
    WTTerminal t;
    uint32_t seed = 42;
    unsigned i;
    assert(!wt_init(&t, 80, 24));
    for (i = 0; i < 1000000; ++i) {
        unsigned char byte;
        seed = seed * 1664525u + 1013904223u;
        byte = (unsigned char)(seed >> 24);
        wt_feed(&t, &byte, 1);
        assert(t.x >= 0 && t.x < t.cols && t.y >= 0 && t.y < t.rows);
        assert(t.top >= 0 && t.top <= t.bottom && t.bottom < t.rows);
        if (i % 10000 == 0) assert(!wt_resize(&t, 1 + seed % 160, 1 + (seed >> 8) % 50));
    }
    wt_destroy(&t);
}

int main(void)
{
    screen_tests();
    editing_tests();
    color_utf_tests();
    fragmentation_tests();
    hostile_input_tests();
    puts("terminal: screen, editing, colors, UTF-8, stream fragmentation, hostile input passed");
    return 0;
}
