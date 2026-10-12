#import "WeazlView.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

@interface WeazlApp : NSObject {
    NSWindow *window;
    WeazlView *terminalView;
    NSString *program;
    NSArray *arguments;
}
- (id)initWithProgram:(NSString *)path arguments:(NSArray *)args;
@end

@implementation WeazlApp
- (id)initWithProgram:(NSString *)path arguments:(NSArray *)args
{
    self = [super init];
    if (self) { program = [path copy]; arguments = [args copy]; }
    return self;
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSMenu *bar = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    NSMenu *app = [[[NSMenu alloc] initWithTitle:@"Weazlterm"] autorelease];
    NSMenu *edit = [[[NSMenu alloc] initWithTitle:@"Edit"] autorelease];
    NSMenuItem *item;
    (void)notification;
    item = [bar addItemWithTitle:@"Weazlterm" action:NULL keyEquivalent:@""];
    [bar setSubmenu:app forItem:item];
    [app addItemWithTitle:@"Quit Weazlterm" action:@selector(terminate:) keyEquivalent:@"q"];
    item = [bar addItemWithTitle:@"Edit" action:NULL keyEquivalent:@""];
    [bar setSubmenu:edit forItem:item];
    [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [NSApp setMainMenu:bar];
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 720, 440)
        styleMask:NSTitledWindowMask | NSClosableWindowMask |
            NSMiniaturizableWindowMask | NSResizableWindowMask
        backing:NSBackingStoreBuffered defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setTitle:@"Weazlterm"];
    [window setMinSize:NSMakeSize(300, 180)];
    terminalView = [[WeazlView alloc] initWithFrame:[[window contentView] bounds]];
    if (!terminalView) { [NSApp terminate:nil]; return; }
    [terminalView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [window setContentView:terminalView];
    [terminalView setFrameSize:[[window contentView] bounds].size];
    [window makeFirstResponder:terminalView];
    [window center];
    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    if (![terminalView startProgram:program arguments:arguments]) [NSApp terminate:nil];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    (void)sender;
    return YES;
}
- (void)applicationWillTerminate:(NSNotification *)notification
{
    (void)notification;
    [terminalView stopSession];
}
@end

int main(int argc, char **argv)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *helpers = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Helpers"];
    NSString *ssh = [helpers stringByAppendingPathComponent:@"ssh"];
    NSString *path = @"/bin/bash";
    NSMutableArray *args = [NSMutableArray array];
    WeazlApp *delegate;
    int i;
    const char *oldPath = getenv("PATH");
    NSString *searchPath = [NSString stringWithFormat:@"%@:%s", helpers,
        oldPath ? oldPath : "/usr/bin:/bin:/usr/sbin:/sbin"];
    setenv("PATH", [searchPath fileSystemRepresentation], 1);
    setenv("WEAZLTERM_RC", [[[[NSBundle mainBundle] resourcePath]
        stringByAppendingPathComponent:@"shell/weazlterm.bashrc"] fileSystemRepresentation], 1);
    [NSApplication sharedApplication];
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:ssh]) {
        NSRunAlertPanel(@"Weazlterm SSH is not bundled", @"Build and package the PowerPC SSH helpers first.",
            @"OK", nil, nil);
        [pool drain];
        return 1;
    }
    if (argc > 1 && !strcmp(argv[1], "--ssh")) {
        path = ssh;
        for (i = 2; i < argc; ++i) [args addObject:[NSString stringWithUTF8String:argv[i]]];
    } else {
        [args addObject:@"-l"];
        [args addObject:@"-c"];
        [args addObject:@"exec /bin/bash --noprofile --rcfile \"$WEAZLTERM_RC\" -i"];
        [args addObject:@"weazlterm"];
    }
    delegate = [[WeazlApp alloc] initWithProgram:path arguments:args];
    [NSApp setDelegate:delegate];
    [NSApp run];
    [delegate release];
    [pool drain];
    return 0;
}
