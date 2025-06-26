#import "CSPixelPanelNode.h"
#import "CSAssetCatalog.h"

@implementation CSPixelPanelNode {
    NSMutableArray<SKSpriteNode *> *_slices;
}

- (instancetype)initWithTextureName:(NSString *)textureName size:(CGSize)size {
    self = [super init];
    if (self) {
        _panelSize = CGSizeMake(MAX(8.0, size.width), MAX(8.0, size.height));
        _slices = [NSMutableArray array];
        SKTexture *texture = [[CSAssetCatalog shared] textureNamed:textureName fallback:@"ui_panel"];
        if (!texture) {
            self.alpha = 0.0;
            return self;
        }
        CGFloat w = _panelSize.width;
        CGFloat h = _panelSize.height;
        CGFloat margin = 9.0;
        if (w < margin * 2.2 || h < margin * 2.2) {
            SKSpriteNode *whole = [SKSpriteNode spriteNodeWithTexture:texture size:_panelSize];
            whole.anchorPoint = CGPointMake(0.5, 0.5);
            [self addChild:whole];
            return self;
        }
        CGFloat tw = texture.size.width;
        CGFloat th = texture.size.height;
        CGFloat cx = margin / tw;
        CGFloat cy = margin / th;
        NSArray<NSValue *> *rects = @[
            [NSValue valueWithRect:NSMakeRect(0, 0, cx, cy)],
            [NSValue valueWithRect:NSMakeRect(cx, 0, 1.0 - cx * 2.0, cy)],
            [NSValue valueWithRect:NSMakeRect(1.0 - cx, 0, cx, cy)],
            [NSValue valueWithRect:NSMakeRect(0, cy, cx, 1.0 - cy * 2.0)],
            [NSValue valueWithRect:NSMakeRect(cx, cy, 1.0 - cx * 2.0, 1.0 - cy * 2.0)],
            [NSValue valueWithRect:NSMakeRect(1.0 - cx, cy, cx, 1.0 - cy * 2.0)],
            [NSValue valueWithRect:NSMakeRect(0, 1.0 - cy, cx, cy)],
            [NSValue valueWithRect:NSMakeRect(cx, 1.0 - cy, 1.0 - cx * 2.0, cy)],
            [NSValue valueWithRect:NSMakeRect(1.0 - cx, 1.0 - cy, cx, cy)],
        ];
        NSArray<NSValue *> *frames = @[
            [NSValue valueWithRect:NSMakeRect(0, 0, margin, margin)],
            [NSValue valueWithRect:NSMakeRect(margin, 0, w - margin * 2.0, margin)],
            [NSValue valueWithRect:NSMakeRect(w - margin, 0, margin, margin)],
            [NSValue valueWithRect:NSMakeRect(0, margin, margin, h - margin * 2.0)],
            [NSValue valueWithRect:NSMakeRect(margin, margin, w - margin * 2.0, h - margin * 2.0)],
            [NSValue valueWithRect:NSMakeRect(w - margin, margin, margin, h - margin * 2.0)],
            [NSValue valueWithRect:NSMakeRect(0, h - margin, margin, margin)],
            [NSValue valueWithRect:NSMakeRect(margin, h - margin, w - margin * 2.0, margin)],
            [NSValue valueWithRect:NSMakeRect(w - margin, h - margin, margin, margin)],
        ];
        for (NSInteger i = 0; i < 9; i++) {
            SKTexture *slice = [SKTexture textureWithRect:rects[i].rectValue inTexture:texture];
            slice.filteringMode = SKTextureFilteringNearest;
            CGRect frame = frames[i].rectValue;
            SKSpriteNode *sprite = [SKSpriteNode spriteNodeWithTexture:slice
                                                                  size:frame.size];
            sprite.anchorPoint = CGPointZero;
            sprite.position = CGPointMake(frame.origin.x - w * 0.5,
                                         frame.origin.y - h * 0.5);
            [self addChild:sprite];
            [_slices addObject:sprite];
        }
    }
    return self;
}

- (void)setTint:(NSColor *)color blend:(CGFloat)blend {
    for (SKSpriteNode *slice in _slices) {
        slice.color = color;
        slice.colorBlendFactor = MIN(1.0, MAX(0.0, blend));
    }
}

@end
