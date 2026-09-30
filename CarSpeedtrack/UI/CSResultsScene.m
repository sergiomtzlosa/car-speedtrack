#import "CSResultsScene.h"
#import "CSAppContext.h"
#import "CSGameCatalog.h"
#import "CSSaveManager.h"
#import "CSAudioManager.h"
#import "CSAssetCatalog.h"
#import "CSGameViewController.h"
#import <math.h>

static NSString *CSResultsFormatNumber(NSInteger value) {
    static NSNumberFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSNumberFormatter new];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.maximumFractionDigits = 0;
    });
    return [formatter stringFromNumber:@(value)] ?: [NSString stringWithFormat:@"%ld", (long)value];
}

static NSString *CSResultsFormatTime(NSTimeInterval duration) {
    NSInteger total = MAX(0, (NSInteger)llround(duration));
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(total / 60), (long)(total % 60)];
}

@interface CSResultsScene ()
@property (nonatomic, strong) CSRunResult *result;
@end

@implementation CSResultsScene {
    NSMutableArray<SKSpriteNode *> *_starIcons;
    CSPixelLabelNode *_newBestLabel;
    NSInteger _nextLevelID;
}

- (instancetype)initWithResult:(CSRunResult *)result {
    self = [super initWithSize:CGSizeMake(640, 360)];
    if (self) {
        _result = result;
        _starIcons = [NSMutableArray array];
        _nextLevelID = result.levelID + 1;
        self.screenMusicName = result.completed ? @"music_win" : @"music_lose";
        self.musicLoops = YES;
        [self buildScreen];
    }
    return self;
}

- (void)buildScreen {
    CSAppContext *context = CSAppContext.shared;
    CSLevel *level = [context.catalog levelForID:_result.levelID];
    CSWorld *world = level ? [context.catalog worldForID:level.worldID] : [context.catalog worldForID:_result.worldID];
    CSAssetCatalog *assets = [CSAssetCatalog shared];
    NSColor *accent = [assets colorFromHex:world.accentHex ?: @"#8EDB78"];
    NSColor *ink = [NSColor colorWithSRGBRed:0.24 green:0.14 blue:0.30 alpha:1.0];
    NSColor *softInk = [NSColor colorWithSRGBRed:0.40 green:0.28 blue:0.45 alpha:1.0];

    SKSpriteNode *topAccent = [SKSpriteNode spriteNodeWithColor:accent size:CGSizeMake(640, 7)];
    topAccent.anchorPoint = CGPointZero;
    topAccent.position = CGPointMake(0, 353);
    topAccent.zPosition = 1;
    [self.contentRoot addChild:topAccent];

    SKSpriteNode *header = [SKSpriteNode spriteNodeWithColor:
        [NSColor colorWithSRGBRed:0.22 green:0.14 blue:0.27 alpha:0.93] size:CGSizeMake(640, 56)];
    header.anchorPoint = CGPointZero;
    header.position = CGPointMake(0, 304);
    header.zPosition = 1;
    [self.contentRoot addChild:header];
    SKSpriteNode *headerLine = [SKSpriteNode spriteNodeWithColor:accent size:CGSizeMake(640, 3)];
    headerLine.anchorPoint = CGPointZero;
    headerLine.position = CGPointMake(0, 304);
    headerLine.zPosition = 2;
    [self.contentRoot addChild:headerLine];

    NSString *title = [self titleText];
    [self addLabel:title atPoint:CGPointMake(320, 334) scale:1.6
             color:[NSColor colorWithSRGBRed:1.0 green:0.96 blue:0.80 alpha:1.0]
         alignment:CSPixelTextAlignmentCenter zPosition:3];
    [self addLabel:[NSString stringWithFormat:@"WORLD %ld  -  LEVEL %02ld  -  %@",
                    (long)_result.worldID, (long)_result.levelID,
                    _result.levelName.uppercaseString ?: @""]
           atPoint:CGPointMake(320, 313) scale:0.58
             color:[NSColor colorWithSRGBRed:1.0 green:0.91 blue:0.74 alpha:0.88]
         alignment:CSPixelTextAlignmentCenter zPosition:3].shadowEnabled = NO;

    SKSpriteNode *footer = [SKSpriteNode spriteNodeWithColor:
        [NSColor colorWithSRGBRed:0.20 green:0.13 blue:0.26 alpha:0.90] size:CGSizeMake(640, 22)];
    footer.anchorPoint = CGPointZero;
    footer.position = CGPointZero;
    footer.zPosition = 1;
    [self.contentRoot addChild:footer];

    [self addPanelWithTexture:@"ui_panel" size:CGSizeMake(588, 218)
                     position:CGPointMake(320, 178) zPosition:2];

    [self buildScoreColumnWithInk:ink softInk:softInk];
    [self buildStatsColumnWithInk:ink softInk:softInk];
    [self buildButtons];

    [self addLabel:@"ENTER SELECTS  -  ESC RETURNS TO LEVELS"
           atPoint:CGPointMake(320, 10) scale:0.5
             color:[NSColor colorWithSRGBRed:1.0 green:0.90 blue:0.70 alpha:0.78]
         alignment:CSPixelTextAlignmentCenter zPosition:3].shadowEnabled = NO;

    if (_result.completed && !context.save.reducedMotion) {
        [self sprinkleConfetti];
    }
}

