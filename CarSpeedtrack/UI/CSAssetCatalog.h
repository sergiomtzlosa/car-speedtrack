#import <Foundation/Foundation.h>
#import <SpriteKit/SpriteKit.h>
#import "CSModels.h"

NS_ASSUME_NONNULL_BEGIN

/// Cached textures for everything in Resources/Art plus the generated bitmap
/// font metrics. All textures use nearest-neighbour filtering.
@interface CSAssetCatalog : NSObject

@property (class, readonly) CSAssetCatalog *shared;

@property (nonatomic, readonly) NSDictionary<NSString *, id> *fontMetrics;
@property (nonatomic, readonly) CGFloat glyphAdvance;
@property (nonatomic, readonly) CGFloat glyphLineHeight;
@property (nonatomic, readonly) CGFloat glyphCellHeight;

- (nullable SKTexture *)textureNamed:(NSString *)name;
- (SKTexture *)textureNamed:(NSString *)name fallback:(NSString *)fallback;
- (nullable SKTexture *)glyphTextureForCharacter:(unichar)character;
- (SKSpriteNode *)spriteNamed:(NSString *)name;
- (NSColor *)colorFromHex:(NSString *)hex alpha:(CGFloat)alpha;
- (NSColor *)colorFromHex:(NSString *)hex;

@end

NS_ASSUME_NONNULL_END
