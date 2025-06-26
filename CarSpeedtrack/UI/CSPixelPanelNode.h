#import <SpriteKit/SpriteKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Nine-sliced pixel-art panel. Keeps corners crisp while stretching the edges
/// and centre, so panels look right at every menu size.
@interface CSPixelPanelNode : SKNode

@property (nonatomic, readonly) CGSize panelSize;

- (instancetype)initWithTextureName:(NSString *)textureName size:(CGSize)size;
- (void)setTint:(NSColor *)color blend:(CGFloat)blend;

@end

NS_ASSUME_NONNULL_END
