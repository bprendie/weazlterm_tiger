#import "WeazlView.h"
#include "clipboard.h"
#include <stdlib.h>

@implementation WeazlView (Clipboard)
- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    if ([item action] == @selector(copy:)) return [self hasSelection];
    if ([item action] == @selector(paste:))
        return sessionStarted && !sessionFinished &&
            [[NSPasteboard generalPasteboard] availableTypeFromArray:
                [NSArray arrayWithObject:NSStringPboardType]] != nil;
    return YES;
}
- (void)paste:(id)sender
{
    NSString *source = [[NSPasteboard generalPasteboard] stringForType:NSStringPboardType];
    NSData *input;
    char *bytes;
    size_t length;
    int multiline, result;
    (void)sender;
    if (!source || ![source length] || !sessionStarted || sessionFinished) return;
    if ([source lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > WT_PASTE_LIMIT) {
        NSRunAlertPanel(@"Paste is too large", @"Paste up to 1 MiB of text at a time.", @"OK", nil, nil);
        return;
    }
    input = [source dataUsingEncoding:NSUTF8StringEncoding];
    if (!input) { NSBeep(); return; }
    bytes = wt_prepare_paste([input bytes], [input length], terminal.bracketed_paste,
                             &length, &multiline);
    if (!bytes) { NSBeep(); return; }
    if (multiline && !terminal.bracketed_paste &&
        NSRunAlertPanel(@"Paste multiple lines?",
            @"This session has not enabled bracketed paste. Newlines may run shell commands immediately.",
            @"Paste", @"Cancel", nil) != NSAlertDefaultReturn) {
        free(bytes);
        return;
    }
    result = length ? wt_session_paste(&session, bytes, length) : 0;
    free(bytes);
    if (result) {
        NSRunAlertPanel(@"Paste could not be queued", @"Wait for the current paste to finish, then try again.",
            @"OK", nil, nil);
        return;
    }
    [self clearSelection];
    [self scrollToLive];
}
@end
