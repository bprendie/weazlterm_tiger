#import "WeazlWindow.h"

@interface WeazlApp : NSObject {
    NSMutableArray *windows;
    NSString *initialProgram;
    NSArray *initialArguments;
}
- (id)initWithProgram:(NSString *)path arguments:(NSArray *)args;
@end
