#import "CSPixelLabelNode.h"
#import "CSAssetCatalog.h"
#import <AppKit/AppKit.h>

static const CGFloat CSLabelBaseFontSize = 20.0;

static NSString *CSLabelFontName(void) {
    static NSString *fontName;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Menlo is bundled with macOS and stays legible at small sizes. Fall
        // back to the regular face if the bold face is unavailable.
        if ([NSFont fontWithName:@"Menlo-Bold" size:12.0]) {
            fontName = @"Menlo-Bold";
        } else if ([NSFont fontWithName:@"Menlo" size:12.0]) {
            fontName = @"Menlo";
        } else {
            fontName = @"Monaco";
        }
    });
    return fontName;
}

@implementation CSPixelLabelNode {
    SKNode *_textRoot;
    SKNode *_shadowRoot;
    NSMutableArray<SKLabelNode *> *_lineLabels;
    NSMutableArray<SKLabelNode *> *_shadowLabels;
    NSColor *_shadowColor;
    CGFloat _computedWidth;
    CGFloat _computedHeight;
}

- (instancetype)initWithText:(NSString *)text fontScale:(CGFloat)fontScale color:(NSColor *)color {
    self = [super init];
    if (self) {
        _text = [text copy] ?: @"";
        _fontScale = MAX(0.5, fontScale);
        _textColor = color ?: [NSColor colorWithSRGBRed:1.0 green:0.98 blue:0.91 alpha:1.0];
        _alignment = CSPixelTextAlignmentCenter;
        _shadowEnabled = NO;
        _shadowColor = [NSColor colorWithSRGBRed:0.19 green:0.12 blue:0.22 alpha:0.75];
        _lineLabels = [NSMutableArray array];
        _shadowLabels = [NSMutableArray array];
        _textRoot = [SKNode node];
        _shadowRoot = [SKNode node];
        // With ignoresSiblingOrder enabled, equal z values have no stable draw
        // order. Keep the shadow behind the glyphs and the glyphs on top.
        _shadowRoot.zPosition = 0.0;
        _textRoot.zPosition = 1.0;
        _shadowRoot.alpha = 0.85;
        [self addChild:_shadowRoot];
        [self addChild:_textRoot];
        [self rebuild];
    }
    return self;
}

- (void)setText:(NSString *)text {
    NSString *next = [text copy] ?: @"";
    if ([_text isEqualToString:next]) return;
    _text = next;
    [self rebuild];
}

- (void)setFontScale:(CGFloat)fontScale {
    _fontScale = MAX(0.5, fontScale);
    [self rebuild];
}

- (void)setMaxWidth:(CGFloat)maxWidth {
    _maxWidth = MAX(0.0, maxWidth);
    [self rebuild];
}

- (void)setTextColor:(NSColor *)textColor {
    _textColor = textColor ?: [NSColor whiteColor];
    for (SKLabelNode *label in _lineLabels) {
        label.fontColor = _textColor;
    }
}

- (void)setAlignment:(CSPixelTextAlignment)alignment {
    _alignment = alignment;
    [self rebuild];
}

- (void)setShadowEnabled:(BOOL)shadowEnabled {
    _shadowEnabled = shadowEnabled;
    _shadowRoot.hidden = !shadowEnabled;
}

- (void)setUppercase:(BOOL)uppercase {
    _uppercase = uppercase;
    [self rebuild];
}

- (CGFloat)renderedWidth {
    return _computedWidth;
}

- (CGFloat)renderedHeight {
    return _computedHeight;
}

- (SKLabelHorizontalAlignmentMode)horizontalAlignmentMode {
    switch (self.alignment) {
        case CSPixelTextAlignmentLeft: return SKLabelHorizontalAlignmentModeLeft;
        case CSPixelTextAlignmentRight: return SKLabelHorizontalAlignmentModeRight;
        default: return SKLabelHorizontalAlignmentModeCenter;
    }
}

