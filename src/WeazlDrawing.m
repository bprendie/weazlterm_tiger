#import "WeazlView.h"

static NSColor *rgb(uint32_t color)
{
    return [NSColor colorWithCalibratedRed:((color >> 16) & 255) / 255.0
        green:((color >> 8) & 255) / 255.0 blue:(color & 255) / 255.0 alpha:1];
}

static void appendScalar(NSMutableString *text, uint32_t scalar)
{
    unichar units[2];
    unsigned length = 1;
    if (scalar > 0xffff) {
        scalar -= 0x10000;
        units[0] = 0xd800 + (scalar >> 10);
        units[1] = 0xdc00 + (scalar & 0x3ff);
        length = 2;
    } else units[0] = (unichar)scalar;
    [text appendString:[NSString stringWithCharacters:units length:length]];
}

@implementation WeazlView (Drawing)
- (void)drawRect:(NSRect)dirty
{
    int y, x;
    [rgb(WT_DEFAULT_BG) set];
    NSRectFill(dirty);
    for (y = 0; y < terminal.rows; ++y) {
        NSRect rowRect = NSMakeRect(8, 8 + y * cellHeight,
            terminal.cols * cellWidth, cellHeight);
        if (!NSIntersectsRect(rowRect, dirty)) continue;
        for (x = 0; x < terminal.cols;) {
            const WTCell *cell = wt_cell(&terminal, x, y);
            int start = x;
            uint32_t fg = cell->fg, bg = cell->bg;
            NSMutableString *text = [NSMutableString string];
            NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
            NSRect run;
            if (cell->flags & WT_INVERSE) { fg = cell->bg; bg = cell->fg; }
            do {
                appendScalar(text, wt_cell(&terminal, x, y)->codepoint);
                ++x;
            } while (x < terminal.cols && wt_cell(&terminal, x, y)->fg == cell->fg &&
                wt_cell(&terminal, x, y)->bg == cell->bg &&
                wt_cell(&terminal, x, y)->flags == cell->flags);
            run = NSMakeRect(8 + start * cellWidth, 8 + y * cellHeight,
                (x - start) * cellWidth, cellHeight);
            [rgb(bg) set];
            NSRectFill(run);
            [attributes setObject:(cell->flags & WT_BOLD) ? boldFont : font
                forKey:NSFontAttributeName];
            [attributes setObject:rgb(fg) forKey:NSForegroundColorAttributeName];
            if (cell->flags & WT_UNDERLINE)
                [attributes setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle]
                    forKey:NSUnderlineStyleAttributeName];
            [NSGraphicsContext saveGraphicsState];
            NSRectClip(run);
            [text drawAtPoint:run.origin withAttributes:attributes];
            [NSGraphicsContext restoreGraphicsState];
        }
    }
    if (terminal.cursor_visible && !sessionFinished) {
        [rgb(0xf0c674) set];
        NSFrameRect(NSMakeRect(8 + terminal.x * cellWidth,
            8 + terminal.y * cellHeight, cellWidth, cellHeight));
    }
    terminal.dirty = 0;
}
@end
