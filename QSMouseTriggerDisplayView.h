

#import <AppKit/AppKit.h>


@interface QSMouseTriggerDisplayView : NSView {
    BOOL active;
    NSUInteger anchor;
}
- (id)initWithFrame:(NSRect)frame anchor:(NSUInteger)thisAnchor;
- (void)_drawRect:(NSRect)rect withGradientFrom:(NSColor*)colorStart to:(NSColor*)colorEnd start:(NSRectEdge)edge;
@end
