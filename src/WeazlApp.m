#import "WeazlApp.h"

@implementation WeazlApp
- (id)initWithProgram:(NSString *)path arguments:(NSArray *)args
{
    self = [super init];
    if (self) {
        windows = [[NSMutableArray alloc] init];
        initialProgram = [path copy];
        initialArguments = [args copy];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(windowClosed:) name:@"WeazlWindowClosed" object:nil];
    }
    return self;
}
- (NSArray *)shellArguments
{
    return [NSArray arrayWithObjects:@"-l", @"-c",
        @"exec /bin/bash --noprofile --rcfile \"$WEAZLTERM_RC\" -i", @"weazlterm", nil];
}
- (WeazlWindow *)activeWindow
{
    unsigned i;
    for (i = 0; i < [windows count]; ++i) {
        WeazlWindow *candidate = [windows objectAtIndex:i];
        if ([candidate window] == [NSApp keyWindow]) return candidate;
    }
    return nil;
}
- (void)openProgram:(NSString *)path arguments:(NSArray *)args
{
    WeazlWindow *controller = [[WeazlWindow alloc] init];
    [windows addObject:controller];
    if (![controller addProgram:path arguments:args]) {
        [[controller window] close];
        [windows removeObjectIdenticalTo:controller];
    }
    [controller release];
}
- (void)newWindow:(id)sender
{
    (void)sender;
    [self openProgram:@"/bin/bash" arguments:[self shellArguments]];
}
- (void)newTab:(id)sender
{
    WeazlWindow *controller = [self activeWindow];
    if (!controller) { [self newWindow:sender]; return; }
    [controller addProgram:@"/bin/bash" arguments:[self shellArguments]];
}
- (void)closeTab:(id)sender { (void)sender; [[self activeWindow] closeTab]; }
- (void)closeWindow:(id)sender { [[[self activeWindow] window] performClose:sender]; }
- (void)nextTab:(id)sender { (void)sender; [[self activeWindow] selectTabOffset:1]; }
- (void)previousTab:(id)sender { (void)sender; [[self activeWindow] selectTabOffset:-1]; }
- (void)windowClosed:(NSNotification *)notification
{
    [windows removeObjectIdenticalTo:[notification object]];
}
- (void)addItem:(NSString *)title action:(SEL)action key:(NSString *)key
    modifiers:(unsigned)modifiers menu:(NSMenu *)menu
{
    NSMenuItem *item = [menu addItemWithTitle:title action:action keyEquivalent:key];
    [item setTarget:self];
    [item setKeyEquivalentModifierMask:modifiers];
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSMenu *bar = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    NSMenu *app = [[[NSMenu alloc] initWithTitle:@"Weazlterm"] autorelease];
    NSMenu *file = [[[NSMenu alloc] initWithTitle:@"Shell"] autorelease];
    NSMenu *edit = [[[NSMenu alloc] initWithTitle:@"Edit"] autorelease];
    NSMenu *navigation = [[[NSMenu alloc] initWithTitle:@"Window"] autorelease];
    NSMenuItem *item;
    unsigned cmd = NSCommandKeyMask, shifted = NSCommandKeyMask | NSShiftKeyMask;
    (void)notification;
    item = [bar addItemWithTitle:@"Weazlterm" action:NULL keyEquivalent:@""];
    [bar setSubmenu:app forItem:item];
    [app addItemWithTitle:@"Quit Weazlterm" action:@selector(terminate:) keyEquivalent:@"q"];
    item = [bar addItemWithTitle:@"Shell" action:NULL keyEquivalent:@""];
    [bar setSubmenu:file forItem:item];
    [self addItem:@"New Terminal" action:@selector(newWindow:) key:@"n" modifiers:cmd menu:file];
    [self addItem:@"New Tab" action:@selector(newTab:) key:@"t" modifiers:cmd menu:file];
    [file addItem:[NSMenuItem separatorItem]];
    [self addItem:@"Close Tab" action:@selector(closeTab:) key:@"w" modifiers:cmd menu:file];
    [self addItem:@"Close Window" action:@selector(closeWindow:) key:@"w" modifiers:shifted menu:file];
    item = [bar addItemWithTitle:@"Edit" action:NULL keyEquivalent:@""];
    [bar setSubmenu:edit forItem:item];
    [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    item = [bar addItemWithTitle:@"Window" action:NULL keyEquivalent:@""];
    [bar setSubmenu:navigation forItem:item];
    [navigation addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [self addItem:@"Previous Tab" action:@selector(previousTab:) key:@"[" modifiers:shifted menu:navigation];
    [self addItem:@"Next Tab" action:@selector(nextTab:) key:@"]" modifiers:shifted menu:navigation];
    [NSApp setWindowsMenu:navigation];
    [NSApp setMainMenu:bar];
    [self openProgram:initialProgram arguments:initialArguments];
    [NSApp activateIgnoringOtherApps:YES];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    (void)sender;
    return NO; /* Cmd-N remains available after closing the final terminal. */
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)visible
{
    (void)sender;
    if (!visible && ![windows count]) [self newWindow:nil];
    return YES;
}
- (void)applicationWillTerminate:(NSNotification *)notification
{
    unsigned i;
    (void)notification;
    for (i = 0; i < [windows count]; ++i) [[windows objectAtIndex:i] stopSessions];
}
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [windows release];
    [initialProgram release];
    [initialArguments release];
    [super dealloc];
}
@end
