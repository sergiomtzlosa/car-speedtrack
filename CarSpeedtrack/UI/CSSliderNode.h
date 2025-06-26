#import <SpriteKit/SpriteKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A compact pixel slider with a chunky knob. Settings handles dragging by
/// calling the tracking methods; the control itself stays render-only.
@interface CSSliderNode : SKNode

@property (nonatomic) CGFloat value;
@property (nonatomic, copy, nullable) void (^valueChanged)(CGFloat value);
@property (nonatomic, readonly) CGFloat sliderWidth;

- (instancetype)initWithWidth:(CGFloat)width value:(CGFloat)value;
- (BOOL)containsScenePoint:(CGPoint)point;
- (void)beginTrackingAtPoint:(CGPoint)point;
- (void)updateTrackingAtPoint:(CGPoint)point;

@end

NS_ASSUME_NONNULL_END
