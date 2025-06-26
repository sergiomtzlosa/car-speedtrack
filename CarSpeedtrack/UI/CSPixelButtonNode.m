#import "CSPixelButtonNode.h"
#import "CSAssetCatalog.h"

@implementation CSPixelButtonNode {
    NSString *_text;
    NSString *_textureName;
    CGFloat _fontScale;
    NSColor *_textColor;
}

- (instancetype)initWithText:(NSString *)text
                 textureName:(NSString *)textureName
                        size:(CGSize)size
                   fontScale:(CGFloat)fontScale {
    return [self initWithText:text textureName:textureName size:size fontScale:fontScale
                    textColor:[NSColor colorWithSRGBRed:0.25 green:0.16 blue:0.30 alpha:1.0]];
}

- (instancetype)initWithText:(NSString *)text
                 textureName:(NSString *)textureName
                        size:(CGSize)size
                   fontScale:(CGFloat)fontScale
                   textColor:(NSColor *)textColor {
    self = [super init];
    if (self) {
        _buttonSize = CGSizeMake(MAX(16.0, size.width), MAX(16.0, size.height));
        _textureName = [textureName copy];
        _text = [text copy];
        _fontScale = MAX(0.5, fontScale);
        _textColor = textColor ?: [NSColor colorWithSRGBRed:0.25 green:0.16 blue:0.30 alpha:1.0];
        _enabled = YES;
        _panel = [[CSPixelPanelNode alloc] initWithTextureName:textureName size:_buttonSize];
        _panel.zPosition = 0.0;
        [self addChild:_panel];
        _label = [[CSPixelLabelNode alloc] initWithText:text fontScale:_fontScale color:_textColor];
        _label.alignment = CSPixelTextAlignmentCenter;
        _label.position = CGPointZero;
        // The view uses ignoresSiblingOrder, so equal zPosition values have no
        // stable draw order. Keep the label explicitly above the button plate.
        _label.zPosition = 20.0;
        [_panel addChild:_label];
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (instancetype)initWithIcon:(NSString *)iconName
                 textureName:(NSString *)textureName
                        size:(CGSize)size {
    self = [super init];
    if (self) {
        _buttonSize = CGSizeMake(MAX(16.0, size.width), MAX(16.0, size.height));
        _textureName = [textureName copy];
        _fontScale = 1.0;
        _textColor = [NSColor whiteColor];
        _enabled = YES;
        _panel = [[CSPixelPanelNode alloc] initWithTextureName:textureName size:_buttonSize];
        _panel.zPosition = 0.0;
        [self addChild:_panel];
        _icon = [SKSpriteNode spriteNodeWithTexture:[[CSAssetCatalog shared] textureNamed:iconName fallback:@"icon_play"]];
        if (_icon.texture.size.width > 0) {
            _icon.size = CGSizeMake(MIN(_buttonSize.width * 0.62, _icon.texture.size.width),
                                    MIN(_buttonSize.height * 0.62, _icon.texture.size.height));
        }
        _icon.position = CGPointZero;
        _icon.zPosition = 20.0;
        [_panel addChild:_icon];
    }
    return self;
}

- (void)setText:(NSString *)text {
    _text = [text copy];
    self.label.text = text;
}

- (NSString *)text {
    return _text;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    self.alpha = enabled ? 1.0 : 0.55;
}

- (void)setFocused:(BOOL)focused {
    if (_focused == focused) return;
    _focused = focused;
    [self.panel setTint:[NSColor colorWithSRGBRed:1.0 green:0.92 blue:0.55 alpha:1.0]
                  blend:focused ? 0.28 : 0.0];
    self.scale = focused ? 1.035 : 1.0;
}

- (BOOL)containsScenePoint:(CGPoint)point {
    if (self.hidden || self.alpha < 0.01) return NO;
    CGPoint local = self.scene ? [self convertPoint:point fromNode:self.scene] : point;
    CGRect bounds = CGRectMake(-_buttonSize.width * 0.5, -_buttonSize.height * 0.5,
                               _buttonSize.width, _buttonSize.height);
    return CGRectContainsPoint(bounds, local);
}

- (void)activate {
    if (!self.enabled) return;
    if (self.actionBlock) self.actionBlock();
}

@end