- (SKLabelNode *)labelForIndex:(NSUInteger)index
                         array:(NSMutableArray<SKLabelNode *> *)array
                      rootNode:(SKNode *)root {
    while (array.count <= index) {
        SKLabelNode *label = [SKLabelNode labelNodeWithFontNamed:CSLabelFontName()];
        label.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
        label.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
        [array addObject:label];
        [root addChild:label];
    }
    SKLabelNode *label = array[index];
    label.hidden = NO;
    return label;
}

- (void)layoutLines:(NSArray<NSString *> *)lines
           fontSize:(CGFloat)fontSize
         horizontal:(SKLabelHorizontalAlignmentMode)horizontal {
    // Whole-point sizes keep glyphs sharp when the scene is scaled to the
    // window's backing resolution.
    NSFont *font = [NSFont fontWithName:CSLabelFontName() size:fontSize]
        ?: [NSFont systemFontOfSize:fontSize];
    CGFloat lineHeight = MAX(fontSize, round(fontSize * 1.18));
    CGFloat glyphHeight = ceil(font.ascender - font.descender);
    CGFloat maxLineWidth = 0.0;

    for (NSUInteger i = 0; i < lines.count; i++) {
        NSString *line = lines[i].length ? lines[i] : @" ";
        SKLabelNode *label = [self labelForIndex:i array:_lineLabels rootNode:_textRoot];
        label.text = line;
        label.fontName = CSLabelFontName();
        label.fontSize = fontSize;
        label.fontColor = self.textColor;
        label.horizontalAlignmentMode = horizontal;
        label.position = CGPointMake(0.0, -(CGFloat)i * lineHeight);
        label.zPosition = 1.0;

        SKLabelNode *shadow = [self labelForIndex:i array:_shadowLabels rootNode:_shadowRoot];
        shadow.text = line;
        shadow.fontName = CSLabelFontName();
        shadow.fontSize = fontSize;
        shadow.fontColor = _shadowColor;
        shadow.horizontalAlignmentMode = horizontal;
        shadow.position = label.position;
        shadow.zPosition = 0.0;

        // AppKit metrics match what SKLabelNode rasterizes and are available
        // immediately, unlike calculateAccumulatedFrame before first layout.
        NSSize measured = [line sizeWithAttributes:@{NSFontAttributeName: font}];
        maxLineWidth = MAX(maxLineWidth, ceil(measured.width));
    }

    for (NSUInteger i = lines.count; i < _lineLabels.count; i++) {
        _lineLabels[i].hidden = YES;
        _shadowLabels[i].hidden = YES;
    }

    _computedWidth = maxLineWidth;
    _computedHeight = glyphHeight + (CGFloat)(lines.count - 1) * lineHeight;
    _textRoot.position = CGPointMake(0.0, round((CGFloat)(lines.count - 1) * lineHeight * 0.5));
    _shadowRoot.position = CGPointMake(2.0, _textRoot.position.y - 2.0);
    _shadowRoot.hidden = !self.shadowEnabled;
}

- (void)rebuild {
    NSString *string = self.uppercase ? self.text.uppercaseString : self.text;
    NSArray<NSString *> *lines = [string componentsSeparatedByString:@"\n"];
    SKLabelHorizontalAlignmentMode horizontal = [self horizontalAlignmentMode];

    // Snap the requested size to a whole point. Long labels are then reduced
    // one point at a time until they fit the supplied width.
    CGFloat fontSize = MAX(10.0, round(CSLabelBaseFontSize * self.fontScale));
    [self layoutLines:lines fontSize:fontSize horizontal:horizontal];
    if (self.maxWidth > 0.0) {
        NSInteger guard = 0;
        while (_computedWidth > self.maxWidth && fontSize > 9.0 && guard < 24) {
            fontSize -= 1.0;
            [self layoutLines:lines fontSize:fontSize horizontal:horizontal];
            guard++;
        }
    }
}

@end
