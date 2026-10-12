#import "WeazlView.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

static int wordClass(uint32_t c)
{
    if (c == ' ' || c == '\t') return 0;
    if (c < 128 && strchr("()[]{}<>,;\"'`|=", (int)c)) return 1;
    return 2;
}

@implementation WeazlView (Selection)
- (uint64_t)oldestRow
{
    return terminal.alternate ? 0 : terminal.history_total - terminal.history_count;
}
- (uint64_t)visibleRow
{
    return terminal.alternate ? 0 : terminal.history_total - scrollOffset;
}
- (BOOL)hasSelection { return selectionAnchor != selectionEnd; }
- (void)clearSelection
{
    selectionAnchor = selectionEnd = 0;
    selecting = NO;
    [self setNeedsDisplay:YES];
}
- (const WTCell *)visibleCellAtColumn:(int)x row:(int)y
{
    int row = (terminal.alternate ? 0 : terminal.history_count - scrollOffset) + y;
    static const WTCell empty = { ' ', WT_DEFAULT_FG, WT_DEFAULT_BG, 0 };
    if (x >= wt_text_columns(&terminal, row)) return &empty;
    return wt_text_line(&terminal, row) + x;
}
- (BOOL)isSelectedColumn:(int)x row:(int)y
{
    uint64_t low = selectionAnchor < selectionEnd ? selectionAnchor : selectionEnd;
    uint64_t high = selectionAnchor > selectionEnd ? selectionAnchor : selectionEnd;
    uint64_t cell = ([self visibleRow] + y) * terminal.cols + x;
    return cell >= low && cell < high;
}
- (uint64_t)positionForEvent:(NSEvent *)event
{
    NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
    int x = (int)floor((p.x - 8) / cellWidth + 0.5);
    int y = (int)floor((p.y - 8) / cellHeight);
    if (x < 0) x = 0;
    if (x > terminal.cols) x = terminal.cols;
    if (y < 0) y = 0;
    if (y >= terminal.rows) y = terminal.rows - 1;
    return ([self visibleRow] + y) * terminal.cols + x;
}
- (void)mouseDown:(NSEvent *)event
{
    uint64_t position;
    [[self window] makeFirstResponder:self];
    if ([event modifierFlags] & NSControlKeyMask) { [self rightMouseDown:event]; return; }
    position = [self positionForEvent:event];
    if (!([event modifierFlags] & NSShiftKeyMask) || ![self hasSelection])
        selectionAnchor = position;
    selectionEnd = position;
    selecting = YES;
    if ([event clickCount] >= 2) {
        NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
        int y = (int)floor((p.y - 8) / cellHeight);
        int x = (int)floor((p.x - 8) / cellWidth), left, right;
        uint64_t row;
        const WTCell *line;
        if (y < 0) y = 0;
        if (y >= terminal.rows) y = terminal.rows - 1;
        if (x < 0) x = 0;
        if (x >= terminal.cols) x = terminal.cols - 1;
        row = [self visibleRow] + y;
        left = x; right = x + 1;
        line = wt_text_line(&terminal, (int)(row - [self oldestRow]));
        if (x >= wt_text_columns(&terminal, (int)(row - [self oldestRow]))) {
            [self clearSelection]; return;
        }
        if ([event clickCount] >= 3) { left = 0; right = terminal.cols; }
        else {
            int kind = wordClass(line[x].codepoint);
            while (left > 0 && wordClass(line[left - 1].codepoint) == kind) --left;
            while (right < terminal.cols && right < wt_text_columns(&terminal,
                (int)(row - [self oldestRow])) && wordClass(line[right].codepoint) == kind) ++right;
        }
        selectionAnchor = row * terminal.cols + left;
        selectionEnd = row * terminal.cols + right;
    }
    [self setNeedsDisplay:YES];
}
- (void)mouseDragged:(NSEvent *)event
{
    NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
    if (!selecting) return;
    if (p.y < 8) [self scrollByLines:1];
    else if (p.y >= 8 + terminal.rows * cellHeight) [self scrollByLines:-1];
    selectionEnd = [self positionForEvent:event];
    [self setNeedsDisplay:YES];
}
- (void)mouseUp:(NSEvent *)event { (void)event; selecting = NO; }
- (void)scrollByLines:(int)lines
{
    int count = terminal.alternate ? 0 : terminal.history_count;
    scrollOffset += lines;
    if (scrollOffset < 0) scrollOffset = 0;
    if (scrollOffset > count) scrollOffset = count;
    [self setNeedsDisplay:YES];
}
- (void)scrollWheel:(NSEvent *)event
{
    float delta = [event deltaY];
    if (delta) [self scrollByLines:(int)(delta > 0 ? ceil(delta * 3) : floor(delta * 3))];
}
- (void)scrollToLive
{
    scrollOffset = 0;
    [self setNeedsDisplay:YES];
}
- (void)selectAll:(id)sender
{
    int row = wt_text_rows(&terminal) - 1, end = 0;
    (void)sender;
    for (; row >= 0; --row) {
        const WTCell *line = wt_text_line(&terminal, row);
        for (end = wt_text_columns(&terminal, row); end > 0 && line[end - 1].codepoint == ' '; --end) {}
        if (end) break;
    }
    if (end > terminal.cols) end = terminal.cols;
    selectionAnchor = [self oldestRow] * terminal.cols;
    selectionEnd = row < 0 ? selectionAnchor : ([self oldestRow] + row) * terminal.cols + end;
    [self setNeedsDisplay:YES];
}
- (void)copy:(id)sender
{
    uint64_t low = selectionAnchor < selectionEnd ? selectionAnchor : selectionEnd;
    uint64_t high = selectionAnchor > selectionEnd ? selectionAnchor : selectionEnd;
    uint64_t base = [self oldestRow] * terminal.cols;
    size_t length;
    char *bytes;
    NSString *text;
    NSPasteboard *board;
    int lastRow, lastCol;
    (void)sender;
    if (![self hasSelection] || low < base) return;
    low -= base; high -= base;
    /* A boundary after the final cell belongs to that row, not a new row. */
    lastRow = (int)((high - 1) / terminal.cols);
    lastCol = (int)((high - 1) % terminal.cols) + 1;
    bytes = wt_copy_text(&terminal, (int)(low / terminal.cols), (int)(low % terminal.cols),
                         lastRow, lastCol, &length);
    if (!bytes) { NSBeep(); return; }
    text = [[[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding] autorelease];
    free(bytes);
    if (!text) { NSBeep(); return; }
    board = [NSPasteboard generalPasteboard];
    [board declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [board setString:text forType:NSStringPboardType];
}
- (void)rightMouseDown:(NSEvent *)event
{
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@"Terminal"] autorelease];
    [[self window] makeFirstResponder:self];
    [menu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@""];
    [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}
@end
