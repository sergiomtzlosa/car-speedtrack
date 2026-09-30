#import "CSGarageScene.h"
#import "CSAppContext.h"
#import "CSGameCatalog.h"
#import "CSSaveManager.h"
#import "CSAssetCatalog.h"
#import "CSAudioManager.h"
#import "CSGameViewController.h"

static NSString *CSWrapWords(NSString *text, NSUInteger width) {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    for (NSString *word in [text componentsSeparatedByString:@" "]) {
        if (current.length == 0) {
            [current appendString:word];
        } else if (current.length + 1 + word.length <= width) {
            [current appendFormat:@" %@", word];
        } else {
            [lines addObject:current];
            current = [NSMutableString stringWithString:word];
        }
    }
    if (current.length) [lines addObject:current];
    if (lines.count > 2) {
        lines = [[lines subarrayWithRange:NSMakeRange(0, 2)] mutableCopy];
    }
    return [lines componentsJoinedByString:@"\n"];
}

@implementation CSGarageScene {
    NSInteger _index;
    SKSpriteNode *_carSprite;
    CSPixelLabelNode *_carNameLabel;
    CSPixelLabelNode *_taglineLabel;
    CSPixelLabelNode *_unlockLabel;
    CSPixelLabelNode *_starLabel;
    CSPixelLabelNode *_counterLabel;
    CSPixelButtonNode *_equipButton;
    SKSpriteNode *_progressFill;
    NSMutableArray<SKSpriteNode *> *_pips;
    NSArray<CSCar *> *_cars;
}

- (instancetype)init {
    self = [super initWithSize:CGSizeMake(640, 360)];
    if (self) {
        self.screenMusicName = @"music_menu";
        _cars = CSAppContext.shared.catalog.cars;
        _pips = [NSMutableArray array];
        NSString *selected = CSAppContext.shared.selectedCarID;
        _index = 0;
        for (NSUInteger i = 0; i < _cars.count; i++) {
            if ([_cars[i].carID isEqualToString:selected]) {
                _index = (NSInteger)i;
                break;
            }
        }
        [self buildScreen];
    }
    return self;
}

