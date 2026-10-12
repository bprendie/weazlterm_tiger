#import "WeazlView.h"
#include <errno.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>

static void deliver(void *context, const void *bytes, size_t length)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSData *data = [NSData dataWithBytes:bytes length:length];
    [(WeazlView *)context performSelectorOnMainThread:@selector(receiveOutput:)
        withObject:data waitUntilDone:YES];
    [pool drain];
}

@implementation WeazlView
- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        if (wt_init(&terminal, 80, 24)) { [self release]; return nil; }
        font = [[NSFont fontWithName:@"Monaco" size:13] retain];
        if (!font) font = [[NSFont userFixedPitchFontOfSize:13] retain];
        boldFont = [[[NSFontManager sharedFontManager] convertFont:font
            toHaveTrait:NSBoldFontMask] retain];
        cellWidth = [@"M" sizeWithAttributes:
            [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]].width;
        cellHeight = ceil([font ascender] - [font descender] + [font leading] + 2);
    }
    return self;
}
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }

- (BOOL)startProgram:(NSString *)path arguments:(NSArray *)arguments
{
    unsigned i, count = (unsigned)[arguments count];
    char **argv = calloc(count + 2, sizeof(char *));
    int result;
    if (!argv) return NO;
    argv[0] = (char *)[path fileSystemRepresentation];
    for (i = 0; i < count; ++i)
        argv[i + 1] = (char *)[[arguments objectAtIndex:i] UTF8String];
    result = wt_session_open(&session, argv[0], argv, terminal.cols, terminal.rows);
    free(argv);
    if (result) {
        NSRunAlertPanel(@"Session could not start", @"%s", @"OK", nil, nil, strerror(errno));
        return NO;
    }
    sessionStarted = YES;
    [NSThread detachNewThreadSelector:@selector(readSession:) toTarget:self withObject:nil];
    return YES;
}
- (void)readSession:(id)unused
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    (void)unused;
    wt_session_run(&session, deliver, self);
    [self performSelectorOnMainThread:@selector(sessionEnded:) withObject:nil waitUntilDone:YES];
    [pool drain];
}
- (void)receiveOutput:(NSData *)data
{
    uint64_t previousTotal = terminal.history_total;
    int previousAlternate = terminal.alternate;
    wt_feed(&terminal, [data bytes], [data length]);
    if (terminal.alternate != previousAlternate || terminal.history_total < previousTotal) {
        scrollOffset = 0;
        [self clearSelection];
    } else if (!terminal.alternate) {
        uint64_t oldest = (terminal.history_total - terminal.history_count) * terminal.cols;
        if (scrollOffset) {
            uint64_t offset = scrollOffset + terminal.history_total - previousTotal;
            scrollOffset = offset > (uint64_t)terminal.history_count ? terminal.history_count : (int)offset;
        }
        if ([self hasSelection] && (selectionAnchor < oldest || selectionEnd < oldest))
            [self clearSelection];
    }
    if (terminal.dirty) [self setNeedsDisplay:YES];
}
- (void)sessionEnded:(id)unused
{
    NSString *title;
    (void)unused;
    sessionFinished = YES;
    if (session.io_error)
        title = @"Weazlterm - session I/O error";
    else if (WIFEXITED(session.status))
        title = [NSString stringWithFormat:@"Weazlterm - session ended (%d)",
            WEXITSTATUS(session.status)];
    else if (WIFSIGNALED(session.status))
        title = [NSString stringWithFormat:@"Weazlterm - session stopped by signal %d",
            WTERMSIG(session.status)];
    else title = @"Weazlterm - session ended";
    sessionTitle = [title copy];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WeazlSessionEnded" object:self];
}
- (NSString *)sessionTitle { return sessionTitle; }
- (void)stopSession
{
    if (sessionStarted && !sessionFinished) wt_session_stop(&session);
}
- (void)sendData:(NSData *)data
{
    [self clearSelection];
    [self scrollToLive];
    if (!sessionStarted || sessionFinished ||
        wt_session_send(&session, [data bytes], [data length])) NSBeep();
}
- (void)setFrameSize:(NSSize)size
{
    int cols, rows;
    [super setFrameSize:size];
    if (!font) return;
    cols = (int)((size.width - 16) / cellWidth);
    rows = (int)((size.height - 16) / cellHeight);
    if (cols < 1) cols = 1;
    if (rows < 1) rows = 1;
    if (cols > WT_MAX_COLS) cols = WT_MAX_COLS;
    if (rows > WT_MAX_ROWS) rows = WT_MAX_ROWS;
    if (cols == terminal.cols && rows == terminal.rows) return;
    [self clearSelection];
    scrollOffset = 0;
    if (wt_resize(&terminal, cols, rows)) { NSBeep(); return; }
    if (sessionStarted && !sessionFinished && wt_session_resize(&session, cols, rows)) NSBeep();
    [self setNeedsDisplay:YES];
}
- (void)dealloc
{
    /* The worker retains its target until it returns. */
    if (sessionStarted) wt_session_close(&session);
    wt_destroy(&terminal);
    [font release];
    [boldFont release];
    [sessionTitle release];
    [super dealloc];
}
@end
