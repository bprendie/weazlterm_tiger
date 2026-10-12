#import "WeazlWindow.h"

@implementation WeazlWindow
- (id)init
{
    self = [super init];
    if (self) {
        window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 720, 460)
            styleMask:NSTitledWindowMask | NSClosableWindowMask |
                NSMiniaturizableWindowMask | NSResizableWindowMask
            backing:NSBackingStoreBuffered defer:NO];
        [window setReleasedWhenClosed:NO];
        [window setTitle:@"Weazlterm"];
        [window setMinSize:NSMakeSize(300, 180)];
        [window setDelegate:self];
        tabs = [[NSTabView alloc] initWithFrame:[[window contentView] bounds]];
        [tabs setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [tabs setAllowsTruncatedLabels:YES];
        [tabs setDelegate:self];
        [window setContentView:tabs];
        [window center];
        nextNumber = 1;
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(sessionEnded:) name:@"WeazlSessionEnded" object:nil];
    }
    return self;
}
- (NSWindow *)window { return window; }
- (BOOL)addProgram:(NSString *)program arguments:(NSArray *)arguments
{
    WeazlView *view = [[WeazlView alloc] initWithFrame:[tabs contentRect]];
    NSTabViewItem *item;
    if (!view) return NO;
    item = [[NSTabViewItem alloc] initWithIdentifier:
        [NSNumber numberWithUnsignedInt:nextNumber++]];
    [item setLabel:[NSString stringWithFormat:@"Terminal %@", [item identifier]]];
    [view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [item setView:view];
    [item setInitialFirstResponder:view];
    [tabs addTabViewItem:item];
    [tabs selectTabViewItem:item];
    [view setFrameSize:[tabs contentRect].size];
    if (![view startProgram:program arguments:arguments]) {
        [tabs removeTabViewItem:item];
        [item release];
        [view release];
        return NO;
    }
    [window makeKeyAndOrderFront:nil];
    [window makeFirstResponder:view];
    [item release];
    [view release];
    return YES;
}
- (void)tabView:(NSTabView *)sender didSelectTabViewItem:(NSTabViewItem *)item
{
    WeazlView *view = (WeazlView *)[item view];
    (void)sender;
    [view setFrameSize:[tabs contentRect].size];
    [window makeFirstResponder:view];
    [window setTitle:[view sessionTitle] ? [view sessionTitle] : @"Weazlterm"];
    [view setNeedsDisplay:YES];
}
- (void)sessionEnded:(NSNotification *)notification
{
    unsigned i;
    for (i = 0; i < (unsigned)[tabs numberOfTabViewItems]; ++i) {
        NSTabViewItem *item = [tabs tabViewItemAtIndex:i];
        if ([item view] != [notification object]) continue;
        [item setLabel:[NSString stringWithFormat:@"Terminal %@ (ended)", [item identifier]]];
        if (item == [tabs selectedTabViewItem])
            [window setTitle:[(WeazlView *)[item view] sessionTitle]];
        break;
    }
}
- (void)selectTabOffset:(int)offset
{
    int count = [tabs numberOfTabViewItems];
    int index = [tabs indexOfTabViewItem:[tabs selectedTabViewItem]];
    if (count) [tabs selectTabViewItemAtIndex:(index + offset + count) % count];
}
- (void)closeTab
{
    NSTabViewItem *item = [tabs selectedTabViewItem];
    if ([tabs numberOfTabViewItems] <= 1) { [window performClose:nil]; return; }
    [(WeazlView *)[item view] stopSession];
    [tabs removeTabViewItem:item];
    [window makeFirstResponder:[[tabs selectedTabViewItem] view]];
}
- (void)stopSessions
{
    unsigned i;
    for (i = 0; i < (unsigned)[tabs numberOfTabViewItems]; ++i)
        [(WeazlView *)[[tabs tabViewItemAtIndex:i] view] stopSession];
}
- (void)windowWillClose:(NSNotification *)notification
{
    (void)notification;
    /* The application removes its owning reference during this notification. */
    [[self retain] autorelease];
    [self stopSessions];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WeazlWindowClosed" object:self];
}
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [window setDelegate:nil];
    [tabs setDelegate:nil];
    [tabs release];
    [window release];
    [super dealloc];
}
@end