- (void)buildScreen {
    CSAssetCatalog *assets = [CSAssetCatalog shared];
    SKSpriteNode *header = [SKSpriteNode spriteNodeWithColor:[NSColor colorWithSRGBRed:0.22 green:0.14 blue:0.27 alpha:0.9]
                                                        size:CGSizeMake(640, 52)];
    header.anchorPoint = CGPointZero;
    header.position = CGPointMake(0, 308);
    header.zPosition = 1;
    [self.contentRoot addChild:header];
    [self addLabel:@"GARAGE" atPoint:CGPointMake(320, 338) scale:1.7
             color:[NSColor colorWithSRGBRed:1 green:0.97 blue:0.87 alpha:1]
         alignment:CSPixelTextAlignmentCenter zPosition:3];

    CSPixelButtonNode *back = [[CSPixelButtonNode alloc] initWithText:@"BACK"
                                                           textureName:@"ui_button_lavender"
                                                                  size:CGSizeMake(70, 24)
                                                             fontScale:0.75];
    back.position = CGPointMake(45, 338);
    __weak typeof(self) weakSelf = self;
    back.actionBlock = ^{ [CSAppContext.shared.viewController presentMenu]; (void)weakSelf; };
    [self addButton:back];

    SKSpriteNode *star = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"icon_star_full"]];
    star.size = CGSizeMake(16, 16);
    star.position = CGPointMake(536, 338);
    star.zPosition = 3;
    [self.contentRoot addChild:star];
    _starLabel = [self addLabel:[NSString stringWithFormat:@"%ld / 300", (long)[CSAppContext.shared displayStars]]
                        atPoint:CGPointMake(552, 338) scale:0.7
                          color:[NSColor colorWithSRGBRed:1 green:0.94 blue:0.72 alpha:1]
                      alignment:CSPixelTextAlignmentLeft zPosition:3];
    _starLabel.shadowEnabled = NO;

    [self addPanelWithTexture:@"ui_panel_cream" size:CGSizeMake(270, 238) position:CGPointMake(160, 158) zPosition:2];
    [self addPanelWithTexture:@"ui_panel" size:CGSizeMake(320, 238) position:CGPointMake(458, 158) zPosition:2];

    _counterLabel = [self addLabel:@"" atPoint:CGPointMake(160, 258) scale:0.66
                             color:[NSColor colorWithSRGBRed:0.40 green:0.28 blue:0.44 alpha:1]
                         alignment:CSPixelTextAlignmentCenter zPosition:4];
    _counterLabel.shadowEnabled = NO;

    _carSprite = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"car_sunny-bug_0"]];
    _carSprite.size = CGSizeMake(36 * 2.4, 58 * 2.4);
    _carSprite.position = CGPointMake(160, 168);
    _carSprite.zPosition = 4;
    [self.contentRoot addChild:_carSprite];
    if (!CSAppContext.shared.save.reducedMotion) {
        [_carSprite runAction:[SKAction repeatActionForever:[SKAction sequence:@[
            [SKAction moveByX:0 y:3 duration:0.9],
            [SKAction moveByX:0 y:-3 duration:0.9],
        ]]]];
    }

    [self addLabel:@"SELECTED RIDE" atPoint:CGPointMake(160, 78) scale:0.6
             color:[NSColor colorWithSRGBRed:0.42 green:0.30 blue:0.46 alpha:0.9]
         alignment:CSPixelTextAlignmentCenter zPosition:4].shadowEnabled = NO;

    CSPixelButtonNode *prev = [[CSPixelButtonNode alloc] initWithIcon:@"icon_arrow_left"
                                                           textureName:@"ui_button_sky"
                                                                  size:CGSizeMake(28, 32)];
    prev.position = CGPointMake(37, 170);
    prev.actionBlock = ^{ [weakSelf cycleCar:-1]; };
    [self addButton:prev];

    CSPixelButtonNode *next = [[CSPixelButtonNode alloc] initWithIcon:@"icon_arrow_right"
                                                           textureName:@"ui_button_sky"
                                                                  size:CGSizeMake(28, 32)];
    next.position = CGPointMake(283, 170);
    next.actionBlock = ^{ [weakSelf cycleCar:1]; };
    [self addButton:next];

    _carNameLabel = [self addLabel:@"" atPoint:CGPointMake(325, 248) scale:1.08
                             color:[NSColor colorWithSRGBRed:0.25 green:0.15 blue:0.31 alpha:1]
                         alignment:CSPixelTextAlignmentLeft zPosition:4];
    _carNameLabel.shadowEnabled = NO;

    _taglineLabel = [self addLabel:@"" atPoint:CGPointMake(325, 221) scale:0.60
                             color:[NSColor colorWithSRGBRed:0.38 green:0.26 blue:0.43 alpha:1]
                         alignment:CSPixelTextAlignmentLeft zPosition:4];
    _taglineLabel.shadowEnabled = NO;

    NSArray<NSString *> *statNames = @[@"SPEED", @"ACCEL", @"GRIP"];
    for (NSInteger row = 0; row < 3; row++) {
        CGFloat y = 190 - row * 25;
        [self addLabel:statNames[row] atPoint:CGPointMake(325, y) scale:0.6
                 color:[NSColor colorWithSRGBRed:0.39 green:0.27 blue:0.44 alpha:1]
             alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;
        for (NSInteger pip = 0; pip < 5; pip++) {
            SKSpriteNode *node = [SKSpriteNode spriteNodeWithColor:
                [NSColor colorWithSRGBRed:0.86 green:0.82 blue:0.85 alpha:1]
                                                                  size:CGSizeMake(18, 10)];
            node.anchorPoint = CGPointMake(0, 0.5);
            node.position = CGPointMake(390 + pip * 22, y);
            node.zPosition = 4;
            [self.contentRoot addChild:node];
            [_pips addObject:node];
        }
    }

    _unlockLabel = [self addLabel:@"" atPoint:CGPointMake(325, 112) scale:0.61
                            color:[NSColor colorWithSRGBRed:0.38 green:0.26 blue:0.43 alpha:1]
                        alignment:CSPixelTextAlignmentLeft zPosition:4];
    _unlockLabel.shadowEnabled = NO;

    SKSpriteNode *track = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"ui_slider_track"]];
    track.size = CGSizeMake(210, 12);
    track.position = CGPointMake(432, 94);
    track.zPosition = 4;
    [self.contentRoot addChild:track];
    _progressFill = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"ui_bar_mint"]];
    _progressFill.anchorPoint = CGPointMake(0, 0.5);
    _progressFill.size = CGSizeMake(1, 10);
    _progressFill.position = CGPointMake(327, 94);
    _progressFill.zPosition = 5;
    [self.contentRoot addChild:_progressFill];

    _equipButton = [[CSPixelButtonNode alloc] initWithText:@"EQUIP"
                                                textureName:@"ui_button_mint"
                                                       size:CGSizeMake(150, 32)
                                                  fontScale:1.0];
    _equipButton.position = CGPointMake(516, 66);
    _equipButton.actionBlock = ^{ [weakSelf equipCar]; };
    [self addButton:_equipButton];

    [self updateDisplay];
}

