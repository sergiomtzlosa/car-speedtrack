#import <SpriteKit/SpriteKit.h>
#import "CSPixelPanelNode.h"
#import "CSPixelLabelNode.h"

NS_ASSUME_NONNULL_BEGIN

/// A mouse and keyboard friendly pixel button with a nine-sliced background,
/// optional icon, label, hover/focus state and an activation block.
@interface CSPixelButtonNode : SKNode

@property (nonatomic, readonly) CGSize buttonSize;
@property (nonatomic, copy) NSString *text;
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL focused;
@property (nonatomic, copy, nullable) void (^actionBlock)(void);
@property (nonatomic, readonly) CSPixelPanelNode *panel;
@property (nonatomic, readonly, nullable) CSPixelLabelNode *label;
@property (nonatomic, readonly, nullable) SKSpriteNode *icon;

- (instancetype)initWithText:(NSString *)text
                 textureName:(NSString *)textureName
                        size:(CGSize)size
                   fontScale:(CGFloat)fontScale;
- (instancetype)initWithText:(NSString *)text
                 textureName:(NSString *)textureName
                        size:(CGSize)size
                   fontScale:(CGFloat)fontScale
                   textColor:(NSColor *)textColor;
- (instancetype)initWithIcon:(NSString *)iconName
                 textureName:(NSString *)textureName
                        size:(CGSize)size;

- (BOOL)containsScenePoint:(CGPoint)point;
- (void)activate;

@end

NS_ASSUME_NONNULL_END
