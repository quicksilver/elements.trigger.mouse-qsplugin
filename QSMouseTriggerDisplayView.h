

#import <AppKit/AppKit.h>


@interface QSMouseTriggerDisplayView : NSView {
    BOOL active;
    int anchor;
}
- (id)initWithFrame:(NSRect)frame anchor:(int)thisAnchor;
- (void)_drawRect:(NSRect)rect withGradientFrom:(NSColor*)colorStart to:(NSColor*)colorEnd start:(NSRectEdge)edge;
@end
