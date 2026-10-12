#import "WeazlApp.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

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
