#import "WeazlView.h"

@interface WeazlWindow : NSObject {
    NSWindow *window;
    NSTabView *tabs;
    unsigned nextNumber;
}
- (NSWindow *)window;
- (BOOL)addProgram:(NSString *)program arguments:(NSArray *)arguments;
- (void)closeTab;
- (void)selectTabOffset:(int)offset;
- (void)stopSessions;
@end