- (void)cycleCar:(NSInteger)delta {
    _index = (_index + delta + (NSInteger)_cars.count) % (NSInteger)_cars.count;
    [self updateDisplay];
    [CSAppContext.shared.audio playSFX:@"sfx_click"];
}

- (void)updateDisplay {
    CSAppContext *context = CSAppContext.shared;
    CSCar *car = _cars[_index];
    NSInteger stars = [context displayStars];
    BOOL unlocked = stars >= car.unlockStars;

    _counterLabel.text = [NSString stringWithFormat:@"CAR %ld / %ld", (long)(_index + 1), (long)_cars.count];
    _carSprite.texture = [[CSAssetCatalog shared] textureNamed:
        [NSString stringWithFormat:@"%@_0", car.assetPrefix] fallback:@"car_sunny-bug_0"];
    _carSprite.color = unlocked ? [NSColor whiteColor] : [NSColor colorWithSRGBRed:0.35 green:0.32 blue:0.38 alpha:1];
    _carSprite.colorBlendFactor = unlocked ? 0.0 : 0.75;
    _carNameLabel.text = car.name.uppercaseString;
    _taglineLabel.text = CSWrapWords(car.tagline, 34);

    NSArray<NSNumber *> *values = @[@(car.speed), @(car.acceleration), @(car.grip)];
    for (NSInteger row = 0; row < 3; row++) {
        NSInteger value = MAX(1, MIN(5, values[row].integerValue));
        for (NSInteger pip = 0; pip < 5; pip++) {
            SKSpriteNode *node = _pips[row * 5 + pip];
            node.color = pip < value
                ? [NSColor colorWithSRGBRed:0.44 green:0.86 blue:0.68 alpha:1]
                : [NSColor colorWithSRGBRed:0.86 green:0.82 blue:0.85 alpha:1];
            node.colorBlendFactor = 1.0;
        }
    }

    if (unlocked) {
        BOOL equipped = [context.selectedCarID isEqualToString:car.carID];
        _unlockLabel.text = equipped ? @"THIS CAR IS EQUIPPED" : @"READY TO RACE";
        _equipButton.text = equipped ? @"EQUIPPED" : @"EQUIP";
        _equipButton.enabled = !equipped;
        _progressFill.size = CGSizeMake(210, 10);
    } else {
        NSInteger need = MAX(0, car.unlockStars - stars);
        _unlockLabel.text = [NSString stringWithFormat:@"NEEDS %ld MORE STAR%@", (long)need, need == 1 ? @"" : @"S"];
        _equipButton.text = @"LOCKED";
        _equipButton.enabled = NO;
        CGFloat fraction = car.unlockStars > 0 ? MIN(1.0, (CGFloat)stars / (CGFloat)car.unlockStars) : 1.0;
        _progressFill.size = CGSizeMake(MAX(1.0, 210.0 * fraction), 10);
    }
    _starLabel.text = [NSString stringWithFormat:@"%ld / 300", (long)stars];
    [self refreshFocus];
}

- (void)equipCar {
    CSCar *car = _cars[_index];
    NSInteger stars = [CSAppContext.shared displayStars];
    if (stars < car.unlockStars) return;
    [CSAppContext.shared setSelectedCarID:car.carID];
    [CSAppContext.shared.audio playSFX:@"sfx_unlock"];
    [self showToast:[NSString stringWithFormat:@"%@ EQUIPPED!", car.name.uppercaseString]];
    [self updateDisplay];
    [self focusButtonAtIndex:(NSInteger)[self.buttons indexOfObject:_equipButton]];
}

- (void)goBack {
    [CSAppContext.shared.viewController presentMenu];
}

@end
