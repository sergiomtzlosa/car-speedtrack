#import <AppKit/AppKit.h>
#import <SpriteKit/SpriteKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CSGameViewInput <NSObject>
@optional
- (void)gameViewKeyDown:(NSEvent *)event;
- (void)gameViewKeyUp:(NSEvent *)event;
- (void)gameViewMouseMovedToPoint:(CGPoint)point;
- (void)gameViewMouseDownAtPoint:(CGPoint)point button:(NSInteger)button;
- (void)gameViewMouseDraggedToPoint:(CGPoint)point button:(NSInteger)button;
- (void)gameViewMouseUpAtPoint:(CGPoint)point button:(NSInteger)button;
- (void)gameViewScrollWheel:(CGFloat)delta;
- (void)gameViewFocusLost;
@end

/// SKView that owns first-responder status and forwards scene-space mouse and
/// keyboard events to whichever scene is currently presented.
@interface CSGameView : SKView

@property (nonatomic, weak, nullable) id<CSGameViewInput> inputTarget;

@end

NS_ASSUME_NONNULL_END
