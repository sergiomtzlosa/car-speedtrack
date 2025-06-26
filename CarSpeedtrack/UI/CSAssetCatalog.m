#import "CSAssetCatalog.h"
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>

@implementation CSAssetCatalog {
    NSMutableDictionary<NSString *, SKTexture *> *_cache;
    NSMutableDictionary<NSNumber *, SKTexture *> *_glyphCache;
    NSDictionary<NSString *, id> *_fontMetrics;
}

+ (CSAssetCatalog *)shared {
    static CSAssetCatalog *catalog;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        catalog = [[CSAssetCatalog alloc] init];
    });
    return catalog;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [NSMutableDictionary dictionary];
        _glyphCache = [NSMutableDictionary dictionary];
        NSURL *fontURL = [[NSBundle mainBundle] URLForResource:@"font" withExtension:@"json" subdirectory:@"Data"];
        if (!fontURL) {
            fontURL = [[NSBundle mainBundle] URLForResource:@"font" withExtension:@"json"];
        }
        NSData *data = fontURL ? [NSData dataWithContentsOfURL:fontURL] : nil;
        NSDictionary *metrics = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        _fontMetrics = [metrics isKindOfClass:[NSDictionary class]] ? metrics : @{
            @"cellW": @12, @"cellH": @20, @"advance": @9,
            @"lineHeight": @18, @"firstChar": @32, @"lastChar": @126,
        };
    }
    return self;
}

- (NSDictionary<NSString *, id> *)fontMetrics {
    return _fontMetrics;
}

- (CGFloat)glyphAdvance {
    return MAX(4.0, [_fontMetrics[@"advance"] doubleValue]);
}

- (CGFloat)glyphLineHeight {
    return MAX(8.0, [_fontMetrics[@"lineHeight"] doubleValue]);
}

- (CGFloat)glyphCellHeight {
    return MAX(10.0, [_fontMetrics[@"cellH"] doubleValue]);
}

- (nullable SKTexture *)textureNamed:(NSString *)name {
    if (name.length == 0) return nil;
    SKTexture *cached = _cache[name];
    if (cached) return cached;
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *url = [bundle URLForResource:name withExtension:@"png" subdirectory:@"Art"];
    if (!url) {
        url = [bundle URLForResource:name withExtension:@"png"];
    }
    if (!url) {
        NSLog(@"CarSpeedtrack: missing art %@", name);
        return nil;
    }
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!source) return nil;
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    if (!image) return nil;
    SKTexture *texture = [SKTexture textureWithCGImage:image];
    CGImageRelease(image);
    texture.filteringMode = SKTextureFilteringNearest;
    _cache[name] = texture;
    return texture;
}

- (SKTexture *)textureNamed:(NSString *)name fallback:(NSString *)fallback {
    return [self textureNamed:name] ?: [self textureNamed:fallback];
}

- (nullable SKTexture *)glyphTextureForCharacter:(unichar)character {
    if (character < 32 || character > 126) return nil;
    NSNumber *key = @(character);
    SKTexture *cached = _glyphCache[key];
    if (cached) return cached;
    NSString *name = [NSString stringWithFormat:@"glyph_%03d", (int)character];
    SKTexture *texture = [self textureNamed:name];
    if (texture) _glyphCache[key] = texture;
    return texture;
}

- (SKSpriteNode *)spriteNamed:(NSString *)name {
    SKTexture *texture = [self textureNamed:name];
    SKSpriteNode *sprite = [[SKSpriteNode alloc] initWithTexture:texture];
    sprite.anchorPoint = CGPointMake(0.5, 0.5);
    return sprite;
}

- (NSColor *)colorFromHex:(NSString *)hex {
    return [self colorFromHex:hex alpha:1.0];
}

- (NSColor *)colorFromHex:(NSString *)hex alpha:(CGFloat)alpha {
    NSString *clean = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (clean.length != 6) clean = @"8EDB78";
    unsigned value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:clean];
    [scanner scanHexInt:&value];
    CGFloat r = ((value >> 16) & 0xFF) / 255.0;
    CGFloat g = ((value >> 8) & 0xFF) / 255.0;
    CGFloat b = (value & 0xFF) / 255.0;
    return [NSColor colorWithSRGBRed:r green:g blue:b alpha:alpha];
}

@end