- (NSString *)titleText {
    if (!_result.completed) return @"OUT OF LIVES";
    switch (MIN(3, MAX(0, _result.stars))) {
        case 3: return @"PERFECT RUN!";
        case 2: return @"GREAT DRIVING!";
        case 1: return @"LEVEL CLEARED!";
        default: return @"FINISHED!";
    }
}

- (void)buildScoreColumnWithInk:(NSColor *)ink softInk:(NSColor *)softInk {
    [self addLabel:@"SCORE" atPoint:CGPointMake(58, 261) scale:0.58 color:softInk
         alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;
    CSPixelLabelNode *score = [self addLabel:CSResultsFormatNumber(_result.score)
                                     atPoint:CGPointMake(56, 234) scale:1.42 color:ink
                                 alignment:CSPixelTextAlignmentLeft zPosition:4];
    score.shadowEnabled = NO;

    CGFloat starX = 80;
    for (NSInteger i = 0; i < 3; i++) {
        BOOL earned = i < _result.stars;
        NSString *name = earned ? @"icon_star_full" : @"icon_star_empty";
        SKSpriteNode *star = [SKSpriteNode spriteNodeWithTexture:
            [[CSAssetCatalog shared] textureNamed:name fallback:name]];
        star.size = CGSizeMake(38, 38);
        star.position = CGPointMake(starX, 195);
        star.zPosition = 5;
        star.alpha = CSAppContext.shared.save.reducedMotion ? 1.0 : 0.0;
        star.color = earned ? [NSColor colorWithSRGBRed:1.0 green:0.82 blue:0.34 alpha:1.0]
                            : [NSColor colorWithSRGBRed:0.58 green:0.48 blue:0.60 alpha:1.0];
        star.colorBlendFactor = earned ? 0.12 : 0.0;
        [self.contentRoot addChild:star];
        [_starIcons addObject:star];
        starX += 43.0;

        if (earned && !CSAppContext.shared.save.reducedMotion) {
            [star runAction:[SKAction sequence:@[
                [SKAction waitForDuration:0.30 + (NSTimeInterval)i * 0.17],
                [SKAction fadeInWithDuration:0.14],
                [SKAction sequence:@[[SKAction scaleTo:1.30 duration:0.13],
                                     [SKAction scaleTo:1.0 duration:0.12]]],
            ]]];
        }
    }

    _newBestLabel = [self addLabel:@"NEW BEST!" atPoint:CGPointMake(58, 157) scale:0.72
                             color:[NSColor colorWithSRGBRed:0.93 green:0.36 blue:0.55 alpha:1.0]
                         alignment:CSPixelTextAlignmentLeft zPosition:4];
    _newBestLabel.shadowEnabled = NO;
    _newBestLabel.hidden = !_result.newBest;
    if (_result.newBest && !CSAppContext.shared.save.reducedMotion) {
        [_newBestLabel runAction:[SKAction repeatActionForever:[SKAction sequence:@[
            [SKAction scaleTo:1.06 duration:0.55],
            [SKAction scaleTo:1.0 duration:0.55],
        ]]]];
    }

    if (!_result.completed) {
        // Keep the encouragement clear of the car sprite below it.
        [self addLabel:@"SHAKE IT OFF - TRY AGAIN" atPoint:CGPointMake(58, 157) scale:0.52
                 color:[NSColor colorWithSRGBRed:0.60 green:0.38 blue:0.50 alpha:1.0]
             alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;
    }

    CSCar *car = [CSAppContext.shared.catalog carForID:_result.carID ?: @""] ?: [CSAppContext.shared selectedCar];
    if (car) {
        SKSpriteNode *carSprite = [SKSpriteNode spriteNodeWithTexture:
            [[CSAssetCatalog shared] textureNamed:[NSString stringWithFormat:@"%@_0", car.assetPrefix]
                                        fallback:@"car_sunny-bug_0"]];
        carSprite.size = CGSizeMake(34, 56);
        carSprite.position = CGPointMake(220, 118);
        carSprite.zPosition = 4;
        [self.contentRoot addChild:carSprite];
        if (!CSAppContext.shared.save.reducedMotion) {
            [carSprite runAction:[SKAction repeatActionForever:[SKAction sequence:@[
                [SKAction moveByX:0 y:2.0 duration:0.85],
                [SKAction moveByX:0 y:-2.0 duration:0.85],
            ]]]];
        }
        [self addLabel:car.name.uppercaseString atPoint:CGPointMake(220, 80) scale:0.48
                 color:[NSColor colorWithSRGBRed:0.48 green:0.36 blue:0.52 alpha:1.0]
             alignment:CSPixelTextAlignmentCenter zPosition:4].shadowEnabled = NO;
    }

    SKSpriteNode *divider = [SKSpriteNode spriteNodeWithColor:
        [NSColor colorWithSRGBRed:0.80 green:0.69 blue:0.72 alpha:0.45] size:CGSizeMake(2, 188)];
    divider.position = CGPointMake(286, 178);
    divider.zPosition = 3;
    [self.contentRoot addChild:divider];
}

- (void)buildStatsColumnWithInk:(NSColor *)ink softInk:(NSColor *)softInk {
    // recordResult: writes the run before this scene appears, so the saved best
    // already includes a new best. Fall back to the run score for debug scenes
    // that show a result without recording it, keeping "NEW BEST!" coherent.
    NSInteger best = [CSAppContext.shared.save bestScoreForLevel:_result.levelID];
    if (_result.newBest) best = MAX(best, _result.score);
    NSArray<NSArray<NSString *> *> *rows = @[
        @[@"COINS", [NSString stringWithFormat:@"%ld", (long)_result.coins]],
        @[@"BEST COMBO", [NSString stringWithFormat:@"x%ld", (long)_result.bestCombo]],
        @[@"LIVES LEFT", [NSString stringWithFormat:@"%ld", (long)MAX(0, _result.livesLeft)]],
        @[@"DIFFICULTY", _result.difficultyName.length ? _result.difficultyName.uppercaseString : @"CLASSIC"],
        @[@"BEST SCORE", CSResultsFormatNumber(best)],
        @[@"TIME", CSResultsFormatTime(_result.duration)],
    ];

    CGFloat y = 260;
    for (NSArray<NSString *> *row in rows) {
        [self addLabel:row[0] atPoint:CGPointMake(306, y) scale:0.60 color:softInk
             alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;
        [self addLabel:row[1] atPoint:CGPointMake(572, y) scale:0.68 color:ink
             alignment:CSPixelTextAlignmentRight zPosition:4].shadowEnabled = NO;
        y -= 25.0;
    }

    NSString *encouragement = _result.completed
        ? @"STARS UNLOCK NEW CARS IN THE GARAGE"
        : @"TIP: SLOW DOWN BEFORE THE CONES";
    [self addLabel:encouragement atPoint:CGPointMake(306, 98) scale:0.5
             color:[NSColor colorWithSRGBRed:0.52 green:0.40 blue:0.55 alpha:0.9]
         alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;
}

- (void)buildButtons {
    CSLevel *nextLevel = [CSAppContext.shared.catalog levelForID:_nextLevelID];
    BOOL hasNext = _result.completed && _nextLevelID <= 100 && nextLevel != nil &&
                   [CSAppContext.shared isLevelUnlocked:_nextLevelID];

    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    [items addObject:@{@"title": @"RETRY", @"texture": @"ui_button_sky", @"action": @"retry", @"width": @132}];
    if (hasNext) {
        [items addObject:@{@"title": @"NEXT LEVEL", @"texture": @"ui_button_mint", @"action": @"next", @"width": @150}];
    }
    [items addObject:@{@"title": @"LEVELS", @"texture": @"ui_button_lavender", @"action": @"levels", @"width": @132}];
    [items addObject:@{@"title": @"MENU", @"texture": @"ui_button_yellow", @"action": @"menu", @"width": @132}];

    CGFloat totalWidth = 0.0;
    CGFloat gap = 16.0;
    for (NSDictionary *item in items) {
        totalWidth += [item[@"width"] doubleValue];
    }
    totalWidth += gap * (CGFloat)(items.count - 1);

    CGFloat x = (640.0 - totalWidth) * 0.5;
    __weak typeof(self) weakSelf = self;
    CSPixelButtonNode *nextButton = nil;
    for (NSDictionary *item in items) {
        CGFloat width = [item[@"width"] doubleValue];
        CSPixelButtonNode *button = [[CSPixelButtonNode alloc] initWithText:item[@"title"]
                                                               textureName:item[@"texture"]
                                                                      size:CGSizeMake(width, 34)
                                                                 fontScale:0.88];
        button.position = CGPointMake(x + width * 0.5, 42);
        NSString *action = item[@"action"];
        button.actionBlock = ^{ [weakSelf performAction:action]; };
        [self addButton:button];
        if ([action isEqualToString:@"next"]) nextButton = button;
        if ([action isEqualToString:@"retry"] && !nextButton) {
            [self focusButtonAtIndex:(NSInteger)[self.buttons indexOfObject:button]];
        }
        x += width + gap;
    }

    if (nextButton) {
        [self focusButtonAtIndex:(NSInteger)[self.buttons indexOfObject:nextButton]];
    }
}

- (void)performAction:(NSString *)action {
    CSGameViewController *viewController = CSAppContext.shared.viewController;
    if ([action isEqualToString:@"retry"]) {
        [viewController startGameForLevelID:_result.levelID];
    } else if ([action isEqualToString:@"next"]) {
        [viewController presentBriefingForLevelID:_nextLevelID];
    } else if ([action isEqualToString:@"levels"]) {
        [viewController presentLevelSelect];
    } else if ([action isEqualToString:@"menu"]) {
        [viewController presentMenu];
    }
}

- (void)sprinkleConfetti {
    NSArray<NSColor *> *palette = @[
        [NSColor colorWithSRGBRed:1.0 green:0.45 blue:0.61 alpha:1.0],
        [NSColor colorWithSRGBRed:1.0 green:0.82 blue:0.35 alpha:1.0],
        [NSColor colorWithSRGBRed:0.47 green:0.87 blue:0.69 alpha:1.0],
        [NSColor colorWithSRGBRed:0.55 green:0.74 blue:1.0 alpha:1.0],
        [NSColor colorWithSRGBRed:0.78 green:0.61 blue:1.0 alpha:1.0],
    ];
    for (NSInteger i = 0; i < 30; i++) {
        SKSpriteNode *confetti = [SKSpriteNode spriteNodeWithColor:palette[i % palette.count]
                                                              size:CGSizeMake(5, 3)];
        confetti.position = CGPointMake(20.0 + arc4random_uniform(600),
                                        360.0 + arc4random_uniform(90));
        confetti.zPosition = 10;
        confetti.zRotation = (CGFloat)arc4random_uniform(360) * (CGFloat)M_PI / 180.0;
        [self.contentRoot addChild:confetti];
        NSTimeInterval delay = (NSTimeInterval)arc4random_uniform(60) / 100.0;
        NSTimeInterval duration = 1.5 + (NSTimeInterval)arc4random_uniform(80) / 100.0;
        SKAction *fall = [SKAction moveByX:((CGFloat)arc4random_uniform(110) - 55.0)
                                         y:-(380.0 + (CGFloat)arc4random_uniform(180))
                                  duration:duration];
        SKAction *spin = [SKAction rotateByAngle:((CGFloat)arc4random_uniform(10) - 5.0)
                                        duration:duration];
        [confetti runAction:[SKAction sequence:@[
            [SKAction waitForDuration:delay],
            [SKAction group:@[fall, spin]],
            [SKAction removeFromParent],
        ]]];
    }
}

#pragma mark - Input

- (void)gameViewKeyDown:(NSEvent *)event {
    if (event.modifierFlags & NSEventModifierFlagCommand) return;
    NSString *characters = event.charactersIgnoringModifiers.lowercaseString;
    if ([characters isEqualToString:@"r"]) {
        [self performAction:@"retry"];
        return;
    }
    if ([characters isEqualToString:@"n"]) {
        CSLevel *nextLevel = [CSAppContext.shared.catalog levelForID:_nextLevelID];
        if (_result.completed && nextLevel && [CSAppContext.shared isLevelUnlocked:_nextLevelID]) {
            [self performAction:@"next"];
        }
        return;
    }
    [super gameViewKeyDown:event];
}

- (void)goBack {
    [CSAppContext.shared.viewController presentLevelSelect];
}

@end
