#import "WeazlView.h"

@implementation WeazlView (Input)
- (void)keyDown:(NSEvent *)event
{
    NSString *characters = [event characters];
    NSString *text = characters;
    unichar key;
    const char *sequence = NULL;
    unsigned modifiers = [event modifierFlags];
    if (![characters length]) return;
    key = [characters characterAtIndex:0];
    switch (key) {
    case NSUpArrowFunctionKey: sequence = terminal.application_cursor ? "\033OA" : "\033[A"; break;
    case NSDownArrowFunctionKey: sequence = terminal.application_cursor ? "\033OB" : "\033[B"; break;
    case NSRightArrowFunctionKey: sequence = terminal.application_cursor ? "\033OC" : "\033[C"; break;
    case NSLeftArrowFunctionKey: sequence = terminal.application_cursor ? "\033OD" : "\033[D"; break;
    case NSHomeFunctionKey: sequence = "\033[H"; break;
    case NSEndFunctionKey: sequence = "\033[F"; break;
    case NSPageUpFunctionKey: sequence = "\033[5~"; break;
    case NSPageDownFunctionKey: sequence = "\033[6~"; break;
    case NSDeleteFunctionKey: sequence = "\033[3~"; break;
    case NSF1FunctionKey: sequence = "\033OP"; break;
    case NSF2FunctionKey: sequence = "\033OQ"; break;
    case NSF3FunctionKey: sequence = "\033OR"; break;
    case NSF4FunctionKey: sequence = "\033OS"; break;
    }
    if (sequence) text = [NSString stringWithUTF8String:sequence];
    else if (key >= 0xf700 && key <= 0xf8ff) return;
    if (modifiers & NSControlKeyMask) {
        NSString *plain = [event charactersIgnoringModifiers];
        unichar control;
        if (key >= 1 && key <= 31) control = key;
        else if ([plain length]) {
            control = [plain characterAtIndex:0];
            if (control >= 'a' && control <= 'z') control -= 'a' - 'A';
            if (control >= '@' && control <= '_') control &= 0x1f;
            else if (control == ' ') control = 0;
            else if (control == '?') control = 0x7f;
            else return;
        } else return;
        text = [NSString stringWithCharacters:&control length:1];
    } else if (modifiers & NSAlternateKeyMask) {
        text = [@"\033" stringByAppendingString:[event charactersIgnoringModifiers]];
    }
    [self sendData:[text dataUsingEncoding:NSUTF8StringEncoding]];
}
- (void)paste:(id)sender
{
    NSString *source = [[NSPasteboard generalPasteboard] stringForType:NSStringPboardType];
    NSMutableString *text;
    NSMutableData *data;
    (void)sender;
    if (!source) return;
    text = [[source mutableCopy] autorelease];
    [text replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:0 range:NSMakeRange(0, [text length])];
    [text replaceOccurrencesOfString:@"\n" withString:@"\r" options:0 range:NSMakeRange(0, [text length])];
    /* Escape can terminate bracketed paste; discard it from pasted text. */
    [text replaceOccurrencesOfString:@"\033" withString:@"" options:0 range:NSMakeRange(0, [text length])];
    data = [NSMutableData data];
    if (terminal.bracketed_paste) [data appendBytes:"\033[200~" length:6];
    [data appendData:[text dataUsingEncoding:NSUTF8StringEncoding]];
    if (terminal.bracketed_paste) [data appendBytes:"\033[201~" length:6];
    if ([data length] > WT_INPUT_CAPACITY) {
        NSRunAlertPanel(@"Paste is too large", @"Paste up to 64 KiB at a time.", @"OK", nil, nil);
        return;
    }
    [self sendData:data];
}
@end
