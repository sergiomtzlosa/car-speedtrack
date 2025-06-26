#import "CSSliderNode.h"
#import "CSAssetCatalog.h"

@implementation CSSliderNode {
    SKSpriteNode *_track;
    SKSpriteNode *_fill;
    SKSpriteNode *_knob;
}

- (instancetype)initWithWidth:(CGFloat)width value:(CGFloat)value {
    self = [super init];
    if (self) {
        _sliderWidth = MAX(40.0, width);
        CSAssetCatalog *assets = [CSAssetCatalog shared];
        _track = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"ui_slider_track"]];
        _track.size = CGSizeMake(_sliderWidth, 12);
        _track.position = CGPointZero;
        _track.zPosition = 1;
        [self addChild:_track];
        _fill = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"ui_bar_pink"]];
        _fill.anchorPoint = CGPointMake(0, 0.5);
        _fill.position = CGPointMake(-_sliderWidth * 0.5, 0);
        _fill.zPosition = 2;
        [self addChild:_fill];
        _knob = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"ui_slider_knob"]];
        _knob.size = CGSizeMake(18, 18);
        _knob.position = CGPointZero;
        _knob.zPosition = 3;
        [self addChild:_knob];
        [self setValue:value];
    }
    return self;
}

- (void)setValue:(CGFloat)value {
    _value = MIN(1.0, MAX(0.0, value));
    CGFloat x = -_sliderWidth * 0.5 + _sliderWidth * _value;
    _fill.size = CGSizeMake(MAX(1.0, _sliderWidth * _value), 8);
    _knob.position = CGPointMake(x, 0);
}

- (BOOL)containsScenePoint:(CGPoint)point {
    if (self.hidden || self.alpha < 0.1) return NO;
    CGPoint local = self.scene ? [self convertPoint:point fromNode:self.scene] : point;
    return CGRectContainsPoint(CGRectMake(-_sliderWidth * 0.5 - 8, -12,
                                          _sliderWidth + 16, 24), local);
}

- (void)beginTrackingAtPoint:(CGPoint)point {
    [self updateTrackingAtPoint:point];
}

- (void)updateTrackingAtPoint:(CGPoint)point {
    CGPoint local = self.scene ? [self convertPoint:point fromNode:self.scene] : point;
    CGFloat fraction = (local.x + _sliderWidth * 0.5) / _sliderWidth;
    CGFloat clamped = MIN(1.0, MAX(0.0, fraction));
    [self setValue:clamped];
    if (self.valueChanged) self.valueChanged(clamped);
}

@end
