#import <SpriteKit/SpriteKit.h>
#import "CSGameView.h"
#import "CSPixelButtonNode.h"
#import "CSPixelPanelNode.h"
#import "CSPixelLabelNode.h"

NS_ASSUME_NONNULL_BEGIN

/// Common menu scene behaviour: generated background, mouse hover, keyboard
/// focus cycling, a click sound, and scene input forwarding.
@interface CSScreenScene : SKScene <CSGameViewInput>

@property (nonatomic, readonly) NSMutableArray<CSPixelButtonNode *> *buttons;
@property (nonatomic) NSInteger focusedIndex;
@property (nonatomic, copy) NSString *screenMusicName;
@property (nonatomic) BOOL musicLoops;
@property (nonatomic, readonly) SKNode *contentRoot;

- (instancetype)initWithSize:(CGSize)size NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (void)addButton:(CSPixelButtonNode *)button;
- (void)focusButtonAtIndex:(NSInteger)index;
- (void)moveFocus:(NSInteger)delta;
- (void)activateFocusedButton;
- (void)goBack;
- (void)refreshFocus;

- (CSPixelLabelNode *)addLabel:(NSString *)text
                        atPoint:(CGPoint)point
                          scale:(CGFloat)scale
                          color:(NSColor *)color
                      alignment:(CSPixelTextAlignment)alignment
                      zPosition:(CGFloat)z;

- (CSPixelPanelNode *)addPanelWithTexture:(NSString *)texture
                                     size:(CGSize)size
                                 position:(CGPoint)position
                                zPosition:(CGFloat)z;

- (void)playClick;
- (void)showToast:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
