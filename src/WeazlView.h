#import <Cocoa/Cocoa.h>
#include "terminal.h"
#include "session.h"

@interface WeazlView : NSView {
    WTTerminal terminal;
    WTSession session;
    NSFont *font;
    NSFont *boldFont;
    float cellWidth, cellHeight;
    NSString *sessionTitle;
    BOOL sessionStarted, sessionFinished;
}
- (BOOL)startProgram:(NSString *)path arguments:(NSArray *)arguments;
- (void)receiveOutput:(NSData *)data;
- (void)sessionEnded:(id)unused;
- (void)readSession:(id)unused;
- (void)stopSession;
- (NSString *)sessionTitle;
- (void)sendData:(NSData *)data;
@end

@interface WeazlView (Input)
- (void)paste:(id)sender;
@end
