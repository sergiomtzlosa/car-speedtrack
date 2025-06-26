#import <SpriteKit/SpriteKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CSPixelTextAlignment) {
    CSPixelTextAlignmentLeft = 0,
    CSPixelTextAlignmentCenter,
    CSPixelTextAlignmentRight,
};

/// A label made from the generated glyph atlas. Renders crisp pixel glyphs at
/// any integer scale, with optional offset drop shadow.
@interface CSPixelLabelNode : SKNode

@property (nonatomic, copy) NSString *text;
@property (nonatomic) CGFloat fontScale;
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
