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
    int scrollOffset;
    uint64_t selectionAnchor, selectionEnd;
    BOOL selecting;
}
- (BOOL)startProgram:(NSString *)path arguments:(NSArray *)arguments;
- (void)receiveOutput:(NSData *)data;
- (void)sessionEnded:(id)unused;
- (void)readSession:(id)unused;
- (void)stopSession;
- (NSString *)sessionTitle;
- (void)sendData:(NSData *)data;
@end

@interface WeazlView (Clipboard)
- (void)paste:(id)sender;
@end

@interface WeazlView (Selection)
- (void)copy:(id)sender;
- (void)selectAll:(id)sender;
- (void)clearSelection;
- (BOOL)hasSelection;
- (BOOL)isSelectedColumn:(int)x row:(int)y;
- (const WTCell *)visibleCellAtColumn:(int)x row:(int)y;
- (void)scrollByLines:(int)lines;
- (void)scrollToLive;
@end
