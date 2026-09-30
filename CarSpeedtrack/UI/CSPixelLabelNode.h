#import <SpriteKit/SpriteKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CSPixelTextAlignment) {
    CSPixelTextAlignmentLeft = 0,
    CSPixelTextAlignmentCenter,
    CSPixelTextAlignmentRight,
};

/// A crisp, smoothly rendered label with an optional offset drop shadow.
/// Font sizes are snapped to whole points so text stays sharp at the game's
/// 2x backing scale. Set maxWidth to shrink long strings to fit a container.
@interface CSPixelLabelNode : SKNode

@property (nonatomic, copy) NSString *text;
@property (nonatomic) CGFloat fontScale;
@property (nonatomic) CGFloat maxWidth;
@property (nonatomic, strong) NSColor *textColor;
@property (nonatomic) CSPixelTextAlignment alignment;
@property (nonatomic) BOOL shadowEnabled;
@property (nonatomic) BOOL uppercase;

- (instancetype)initWithText:(NSString *)text fontScale:(CGFloat)fontScale color:(NSColor *)color;
- (void)setText:(NSString *)text;
- (CGFloat)renderedWidth;
- (CGFloat)renderedHeight;

@end

NS_ASSUME_NONNULL_END
