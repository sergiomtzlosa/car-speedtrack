#import "CSGameScene.h"
#import "CSGameView.h"
#import "CSAppContext.h"
#import "CSGameCatalog.h"
#import "CSGameSession.h"
#import "CSSaveManager.h"
#import "CSAudioManager.h"
#import "CSGameViewController.h"
#import "CSAssetCatalog.h"
#import "CSPixelLabelNode.h"
#import "CSPixelPanelNode.h"
#import "CSPixelButtonNode.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

typedef NS_ENUM(NSInteger, CSGameSceneState) {
    CSGameSceneStateCountdown = 0,
    CSGameSceneStatePlaying,
    CSGameSceneStatePaused,
    CSGameSceneStateEnding,
};

static const CGFloat CSPlayerScreenY = 96.0;
static const NSInteger CSGroundColumns = 11;
static const NSInteger CSGroundRows = 7;

static CGFloat CSClamp(CGFloat value, CGFloat low, CGFloat high) {
    return MIN(high, MAX(low, value));
}

static uint64_t CSMixHash(uint64_t value) {
    value ^= value >> 33;
    value *= 0xff51afd7ed558ccdULL;
    value ^= value >> 33;
    value *= 0xc4ceb9fe1a85ec53ULL;
    value ^= value >> 33;
    return value;
}

static NSString *CSFormatNumber(NSInteger value) {
    static NSNumberFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSNumberFormatter new];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.maximumFractionDigits = 0;
    });
    return [formatter stringFromNumber:@(value)] ?: [NSString stringWithFormat:@"%ld", (long)value];
}

static CGPoint CSScreenPointForDistance(CGFloat distance, CGFloat playerDistance) {
    return CGPointMake(0.0, CSPlayerScreenY + distance - playerDistance);
}

static CGMutablePathRef CSCreateRoadPolygon(CSRoadPath *road,
                                            CGFloat playerDistance,
                                            CGFloat nearDistance,
                                            CGFloat farDistance,
                                            NSInteger steps,
                                            CGFloat padding) {
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat span = MAX(1.0, farDistance - nearDistance);
    for (NSInteger i = 0; i <= steps; i++) {
        CGFloat distance = nearDistance + span * (CGFloat)i / (CGFloat)steps;
        CGFloat x = [road leftEdgeAtDistance:distance] - padding;
        CGPoint point = CSScreenPointForDistance(distance, playerDistance);
        if (i == 0) {
            CGPathMoveToPoint(path, NULL, x, point.y);
        } else {
            CGPathAddLineToPoint(path, NULL, x, point.y);
        }
    }
    for (NSInteger i = steps; i >= 0; i--) {
        CGFloat distance = nearDistance + span * (CGFloat)i / (CGFloat)steps;
        CGFloat x = [road rightEdgeAtDistance:distance] + padding;
        CGPoint point = CSScreenPointForDistance(distance, playerDistance);
        CGPathAddLineToPoint(path, NULL, x, point.y);
    }
    CGPathCloseSubpath(path);
    return path;
}

static CGMutablePathRef CSCreateRoadEdge(CSRoadPath *road,
                                         CGFloat playerDistance,
                                         CGFloat nearDistance,
                                         CGFloat farDistance,
                                         NSInteger steps,
                                         BOOL leftSide) {
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat span = MAX(1.0, farDistance - nearDistance);
    for (NSInteger i = 0; i <= steps; i++) {
        CGFloat distance = nearDistance + span * (CGFloat)i / (CGFloat)steps;
        CGFloat x = leftSide ? [road leftEdgeAtDistance:distance] : [road rightEdgeAtDistance:distance];
        CGPoint point = CSScreenPointForDistance(distance, playerDistance);
        if (i == 0) {
            CGPathMoveToPoint(path, NULL, x, point.y);
        } else {
            CGPathAddLineToPoint(path, NULL, x, point.y);
        }
    }
    return path;
}

static NSString *CSPickupTextureName(CSPickupKind kind, NSInteger frame) {
    switch (kind) {
        case CSPickupKindCoin:
            return [NSString stringWithFormat:@"pickup_coin_%ld", (long)(frame & 3)];
        case CSPickupKindGem: return @"pickup_gem";
        case CSPickupKindHeart: return @"pickup_heart";
        case CSPickupKindShield: return @"pickup_shield";
        case CSPickupKindMagnet: return @"pickup_magnet";
        case CSPickupKindStar: return @"pickup_star";
    }
    return @"pickup_coin_0";
}

@interface CSGameScene () <CSGameViewInput>
@end

@implementation CSGameScene {
    CSLevel *_level;
    CSWorld *_world;
    CSCar *_car;
    CSDifficultySettings *_difficulty;
    CSGameSession *_session;

    CSGameSceneState _state;
    CSGameSceneState _stateBeforePause;
    CSRunResult *_result;
    CSRunResult *_debugResult;
    BOOL _didPresentResults;

    NSTimeInterval _lastUpdateTime;
    NSTimeInterval _countdownRemaining;
    NSInteger _countdownShown;
    NSTimeInterval _endingTimer;
    NSTimeInterval _elapsedPlay;
    CGFloat _shakeAmount;

    BOOL _keyLeft;
    BOOL _keyRight;
    BOOL _keyThrottle;
    BOOL _keyBrake;
    BOOL _boostRequested;
    BOOL _mouseSteering;
    BOOL _mouseThrottle;
    BOOL _mouseBrake;
    CGFloat _mouseTargetX;

    SKNode *_gameRoot;
    SKNode *_groundRoot;
    SKNode *_decorRoot;
    SKNode *_roadRoot;
    SKNode *_entityRoot;
    SKNode *_fxRoot;
    SKNode *_hudRoot;
    SKNode *_pauseRoot;
    SKNode *_endRoot;

    NSMutableArray<SKSpriteNode *> *_groundTiles;
    NSMutableArray<SKSpriteNode *> *_decorSprites;
    NSMutableArray<SKSpriteNode *> *_laneDashes;
    NSMutableArray<SKSpriteNode *> *_finishSquares;
    NSMutableDictionary<NSNumber *, SKSpriteNode *> *_entitySprites;

    SKShapeNode *_roadShadowShape;
    SKShapeNode *_shoulderShape;
    SKShapeNode *_roadShape;
    SKShapeNode *_leftEdgeShape;
    SKShapeNode *_rightEdgeShape;
    CSPixelLabelNode *_finishLabel;

    SKSpriteNode *_playerSprite;
    SKSpriteNode *_playerShadow;
    NSArray<SKTexture *> *_carFrameTextures;
    NSInteger _playerFrame;
    CGFloat _boostTrailTimer;

    NSColor *_worldAccent;
    NSColor *_roadColor;
    NSColor *_shoulderColor;
    NSColor *_checkerLight;
    NSColor *_checkerDark;

    CSPixelLabelNode *_scoreCaption;
    CSPixelLabelNode *_scoreLabel;
    CSPixelLabelNode *_levelCaption;
    CSPixelLabelNode *_levelNameLabel;
    CSPixelLabelNode *_speedLabel;
    CSPixelLabelNode *_comboLabel;
    CSPixelLabelNode *_turboCaption;
    CSPixelLabelNode *_progressLabel;
    CSPixelLabelNode *_hintLabel;
    CSPixelLabelNode *_countdownLabel;
    CSPixelLabelNode *_countdownSubtitle;
    SKSpriteNode *_boostFill;
    SKSpriteNode *_progressFill;
    SKSpriteNode *_damageFlash;
    NSMutableArray<SKSpriteNode *> *_heartIcons;
    SKSpriteNode *_shieldIcon;
    SKSpriteNode *_magnetIcon;

    CSPixelButtonNode *_hudPauseButton;
    NSMutableArray<CSPixelButtonNode *> *_pauseButtons;
    NSMutableArray<CSPixelButtonNode *> *_endButtons;
    CSPixelButtonNode *_soundButton;
    CSPixelButtonNode *_endContinueButton;
    NSInteger _pauseFocusIndex;
    NSInteger _endFocusIndex;

    CSPixelLabelNode *_pauseSubtitle;
    CSPixelLabelNode *_endTitleLabel;
    CSPixelLabelNode *_endSubtitleLabel;
    CSPixelLabelNode *_endScoreLabel;
    CSPixelLabelNode *_endBestLabel;
    NSMutableArray<SKSpriteNode *> *_endStarIcons;
    BOOL _didCelebrate;

    NSInteger _lastLives;
    NSInteger _lastCombo;
    NSInteger _lastSpeed;
    BOOL _lastTurboReady;
    BOOL _engineStarted;
    BOOL _hintScheduled;
}

#pragma mark - Lifecycle

- (instancetype)initWithLevelID:(NSInteger)levelID {
    self = [super initWithSize:CGSizeMake(640, 360)];
    if (!self) return nil;

    CSAppContext *context = CSAppContext.shared;
    CSLevel *level = [context.catalog levelForID:MAX(1, MIN(100, levelID))];
    if (!level) return nil;

    _level = level;
    _world = [context.catalog worldForID:level.worldID] ?: context.catalog.worlds.firstObject;
    _car = [context selectedCar];
    _difficulty = [context difficultyForNewRun];
    uint64_t seed = ((uint64_t)(CACurrentMediaTime() * 1000.0)) ^ ((uint64_t)arc4random() << 32) ^ arc4random();
    _session = [[CSGameSession alloc] initWithLevel:_level car:_car difficulty:_difficulty runSeed:seed];

    _state = context.skipCountdown ? CSGameSceneStatePlaying : CSGameSceneStateCountdown;
    _stateBeforePause = CSGameSceneStatePlaying;
    _countdownRemaining = 3.0;
    _countdownShown = 3;
    _lastLives = -1;
    _lastCombo = -1;
    _lastSpeed = -1;
    _playerFrame = -1;
    _gameRoot = [SKNode node];
    _groundRoot = [SKNode node];
    _decorRoot = [SKNode node];
    _roadRoot = [SKNode node];
    _entityRoot = [SKNode node];
    _fxRoot = [SKNode node];
    _hudRoot = [SKNode node];
    _pauseRoot = [SKNode node];
    _endRoot = [SKNode node];
    _groundTiles = [NSMutableArray array];
    _decorSprites = [NSMutableArray array];
    _laneDashes = [NSMutableArray array];
    _finishSquares = [NSMutableArray array];
    _entitySprites = [NSMutableDictionary dictionary];
    _pauseButtons = [NSMutableArray array];
    _endButtons = [NSMutableArray array];
    _heartIcons = [NSMutableArray array];
    _endStarIcons = [NSMutableArray array];

    [self buildPalette];
    [self buildScene];
    return self;
}

- (void)didMoveToView:(SKView *)view {
    [super didMoveToView:view];
    CSGameView *gameView = (CSGameView *)view;
    gameView.inputTarget = self;
    if (view.window) [view.window makeFirstResponder:view];

    CSAudioManager *audio = CSAppContext.shared.audio;
    [audio playMusic:_level.music loop:YES];
    if (!_engineStarted) {
        [audio startEngine];
        _engineStarted = YES;
    }
    [audio updateEngineWithSpeedRatio:0.2 offRoad:0 paused:NO];

    if (_state == CSGameSceneStateCountdown) {
        [audio playSFX:@"sfx_countdown"];
    }
    [self showHint];
    [self updateCountdownDisplay];
    [self updateWorldWithDelta:0.0];
    [self updateHUDWithDelta:0.0];
}

- (void)willMoveFromView:(SKView *)view {
    [super willMoveFromView:view];
    CSGameView *gameView = (CSGameView *)view;
    if (gameView.inputTarget == self) gameView.inputTarget = nil;
    [CSAppContext.shared.audio stopEngine];
    [CSAppContext.shared.audio setDucked:NO];
    _engineStarted = NO;
}

#pragma mark - Scene construction

- (void)buildPalette {
    CSAssetCatalog *assets = [CSAssetCatalog shared];
    _worldAccent = [assets colorFromHex:_world.accentHex ?: @"#8EDB78"];
    NSColor *asphalt = [NSColor colorWithSRGBRed:0.27 green:0.21 blue:0.32 alpha:1.0];
    _roadColor = [asphalt blendedColorWithFraction:0.14 ofColor:_worldAccent] ?: asphalt;
    _shoulderColor = [NSColor colorWithSRGBRed:0.98 green:0.88 blue:0.68 alpha:1.0];
    _checkerLight = [NSColor colorWithSRGBRed:1.0 green:0.97 blue:0.86 alpha:1.0];
    _checkerDark = [NSColor colorWithSRGBRed:0.33 green:0.24 blue:0.39 alpha:1.0];
}

- (void)buildScene {
    self.anchorPoint = CGPointZero;
    self.scaleMode = SKSceneScaleModeAspectFit;
    self.backgroundColor = [NSColor colorWithSRGBRed:0.10 green:0.14 blue:0.10 alpha:1.0];

    _gameRoot.zPosition = 0;
    _groundRoot.zPosition = 0;
    _decorRoot.zPosition = 1;
    _roadRoot.zPosition = 3;
    _entityRoot.zPosition = 10;
    _fxRoot.zPosition = 30;
    _hudRoot.zPosition = 100;
    _pauseRoot.zPosition = 300;
    _endRoot.zPosition = 310;
    [_gameRoot addChild:_groundRoot];
    [_gameRoot addChild:_decorRoot];
    [_gameRoot addChild:_roadRoot];
    [_gameRoot addChild:_entityRoot];
    [_gameRoot addChild:_fxRoot];
    [self addChild:_gameRoot];
    [self addChild:_hudRoot];
    [self addChild:_pauseRoot];
    [self addChild:_endRoot];

    [self buildGround];
    [self buildRoad];
    [self buildDecor];
    [self buildPlayer];
    [self buildHUD];
    [self buildPauseOverlay];
    [self buildEndOverlay];

    _pauseRoot.hidden = YES;
    _endRoot.hidden = YES;
    if (_state == CSGameSceneStatePlaying) {
        _countdownLabel.hidden = YES;
        _countdownSubtitle.hidden = YES;
    }
}

- (void)buildGround {
    SKTexture *texture = [[CSAssetCatalog shared] textureNamed:_level.ground ?: @"ground_1" fallback:@"ground_1"];
    for (NSInteger row = 0; row < CSGroundRows; row++) {
        for (NSInteger column = 0; column < CSGroundColumns; column++) {
            SKSpriteNode *tile = [[SKSpriteNode alloc] initWithTexture:texture];
            tile.size = CGSizeMake(64, 64);
            tile.anchorPoint = CGPointZero;
            tile.zPosition = -20;
            tile.position = CGPointMake((CGFloat)column * 64.0 - 32.0,
                                        (CGFloat)row * 64.0 - 64.0);
            [_groundRoot addChild:tile];
            [_groundTiles addObject:tile];
        }
    }
}

- (void)buildRoad {
    _roadShadowShape = [SKShapeNode node];
    _roadShadowShape.zPosition = 0;
    _roadShadowShape.fillColor = [NSColor colorWithSRGBRed:0.16 green:0.11 blue:0.20 alpha:0.34];
    _roadShadowShape.strokeColor = [NSColor clearColor];
    _roadShadowShape.lineWidth = 0;
    _roadShadowShape.antialiased = NO;
    [_roadRoot addChild:_roadShadowShape];

    _shoulderShape = [SKShapeNode node];
    _shoulderShape.zPosition = 1;
    _shoulderShape.fillColor = _shoulderColor;
    _shoulderShape.strokeColor = [NSColor clearColor];
    _shoulderShape.lineWidth = 0;
    _shoulderShape.antialiased = NO;
    [_roadRoot addChild:_shoulderShape];

    _roadShape = [SKShapeNode node];
    _roadShape.zPosition = 2;
    _roadShape.fillColor = _roadColor;
    _roadShape.strokeColor = [NSColor clearColor];
    _roadShape.lineWidth = 0;
    _roadShape.antialiased = NO;
    [_roadRoot addChild:_roadShape];

    _leftEdgeShape = [SKShapeNode node];
    _leftEdgeShape.zPosition = 3;
    _leftEdgeShape.fillColor = [NSColor clearColor];
    _leftEdgeShape.strokeColor = [NSColor colorWithSRGBRed:1.0 green:0.93 blue:0.72 alpha:0.9];
    _leftEdgeShape.lineWidth = 3.0;
    _leftEdgeShape.lineCap = kCGLineCapButt;
    _leftEdgeShape.antialiased = NO;
    [_roadRoot addChild:_leftEdgeShape];

    _rightEdgeShape = [SKShapeNode node];
    _rightEdgeShape.zPosition = 3;
    _rightEdgeShape.fillColor = [NSColor clearColor];
    _rightEdgeShape.strokeColor = _leftEdgeShape.strokeColor;
    _rightEdgeShape.lineWidth = 3.0;
    _rightEdgeShape.lineCap = kCGLineCapButt;
    _rightEdgeShape.antialiased = NO;
    [_roadRoot addChild:_rightEdgeShape];

    for (NSInteger i = 0; i < 14; i++) {
        SKSpriteNode *dash = [SKSpriteNode spriteNodeWithColor:
            [NSColor colorWithSRGBRed:1.0 green:0.93 blue:0.70 alpha:0.82]
                                                        size:CGSizeMake(4, 17)];
        dash.zPosition = 4;
        [_roadRoot addChild:dash];
        [_laneDashes addObject:dash];
    }

    for (NSInteger i = 0; i < 32; i++) {
        SKSpriteNode *square = [SKSpriteNode spriteNodeWithColor:_checkerLight size:CGSizeMake(10, 10)];
        square.zPosition = 5;
        square.colorBlendFactor = 1.0;
        [_roadRoot addChild:square];
        [_finishSquares addObject:square];
    }

    _finishLabel = [[CSPixelLabelNode alloc] initWithText:@"FINISH"
                                                fontScale:0.62
                                                    color:[NSColor colorWithSRGBRed:0.28 green:0.18 blue:0.34 alpha:1.0]];
    _finishLabel.zPosition = 6;
    _finishLabel.shadowEnabled = YES;
    [_roadRoot addChild:_finishLabel];
}

- (void)buildDecor {
    for (NSInteger i = 0; i < 18; i++) {
        SKSpriteNode *sprite = [[SKSpriteNode alloc] initWithTexture:
            [[CSAssetCatalog shared] textureNamed:@"decor_1_0" fallback:@"decor_1_0"]];
        sprite.anchorPoint = CGPointMake(0.5, 0.0);
        sprite.zPosition = 0;
        sprite.hidden = YES;
        [_decorRoot addChild:sprite];
        [_decorSprites addObject:sprite];
    }
}

- (void)buildPlayer {
    NSMutableArray<SKTexture *> *frames = [NSMutableArray array];
    for (NSInteger frame = 0; frame < 4; frame++) {
        NSString *name = [NSString stringWithFormat:@"%@_%ld", _car.assetPrefix, (long)frame];
        SKTexture *texture = [[CSAssetCatalog shared] textureNamed:name fallback:@"car_sunny-bug_0"];
        if (texture) [frames addObject:texture];
    }
    if (frames.count == 0) {
        SKTexture *fallback = [[CSAssetCatalog shared] textureNamed:@"car_sunny-bug_0"];
        if (fallback) [frames addObject:fallback];
    }
    _carFrameTextures = frames;

    _playerShadow = [SKSpriteNode spriteNodeWithColor:[NSColor colorWithSRGBRed:0.13 green:0.08 blue:0.16 alpha:0.28]
                                                 size:CGSizeMake(29, 46)];
    _playerShadow.zPosition = 19;
    _playerShadow.anchorPoint = CGPointMake(0.5, 0.5);
    [_gameRoot addChild:_playerShadow];

    _playerSprite = [[SKSpriteNode alloc] initWithTexture:_carFrameTextures.firstObject];
    _playerSprite.size = CGSizeMake(40, 64);
    _playerSprite.anchorPoint = CGPointMake(0.5, 0.5);
    _playerSprite.zPosition = 20;
    [_gameRoot addChild:_playerSprite];
}

- (CSPixelLabelNode *)addHUILabel:(NSString *)text
                          atPoint:(CGPoint)point
                            scale:(CGFloat)scale
                            color:(NSColor *)color
                        alignment:(CSPixelTextAlignment)alignment
                        zPosition:(CGFloat)z
                           shadow:(BOOL)shadow {
    CSPixelLabelNode *label = [[CSPixelLabelNode alloc] initWithText:text fontScale:scale color:color];
    label.alignment = alignment;
    label.position = point;
    label.zPosition = z;
    label.shadowEnabled = shadow;
    [_hudRoot addChild:label];
    return label;
}

- (void)buildHUD {
    SKSpriteNode *topBar = [SKSpriteNode spriteNodeWithColor:
        [NSColor colorWithSRGBRed:0.15 green:0.10 blue:0.20 alpha:0.90]
                                                       size:CGSizeMake(640, 44)];
    topBar.anchorPoint = CGPointZero;
    topBar.position = CGPointMake(0, 316);
    topBar.zPosition = 1;
    [_hudRoot addChild:topBar];
    SKSpriteNode *topAccent = [SKSpriteNode spriteNodeWithColor:_worldAccent size:CGSizeMake(640, 2)];
    topAccent.anchorPoint = CGPointZero;
    topAccent.position = CGPointMake(0, 316);
    topAccent.zPosition = 2;
    [_hudRoot addChild:topAccent];

    NSColor *cream = [NSColor colorWithSRGBRed:1.0 green:0.97 blue:0.87 alpha:1.0];
    NSColor *softCream = [NSColor colorWithSRGBRed:1.0 green:0.91 blue:0.72 alpha:0.72];

    _scoreCaption = [self addHUILabel:@"SCORE" atPoint:CGPointMake(12, 349) scale:0.5
                                color:softCream alignment:CSPixelTextAlignmentLeft zPosition:3 shadow:NO];
    _scoreLabel = [self addHUILabel:@"0" atPoint:CGPointMake(12, 332) scale:1.02
                              color:cream alignment:CSPixelTextAlignmentLeft zPosition:3 shadow:YES];

    _levelCaption = [self addHUILabel:@"" atPoint:CGPointMake(250, 349) scale:0.5
                                color:softCream alignment:CSPixelTextAlignmentCenter zPosition:3 shadow:NO];
    _levelNameLabel = [self addHUILabel:@"" atPoint:CGPointMake(250, 332) scale:0.64
                                  color:cream alignment:CSPixelTextAlignmentCenter zPosition:3 shadow:YES];
    _levelCaption.text = [NSString stringWithFormat:@"WORLD %ld  -  LEVEL %02ld/100",
                          (long)_level.worldID, (long)_level.levelID];
    _levelNameLabel.text = _level.name.uppercaseString;

    for (NSInteger i = 0; i < 5; i++) {
        SKSpriteNode *heart = [SKSpriteNode spriteNodeWithTexture:
            [[CSAssetCatalog shared] textureNamed:@"icon_heart_full" fallback:@"icon_heart_full"]];
        heart.size = CGSizeMake(16, 16);
        heart.position = CGPointMake(510 + i * 18.0, 338);
        heart.zPosition = 3;
        [_hudRoot addChild:heart];
        [_heartIcons addObject:heart];
    }

    _shieldIcon = [SKSpriteNode spriteNodeWithTexture:
        [[CSAssetCatalog shared] textureNamed:@"icon_shield" fallback:@"icon_shield"]];
    _shieldIcon.size = CGSizeMake(15, 17);
    _shieldIcon.position = CGPointMake(583, 318);
    _shieldIcon.zPosition = 3;
    _shieldIcon.hidden = YES;
    [_hudRoot addChild:_shieldIcon];

    _magnetIcon = [SKSpriteNode spriteNodeWithTexture:
        [[CSAssetCatalog shared] textureNamed:@"icon_magnet" fallback:@"icon_magnet"]];
    _magnetIcon.size = CGSizeMake(15, 15);
    _magnetIcon.position = CGPointMake(601, 318);
    _magnetIcon.zPosition = 3;
    _magnetIcon.hidden = YES;
    [_hudRoot addChild:_magnetIcon];

    _hudPauseButton = [[CSPixelButtonNode alloc] initWithIcon:@"icon_pause"
                                                  textureName:@"ui_button_lavender"
                                                         size:CGSizeMake(31, 27)];
    _hudPauseButton.position = CGPointMake(617, 334);
    _hudPauseButton.zPosition = 5;
    __weak typeof(self) weakSelf = self;
    _hudPauseButton.actionBlock = ^{ [weakSelf togglePause]; };
    [_hudRoot addChild:_hudPauseButton];

    SKSpriteNode *bottomBar = [SKSpriteNode spriteNodeWithColor:
        [NSColor colorWithSRGBRed:0.15 green:0.10 blue:0.20 alpha:0.84]
                                                          size:CGSizeMake(640, 30)];
    bottomBar.anchorPoint = CGPointZero;
    bottomBar.position = CGPointMake(0, 0);
    bottomBar.zPosition = 1;
    [_hudRoot addChild:bottomBar];
    SKSpriteNode *bottomAccent = [SKSpriteNode spriteNodeWithColor:_worldAccent size:CGSizeMake(640, 2)];
    bottomAccent.anchorPoint = CGPointZero;
    bottomAccent.position = CGPointMake(0, 30);
    bottomAccent.zPosition = 2;
    [_hudRoot addChild:bottomAccent];

    _turboCaption = [self addHUILabel:@"TURBO" atPoint:CGPointMake(12, 19) scale:0.5
                                color:softCream alignment:CSPixelTextAlignmentLeft zPosition:3 shadow:NO];
    SKSpriteNode *boostTrack = [SKSpriteNode spriteNodeWithTexture:
        [[CSAssetCatalog shared] textureNamed:@"ui_slider_track" fallback:@"ui_slider_track"]];
    boostTrack.size = CGSizeMake(102, 8);
    boostTrack.position = CGPointMake(66, 10);
    boostTrack.zPosition = 2;
    [_hudRoot addChild:boostTrack];
    _boostFill = [SKSpriteNode spriteNodeWithTexture:
        [[CSAssetCatalog shared] textureNamed:@"ui_bar_pink" fallback:@"ui_bar_pink"]];
    _boostFill.anchorPoint = CGPointMake(0.0, 0.5);
    _boostFill.position = CGPointMake(15, 10);
    _boostFill.size = CGSizeMake(1, 7);
    _boostFill.zPosition = 3;
    [_hudRoot addChild:_boostFill];

    SKSpriteNode *progressTrack = [SKSpriteNode spriteNodeWithTexture:
        [[CSAssetCatalog shared] textureNamed:@"ui_slider_track" fallback:@"ui_slider_track"]];
    progressTrack.size = CGSizeMake(222, 8);
    progressTrack.position = CGPointMake(320, 10);
    progressTrack.zPosition = 2;
    [_hudRoot addChild:progressTrack];
    _progressFill = [SKSpriteNode spriteNodeWithTexture:
        [[CSAssetCatalog shared] textureNamed:@"ui_bar_mint" fallback:@"ui_bar_mint"]];
    _progressFill.anchorPoint = CGPointMake(0.0, 0.5);
    _progressFill.position = CGPointMake(209, 10);
    _progressFill.size = CGSizeMake(1, 7);
    _progressFill.zPosition = 3;
    [_hudRoot addChild:_progressFill];
    _progressLabel = [self addHUILabel:@"0%" atPoint:CGPointMake(320, 20) scale:0.47
                                color:softCream alignment:CSPixelTextAlignmentCenter zPosition:3 shadow:NO];

    _speedLabel = [self addHUILabel:@"0 KM/H" atPoint:CGPointMake(632, 20) scale:0.56
                             color:cream alignment:CSPixelTextAlignmentRight zPosition:3 shadow:YES];

    _comboLabel = [self addHUILabel:@"x1 COMBO" atPoint:CGPointMake(630, 42) scale:0.61
                             color:[NSColor colorWithSRGBRed:1.0 green:0.87 blue:0.35 alpha:1.0]
                         alignment:CSPixelTextAlignmentRight zPosition:4 shadow:YES];
    _comboLabel.hidden = YES;

    _hintLabel = [self addHUILabel:@"A/D OR ARROWS STEER   W THROTTLE   S BRAKE\nSPACE TURBO   MOUSE ALSO STEERS"
                           atPoint:CGPointMake(320, 58) scale:0.6
                             color:[NSColor colorWithSRGBRed:1.0 green:0.96 blue:0.85 alpha:0.98]
                         alignment:CSPixelTextAlignmentCenter zPosition:4 shadow:YES];
    _hintLabel.alpha = 0.0;
    _hintLabel.hidden = YES;

    _countdownSubtitle = [self addHUILabel:@"" atPoint:CGPointMake(320, 238) scale:0.78
                                    color:cream alignment:CSPixelTextAlignmentCenter zPosition:15 shadow:YES];
    _countdownSubtitle.text = [NSString stringWithFormat:@"LEVEL %02ld  -  %@",
                               (long)_level.levelID, _level.name.uppercaseString];
    _countdownLabel = [self addHUILabel:@"3" atPoint:CGPointMake(320, 176) scale:3.8
                                 color:[NSColor colorWithSRGBRed:1.0 green:0.88 blue:0.36 alpha:1.0]
                             alignment:CSPixelTextAlignmentCenter zPosition:16 shadow:YES];

    _damageFlash = [SKSpriteNode spriteNodeWithColor:
        [NSColor colorWithSRGBRed:1.0 green:0.18 blue:0.35 alpha:0.34] size:CGSizeMake(640, 360)];
    _damageFlash.anchorPoint = CGPointZero;
    _damageFlash.position = CGPointZero;
    _damageFlash.zPosition = -1;
    _damageFlash.alpha = 0.0;
    [_hudRoot addChild:_damageFlash];
}

- (void)buildPauseOverlay {
    SKSpriteNode *dim = [SKSpriteNode spriteNodeWithColor:
        [NSColor colorWithSRGBRed:0.06 green:0.04 blue:0.09 alpha:0.66] size:CGSizeMake(640, 360)];
    dim.anchorPoint = CGPointZero;
    dim.position = CGPointZero;
    dim.zPosition = 0;
    [_pauseRoot addChild:dim];

    CSPixelPanelNode *panel = [[CSPixelPanelNode alloc] initWithTextureName:@"ui_panel_dark"
                                                                        size:CGSizeMake(326, 250)];
    panel.position = CGPointMake(320, 180);
    panel.zPosition = 1;
    [_pauseRoot addChild:panel];

    CSPixelLabelNode *title = [[CSPixelLabelNode alloc] initWithText:@"PAUSED" fontScale:1.95
                                                               color:[NSColor colorWithSRGBRed:1.0 green:0.94 blue:0.74 alpha:1.0]];
    title.position = CGPointMake(320, 263);
    title.zPosition = 2;
    title.shadowEnabled = YES;
    [_pauseRoot addChild:title];

    _pauseSubtitle = [[CSPixelLabelNode alloc] initWithText:@"" fontScale:0.61
                                                       color:[NSColor colorWithSRGBRed:1.0 green:0.90 blue:0.70 alpha:0.82]];
    _pauseSubtitle.position = CGPointMake(320, 234);
    _pauseSubtitle.zPosition = 2;
    [_pauseRoot addChild:_pauseSubtitle];
    _pauseSubtitle.text = [NSString stringWithFormat:@"LEVEL %02ld  -  %@",
                           (long)_level.levelID, _level.name.uppercaseString];

    __weak typeof(self) weakSelf = self;
    NSArray<NSDictionary *> *items = @[
        @{@"title": @"RESUME", @"texture": @"ui_button_mint", @"y": @190},
        @{@"title": @"RETRY LEVEL", @"texture": @"ui_button_sky", @"y": @152},
        @{@"title": @"SOUND: ON", @"texture": @"ui_button_yellow", @"y": @114},
        @{@"title": @"LEVEL SELECT", @"texture": @"ui_button_lavender", @"y": @76},
    ];
    for (NSDictionary *item in items) {
        CSPixelButtonNode *button = [[CSPixelButtonNode alloc] initWithText:item[@"title"]
                                                               textureName:item[@"texture"]
                                                                      size:CGSizeMake(208, 32)
                                                                 fontScale:0.78];
        button.position = CGPointMake(320, [item[@"y"] doubleValue]);
        button.zPosition = 2;
        [_pauseRoot addChild:button];
        [_pauseButtons addObject:button];
        NSString *titleText = item[@"title"];
        if ([titleText isEqualToString:@"RESUME"]) {
            button.actionBlock = ^{ [weakSelf resumeGame]; };
        } else if ([titleText isEqualToString:@"RETRY LEVEL"]) {
            button.actionBlock = ^{ [weakSelf retryLevel]; };
        } else if ([titleText isEqualToString:@"SOUND: ON"]) {
            button.actionBlock = ^{ [weakSelf togglePauseMute]; };
            _soundButton = button;
        } else {
            button.actionBlock = ^{ [weakSelf quitToLevels]; };
        }
    }
    _soundButton.text = [CSAppContext.shared.audio isMuted] ? @"SOUND: OFF" : @"SOUND: ON";

    CSPixelLabelNode *hint = [[CSPixelLabelNode alloc] initWithText:
        @"ARROWS + ENTER SELECT   ESC RESUMES   R RETRY   M MUTE"
                                                              fontScale:0.50
                                                                  color:[NSColor colorWithSRGBRed:1.0 green:0.94 blue:0.80 alpha:0.82]];
    hint.position = CGPointMake(320, 43);
    hint.maxWidth = 380;
    hint.zPosition = 2;
    [_pauseRoot addChild:hint];
}

- (void)buildEndOverlay {
    SKSpriteNode *dim = [SKSpriteNode spriteNodeWithColor:
        [NSColor colorWithSRGBRed:0.06 green:0.04 blue:0.09 alpha:0.56] size:CGSizeMake(640, 360)];
    dim.anchorPoint = CGPointZero;
    dim.position = CGPointZero;
    dim.zPosition = 0;
    [_endRoot addChild:dim];

    CSPixelPanelNode *panel = [[CSPixelPanelNode alloc] initWithTextureName:@"ui_panel"
                                                                        size:CGSizeMake(388, 264)];
    panel.position = CGPointMake(320, 180);
    panel.zPosition = 1;
    [_endRoot addChild:panel];

    _endTitleLabel = [[CSPixelLabelNode alloc] initWithText:@"FINISH!" fontScale:2.2
                                                      color:[NSColor colorWithSRGBRed:1.0 green:0.88 blue:0.35 alpha:1.0]];
    _endTitleLabel.position = CGPointMake(320, 272);
    _endTitleLabel.zPosition = 2;
    _endTitleLabel.shadowEnabled = YES;
    [_endRoot addChild:_endTitleLabel];

    _endSubtitleLabel = [[CSPixelLabelNode alloc] initWithText:@"" fontScale:0.60
                                                         color:[NSColor colorWithSRGBRed:0.38 green:0.26 blue:0.43 alpha:1.0]];
    _endSubtitleLabel.position = CGPointMake(320, 244);
    _endSubtitleLabel.zPosition = 2;
    [_endRoot addChild:_endSubtitleLabel];

    _endScoreLabel = [[CSPixelLabelNode alloc] initWithText:@"SCORE 0" fontScale:1.06
                                                      color:[NSColor colorWithSRGBRed:0.24 green:0.15 blue:0.30 alpha:1.0]];
    _endScoreLabel.position = CGPointMake(320, 213);
    _endScoreLabel.zPosition = 2;
    [_endRoot addChild:_endScoreLabel];

    for (NSInteger i = 0; i < 3; i++) {
        SKSpriteNode *star = [SKSpriteNode spriteNodeWithTexture:
            [[CSAssetCatalog shared] textureNamed:@"icon_star_empty" fallback:@"icon_star_empty"]];
        star.size = CGSizeMake(27, 27);
        star.position = CGPointMake(282 + i * 38.0, 185);
        star.zPosition = 2;
        [_endRoot addChild:star];
        [_endStarIcons addObject:star];
    }

    _endBestLabel = [[CSPixelLabelNode alloc] initWithText:@"NEW BEST!" fontScale:0.82
                                                     color:[NSColor colorWithSRGBRed:0.93 green:0.38 blue:0.55 alpha:1.0]];
    _endBestLabel.position = CGPointMake(320, 156);
    _endBestLabel.zPosition = 2;
    _endBestLabel.shadowEnabled = YES;
    _endBestLabel.hidden = YES;
    [_endRoot addChild:_endBestLabel];

    __weak typeof(self) weakSelf = self;
    _endContinueButton = [[CSPixelButtonNode alloc] initWithText:@"CONTINUE"
                                                     textureName:@"ui_button_mint"
                                                            size:CGSizeMake(178, 34)
                                                       fontScale:0.9];
    _endContinueButton.position = CGPointMake(320, 108);
    _endContinueButton.zPosition = 2;
    _endContinueButton.actionBlock = ^{ [weakSelf showResults]; };
    [_endRoot addChild:_endContinueButton];
    [_endButtons addObject:_endContinueButton];

    CSPixelLabelNode *hint = [[CSPixelLabelNode alloc] initWithText:@"PRESS ENTER OR CLICK TO CONTINUE"
                                                              fontScale:0.49
                                                                  color:[NSColor colorWithSRGBRed:0.44 green:0.30 blue:0.48 alpha:0.7]];
    hint.position = CGPointMake(320, 70);
    hint.zPosition = 2;
    [_endRoot addChild:hint];
}

#pragma mark - World rendering

- (void)updateWorldWithDelta:(CGFloat)dt {
    CGFloat playerDistance = _session.playerDistance;
    [self updateGroundForDistance:playerDistance];
    [self updateDecorForDistance:playerDistance];
    [self updateRoadForDistance:playerDistance];
    [self updateFinishLineForDistance:playerDistance];
    [self updateEntities];
    [self updatePlayerWithDelta:dt];

    _shakeAmount = MAX(_shakeAmount, _session.cameraShake);
    _shakeAmount = MAX(0.0, _shakeAmount - dt * 2.6);
    if (_shakeAmount > 0.02 && !CSAppContext.shared.save.reducedMotion) {
        CGFloat magnitude = _shakeAmount * 3.2;
        _gameRoot.position = CGPointMake(sin(_elapsedPlay * 74.0) * magnitude,
                                         cos(_elapsedPlay * 59.0) * magnitude);
    } else {
        _gameRoot.position = CGPointZero;
    }
}

- (void)updateGroundForDistance:(CGFloat)playerDistance {
    CGFloat scroll = fmod(playerDistance * 0.65, 64.0);
    for (NSUInteger i = 0; i < _groundTiles.count; i++) {
        NSInteger row = (NSInteger)i / CSGroundColumns;
        NSInteger column = (NSInteger)i % CSGroundColumns;
        CGFloat y = fmod((CGFloat)row * 64.0 + scroll + 448.0, 448.0) - 64.0;
        SKSpriteNode *tile = _groundTiles[i];
        tile.position = CGPointMake((CGFloat)column * 64.0 - 32.0, y);
    }
}

- (void)updateDecorForDistance:(CGFloat)playerDistance {
    NSInteger slotSize = 96;
    NSInteger firstSlot = (NSInteger)floor((playerDistance - 150.0) / (CGFloat)slotSize);
    NSInteger lastSlot = (NSInteger)floor((playerDistance + 340.0) / (CGFloat)slotSize);
    NSUInteger used = 0;
    CSAssetCatalog *assets = [CSAssetCatalog shared];

    for (NSInteger slot = firstSlot; slot <= lastSlot && used < _decorSprites.count; slot++) {
        for (NSInteger side = 0; side < 2 && used < _decorSprites.count; side++) {
            uint64_t hash = CSMixHash(_level.seed ^ ((uint64_t)(slot + 4096) << 32) ^
                                      ((uint64_t)side * 0x9E3779B97F4A7C15ULL));
            if ((hash & 0x07) == 0) continue;
            CGFloat distance = (CGFloat)slot * (CGFloat)slotSize + (CGFloat)((hash >> 8) % 66);
            if (distance < -20.0 || distance > _level.length + 110.0) continue;
            CGFloat y = CSPlayerScreenY + distance - playerDistance;
            if (y < -90.0 || y > 450.0) continue;

            NSInteger decorIndex = (NSInteger)((hash >> 24) % 3);
            NSString *name = [NSString stringWithFormat:@"decor_%ld_%ld",
                              (long)MIN(10, MAX(1, _level.worldID)), (long)decorIndex];
            SKTexture *texture = [assets textureNamed:name fallback:@"decor_1_0"];
            if (!texture) continue;
            SKSpriteNode *sprite = _decorSprites[used++];
            sprite.texture = texture;
            CGFloat scale = 0.92 + (CGFloat)((hash >> 32) % 34) / 100.0;
            sprite.size = CGSizeMake(texture.size.width * scale, texture.size.height * scale);
            CGFloat left = [_session.roadPath leftEdgeAtDistance:distance];
            CGFloat right = [_session.roadPath rightEdgeAtDistance:distance];
            CGFloat offset = 18.0 + (CGFloat)((hash >> 16) % 55);
            sprite.position = CGPointMake(side == 0 ? left - offset : right + offset, y);
            sprite.zRotation = 0.0;
            sprite.zPosition = 0;
            sprite.hidden = NO;
        }
    }

    for (NSUInteger i = used; i < _decorSprites.count; i++) {
        _decorSprites[i].hidden = YES;
    }
}

- (void)updateRoadForDistance:(CGFloat)playerDistance {
    CGFloat nearDistance = playerDistance - 145.0;
    CGFloat farDistance = playerDistance + 335.0;
    NSInteger steps = 46;

    CGFloat shadowPadding = 15.0;
    CGPathRef shadowPath = CSCreateRoadPolygon(_session.roadPath, playerDistance,
                                               nearDistance, farDistance, steps, shadowPadding);
    _roadShadowShape.path = shadowPath;
    CGPathRelease(shadowPath);

    CGFloat shoulderPadding = 9.0;
    CGPathRef shoulderPath = CSCreateRoadPolygon(_session.roadPath, playerDistance,
                                                 nearDistance, farDistance, steps, shoulderPadding);
    _shoulderShape.path = shoulderPath;
    CGPathRelease(shoulderPath);

    CGPathRef roadPath = CSCreateRoadPolygon(_session.roadPath, playerDistance,
                                             nearDistance, farDistance, steps, 0.0);
    _roadShape.path = roadPath;
    CGPathRelease(roadPath);

    CGPathRef leftPath = CSCreateRoadEdge(_session.roadPath, playerDistance,
                                          nearDistance, farDistance, steps, YES);
    _leftEdgeShape.path = leftPath;
    CGPathRelease(leftPath);

    CGPathRef rightPath = CSCreateRoadEdge(_session.roadPath, playerDistance,
                                           nearDistance, farDistance, steps, NO);
    _rightEdgeShape.path = rightPath;
    CGPathRelease(rightPath);

    NSUInteger dashIndex = 0;
    NSInteger firstDash = (NSInteger)floor((playerDistance - 120.0) / 64.0);
    for (NSInteger lane = 1; lane <= 2; lane++) {
        for (NSInteger k = 0; k < 7 && dashIndex < _laneDashes.count; k++) {
            CGFloat distance = (CGFloat)(firstDash + k) * 64.0 + (lane == 2 ? 32.0 : 0.0);
            SKSpriteNode *dash = _laneDashes[dashIndex++];
            if (distance < 0.0 || distance > _level.length + 4.0) {
                dash.hidden = YES;
                continue;
            }
            CGFloat y = CSPlayerScreenY + distance - playerDistance;
            if (y < -30.0 || y > 390.0) {
                dash.hidden = YES;
                continue;
            }
            CGFloat left = [_session.roadPath leftEdgeAtDistance:distance];
            CGFloat right = [_session.roadPath rightEdgeAtDistance:distance];
            CGFloat width = right - left;
            CGFloat x = left + width * ((CGFloat)lane / 3.0);
            dash.hidden = NO;
            dash.position = CGPointMake(x, y);
            dash.zRotation = atan([_session.roadPath tangentAtDistance:distance]);
        }
    }
    for (; dashIndex < _laneDashes.count; dashIndex++) {
        _laneDashes[dashIndex].hidden = YES;
    }
}

- (void)updateFinishLineForDistance:(CGFloat)playerDistance {
    CGFloat finishY = CSPlayerScreenY + _level.length - playerDistance;
    BOOL visible = finishY > -80.0 && finishY < 440.0;
    CGFloat half = [_session.roadPath halfWidthAtDistance:_level.length];
    CGFloat center = [_session.roadPath centerXAtDistance:_level.length];
    CGFloat width = half * 2.0;
    CGFloat columnWidth = width / 16.0;

    for (NSInteger row = 0; row < 2; row++) {
        for (NSInteger column = 0; column < 16; column++) {
            SKSpriteNode *square = _finishSquares[row * 16 + column];
            if (!visible) {
                square.hidden = YES;
                continue;
            }
            square.hidden = NO;
            square.size = CGSizeMake(columnWidth + 0.6, 9.0);
            square.position = CGPointMake(center - half + (CGFloat)(column + 0.5) * columnWidth,
                                          finishY + (CGFloat)row * 9.0 - 4.5);
            square.color = ((row + column) % 2 == 0) ? _checkerLight : _checkerDark;
        }
    }

    _finishLabel.hidden = !visible;
    _finishLabel.position = CGPointMake(center, finishY + 24.0);
}

- (void)updateEntities {
    NSMutableSet<NSNumber *> *alive = [NSMutableSet set];
    CGFloat playerDistance = _session.playerDistance;
    CSAssetCatalog *assets = [CSAssetCatalog shared];

    for (CSGameEntity *entity in [_session activeEntities]) {
        if (entity.distance < playerDistance - 170.0 || entity.distance > playerDistance + 325.0) continue;
        NSNumber *key = @(entity.entityID);
        [alive addObject:key];
        SKSpriteNode *sprite = _entitySprites[key];
        if (!sprite) {
            sprite = [self makeSpriteForEntity:entity assets:assets];
            if (!sprite) continue;
            _entitySprites[key] = sprite;
            [_entityRoot addChild:sprite];
        }

        CGFloat y = CSPlayerScreenY + entity.distance - playerDistance;
        CGFloat x = entity.x;
        CGFloat tangent = [_session.roadPath tangentAtDistance:entity.distance];
        if (entity.kind == CSEntityKindPickup) {
            y += sin(entity.age * 5.0 + (CGFloat)entity.entityID) * 1.4;
            CGFloat pulse = 1.0 + sin(entity.age * 4.0) * 0.05;
            sprite.position = CGPointMake(x, y);
            sprite.xScale = pulse;
            sprite.yScale = pulse;
            sprite.zRotation = 0.0;
            [self animatePickupSprite:sprite entity:entity];
        } else if (entity.kind == CSEntityKindTraffic) {
            sprite.position = CGPointMake(x, y);
            sprite.zRotation = atan(tangent) + sin(entity.age * 2.3 + (CGFloat)entity.entityID) * 0.012;
        } else {
            sprite.position = CGPointMake(x, y);
            [self animateHazardSprite:sprite entity:entity];
            if (entity.subkind == CSHazardKindBeachball ||
                entity.subkind == CSHazardKindTumbleweed ||
                entity.subkind == CSHazardKindSnowball) {
                sprite.zRotation = entity.age * (entity.subkind == CSHazardKindBeachball ? 2.4 : 1.2);
            } else {
                sprite.zRotation = 0.0;
            }
        }
    }

    NSMutableArray<NSNumber *> *stale = [NSMutableArray array];
    for (NSNumber *key in _entitySprites.allKeys) {
        if (![alive containsObject:key]) [stale addObject:key];
    }
    for (NSNumber *key in stale) {
        [_entitySprites[key] removeFromParent];
        [_entitySprites removeObjectForKey:key];
    }
}

- (nullable SKSpriteNode *)makeSpriteForEntity:(CSGameEntity *)entity assets:(CSAssetCatalog *)assets {
    NSString *textureName = nil;
    SKSpriteNode *sprite = nil;
    if (entity.kind == CSEntityKindTraffic) {
        textureName = [NSString stringWithFormat:@"traffic_%ld", (long)(entity.subkind % 5)];
        sprite = [[SKSpriteNode alloc] initWithTexture:[assets textureNamed:textureName fallback:@"traffic_0"]];
        sprite.size = CGSizeMake(36, 58);
        sprite.zPosition = 11;
        SKSpriteNode *shadow = [SKSpriteNode spriteNodeWithColor:
            [NSColor colorWithSRGBRed:0.12 green:0.08 blue:0.16 alpha:0.2]
                                                            size:CGSizeMake(27, 42)];
        shadow.position = CGPointMake(2, -3);
        shadow.zPosition = -1;
        [sprite addChild:shadow];
        sprite.userData = [NSMutableDictionary dictionaryWithDictionary:@{@"frame": @0}];
    } else if (entity.kind == CSEntityKindHazard) {
        textureName = CSHazardAssetName((CSHazardKind)entity.subkind, 0);
        SKTexture *texture = [assets textureNamed:textureName fallback:@"hazard_cone"];
        sprite = [[SKSpriteNode alloc] initWithTexture:texture];
        if (texture) sprite.size = CGSizeMake(texture.size.width * 1.25, texture.size.height * 1.25);
        sprite.zPosition = 12;
        sprite.userData = [NSMutableDictionary dictionaryWithDictionary:@{@"frame": @(-1)}];
    } else {
        textureName = CSPickupTextureName((CSPickupKind)entity.subkind, 0);
        SKTexture *texture = [assets textureNamed:textureName fallback:@"pickup_coin_0"];
        sprite = [[SKSpriteNode alloc] initWithTexture:texture];
        if (texture) sprite.size = CGSizeMake(texture.size.width * 1.3, texture.size.height * 1.3);
        sprite.zPosition = 13;
        sprite.userData = [NSMutableDictionary dictionaryWithDictionary:@{@"frame": @(-1)}];
    }
    sprite.anchorPoint = CGPointMake(0.5, 0.5);
    return sprite;
}

- (void)animateHazardSprite:(SKSpriteNode *)sprite entity:(CSGameEntity *)entity {
    NSInteger frame = (NSInteger)(entity.age * 7.0) & 1;
    NSMutableDictionary *userData = sprite.userData;
    if (!userData) {
        userData = [NSMutableDictionary dictionary];
        sprite.userData = userData;
    }
    if ([userData[@"frame"] integerValue] == frame) return;
    userData[@"frame"] = @(frame);
    SKTexture *texture = [[CSAssetCatalog shared] textureNamed:
        CSHazardAssetName((CSHazardKind)entity.subkind, frame) fallback:@"hazard_cone"];
    if (texture) sprite.texture = texture;
}

- (void)animatePickupSprite:(SKSpriteNode *)sprite entity:(CSGameEntity *)entity {
    if (entity.subkind != CSPickupKindCoin) return;
    NSInteger frame = (NSInteger)(entity.age * 11.0) & 3;
    NSMutableDictionary *userData = sprite.userData;
    if (!userData) {
        userData = [NSMutableDictionary dictionary];
        sprite.userData = userData;
    }
    if ([userData[@"frame"] integerValue] == frame) return;
    userData[@"frame"] = @(frame);
    SKTexture *texture = [[CSAssetCatalog shared] textureNamed:
        CSPickupTextureName(CSPickupKindCoin, frame) fallback:@"pickup_coin_0"];
    if (texture) sprite.texture = texture;
}

- (void)updatePlayerWithDelta:(CGFloat)dt {
    CGFloat tangent = [_session.roadPath tangentAtDistance:_session.playerDistance];
    CGFloat drift = CSClamp(-_session.lateralVelocity * 0.00055, -0.15, 0.15);
    CGFloat angle = atan(tangent) + drift;
    _playerSprite.position = CGPointMake(_session.playerX, CSPlayerScreenY);
    _playerSprite.zRotation = angle;
    _playerShadow.position = CGPointMake(_session.playerX + 2.0, CSPlayerScreenY - 3.0);
    _playerShadow.zRotation = angle;

    NSInteger frame = MAX(0, MIN((NSInteger)_carFrameTextures.count - 1, _session.steeringFrame));
    if (frame != _playerFrame && _carFrameTextures.count > 0) {
        _playerFrame = frame;
        _playerSprite.texture = _carFrameTextures[frame];
    }
    if (_session.invulnerable) {
        CGFloat blink = sin(_session.elapsed * 22.0) > 0.0 ? 1.0 : 0.42;
        _playerSprite.alpha = blink;
    } else {
        _playerSprite.alpha = 1.0;
    }

    if (_session.boosting && !CSAppContext.shared.save.reducedMotion) {
        _boostTrailTimer += dt;
        if (_boostTrailTimer > 0.035) {
            _boostTrailTimer = 0.0;
            CGFloat offset = ((CGFloat)arc4random_uniform(120) / 100.0 - 0.6) * 13.0;
            CGPoint point = CGPointMake(_session.playerX + offset, CSPlayerScreenY - 34.0);
            NSColor *color = arc4random_uniform(2) == 0
                ? [NSColor colorWithSRGBRed:1.0 green:0.70 blue:0.26 alpha:0.9]
                : [NSColor colorWithSRGBRed:1.0 green:0.92 blue:0.44 alpha:0.9];
            [self spawnSmallParticleAt:point color:color velocity:CGPointMake(offset * 1.6, -90) life:0.34];
        }
    }
}

#pragma mark - Events and feedback

- (void)stepGame:(CGFloat)dt {
    CSInputState input = CSInputStateMake();
    input.steerLeft = _keyLeft;
    input.steerRight = _keyRight;
    input.throttle = _keyThrottle;
    input.brake = _keyBrake || _mouseBrake;
    input.boostPressed = _boostRequested;
    input.mouseActive = _mouseSteering && !(_keyLeft || _keyRight);
    input.mouseX = _mouseTargetX;
    input.mouseThrottle = _mouseThrottle;
    input.mouseBrake = _mouseBrake;
    _boostRequested = NO;

    [_session stepWithInput:input dt:dt];
    _elapsedPlay += dt;
    [self handleSessionEvents];
    if (_session.isFinished) {
        [self finishRun];
    }
}

- (void)handleSessionEvents {
    for (CSSessionEvent *event in [_session drainEvents]) {
        CSAudioManager *audio = CSAppContext.shared.audio;
        switch (event.type) {
            case CSGameEventPickup:
                if ([event.message isEqualToString:@"SHIELD"]) {
                    [audio playSFX:@"sfx_shield"];
                } else if ([event.message isEqualToString:@"MAGNET"]) {
                    [audio playSFX:@"sfx_magnet"];
                } else if (event.points >= 400) {
                    [audio playSFX:@"sfx_star"];
                } else if (event.points >= 100) {
                    [audio playSFX:@"sfx_gem"];
                } else {
                    [audio playSFX:@"sfx_coin"];
                }
                [self spawnBurstAtPoint:event.screenPosition
                                  color:[NSColor colorWithSRGBRed:1.0 green:0.85 blue:0.31 alpha:1.0]
                                  count:7];
                break;
            case CSGameEventHit:
                if (event.points < 0) {
                    [audio playSFX:@"sfx_crash"];
                    _shakeAmount = 1.0;
                    [self flashDamage];
                } else {
                    [audio playSFX:@"sfx_cone"];
                    _shakeAmount = MAX(_shakeAmount, 0.45);
                }
                [self spawnBurstAtPoint:event.screenPosition
                                  color:[NSColor colorWithSRGBRed:1.0 green:0.43 blue:0.39 alpha:1.0]
                                  count:9];
                break;
            case CSGameEventNearMiss:
                [audio playSFX:@"sfx_nearmiss"];
                [self spawnBurstAtPoint:event.screenPosition
                                  color:[NSColor colorWithSRGBRed:0.55 green:0.88 blue:1.0 alpha:1.0]
                                  count:4];
                break;
            case CSGameEventLifeGained:
                [audio playSFX:@"sfx_heart"];
                [self spawnBurstAtPoint:event.screenPosition
                                  color:[NSColor colorWithSRGBRed:1.0 green:0.47 blue:0.58 alpha:1.0]
                                  count:9];
                break;
            case CSGameEventShieldAbsorbed:
                [audio playSFX:@"sfx_shield"];
                [self spawnBurstAtPoint:event.screenPosition
                                  color:[NSColor colorWithSRGBRed:0.56 green:0.86 blue:1.0 alpha:1.0]
                                  count:10];
                break;
            case CSGameEventBoostStart:
                [audio playSFX:@"sfx_boost"];
                break;
            case CSGameEventSlip:
                [audio playSFX:@"sfx_slick"];
                [self spawnBurstAtPoint:event.screenPosition
                                  color:[NSColor colorWithSRGBRed:0.78 green:0.62 blue:0.92 alpha:1.0]
                                  count:6];
                break;
            case CSGameEventFinish:
            case CSGameEventFail:
                break;
        }
        [self showFloatingEvent:event];
    }
}

- (void)showFloatingEvent:(CSSessionEvent *)event {
    if (event.message.length == 0) return;
    if (_fxRoot.children.count > 28) return;
    NSColor *color = [NSColor colorWithSRGBRed:1.0 green:0.97 blue:0.86 alpha:1.0];
    if (event.type == CSGameEventHit) color = [NSColor colorWithSRGBRed:1.0 green:0.48 blue:0.51 alpha:1.0];
    if (event.type == CSGameEventNearMiss || event.type == CSGameEventBoostStart) {
        color = [NSColor colorWithSRGBRed:0.55 green:0.91 blue:1.0 alpha:1.0];
    }
    if (event.type == CSGameEventLifeGained) color = [NSColor colorWithSRGBRed:1.0 green:0.55 blue:0.65 alpha:1.0];
    if (event.type == CSGameEventPickup) color = [NSColor colorWithSRGBRed:1.0 green:0.91 blue:0.45 alpha:1.0];
    if (event.type == CSGameEventShieldAbsorbed) color = [NSColor colorWithSRGBRed:0.62 green:0.91 blue:1.0 alpha:1.0];

    CSPixelLabelNode *label = [[CSPixelLabelNode alloc] initWithText:event.message fontScale:0.72 color:color];
    label.position = CGPointMake(CSClamp(event.screenPosition.x, 64, 576),
                                 CSClamp(event.screenPosition.y, 42, 326));
    label.zPosition = 31;
    label.shadowEnabled = YES;
    [_fxRoot addChild:label];
    if (CSAppContext.shared.save.reducedMotion) {
        [label runAction:[SKAction sequence:@[
            [SKAction waitForDuration:0.55],
            [SKAction fadeOutWithDuration:0.35],
            [SKAction removeFromParent],
        ]]];
    } else {
        [label runAction:[SKAction sequence:@[
            [SKAction group:@[
                [SKAction moveByX:0 y:28 duration:0.9],
                [SKAction sequence:@[[SKAction waitForDuration:0.5],
                                     [SKAction fadeOutWithDuration:0.4]]],
            ]],
            [SKAction removeFromParent],
        ]]];
    }
}

- (void)spawnBurstAtPoint:(CGPoint)point color:(NSColor *)color count:(NSInteger)count {
    if (CSAppContext.shared.save.reducedMotion) return;
    for (NSInteger i = 0; i < count; i++) {
        CGFloat angle = ((CGFloat)arc4random_uniform(360) / 180.0) * (CGFloat)M_PI;
        CGFloat speed = 35.0 + (CGFloat)arc4random_uniform(50);
        CGPoint velocity = CGPointMake(cos(angle) * speed, sin(angle) * speed);
        [self spawnSmallParticleAt:point color:color velocity:velocity life:0.42];
    }
}

- (void)spawnSmallParticleAt:(CGPoint)point color:(NSColor *)color velocity:(CGPoint)velocity life:(CGFloat)life {
    CGFloat size = 2.0 + (CGFloat)arc4random_uniform(3);
    SKSpriteNode *particle = [SKSpriteNode spriteNodeWithColor:color size:CGSizeMake(size, size)];
    particle.position = point;
    particle.zPosition = 32;
    [_fxRoot addChild:particle];
    SKAction *move = [SKAction moveByX:velocity.x * life y:velocity.y * life duration:life];
    move.timingMode = SKActionTimingEaseOut;
    [particle runAction:[SKAction sequence:@[
        [SKAction group:@[move, [SKAction fadeOutWithDuration:life]]],
        [SKAction removeFromParent],
    ]]];
}

- (void)flashDamage {
    [_damageFlash removeAllActions];
    _damageFlash.alpha = 1.0;
    [_damageFlash runAction:[SKAction sequence:@[
        [SKAction fadeOutWithDuration:0.32],
    ]]];
}

- (void)celebrate {
    if (_didCelebrate || CSAppContext.shared.save.reducedMotion) return;
    _didCelebrate = YES;
    NSArray<NSColor *> *palette = @[
        [NSColor colorWithSRGBRed:1.0 green:0.45 blue:0.61 alpha:1.0],
        [NSColor colorWithSRGBRed:1.0 green:0.82 blue:0.35 alpha:1.0],
        [NSColor colorWithSRGBRed:0.47 green:0.87 blue:0.69 alpha:1.0],
        [NSColor colorWithSRGBRed:0.55 green:0.74 blue:1.0 alpha:1.0],
        [NSColor colorWithSRGBRed:0.78 green:0.61 blue:1.0 alpha:1.0],
    ];
    for (NSInteger i = 0; i < 34; i++) {
        SKSpriteNode *confetti = [SKSpriteNode spriteNodeWithColor:palette[i % palette.count]
                                                              size:CGSizeMake(5, 3)];
        confetti.position = CGPointMake(40 + (CGFloat)arc4random_uniform(560),
                                        360 + (CGFloat)arc4random_uniform(110));
        confetti.zPosition = 33;
        confetti.zRotation = (CGFloat)arc4random_uniform(360) * (CGFloat)M_PI / 180.0;
        [_fxRoot addChild:confetti];
        NSTimeInterval delay = (NSTimeInterval)arc4random_uniform(70) / 100.0;
        NSTimeInterval duration = 1.2 + (NSTimeInterval)arc4random_uniform(70) / 100.0;
        SKAction *fall = [SKAction moveByX:((CGFloat)arc4random_uniform(80) - 40.0)
                                         y:-(260.0 + (CGFloat)arc4random_uniform(220))
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

#pragma mark - Countdown and run flow

- (void)updateCountdown:(CGFloat)dt {
    _countdownRemaining -= dt;
    if (_countdownRemaining <= 0.0) {
        [self beginRace];
        return;
    }
    NSInteger next = (NSInteger)ceil(_countdownRemaining);
    if (next != _countdownShown) {
        _countdownShown = next;
        [self showCountdownNumber:next];
        [CSAppContext.shared.audio playSFX:@"sfx_countdown"];
    }
}

- (void)updateCountdownDisplay {
    if (_state != CSGameSceneStateCountdown) return;
    [self showCountdownNumber:_countdownShown];
}

- (void)showCountdownNumber:(NSInteger)number {
    if (number <= 0) return;
    _countdownLabel.hidden = NO;
    _countdownLabel.text = [NSString stringWithFormat:@"%ld", (long)number];
    _countdownLabel.textColor = [NSColor colorWithSRGBRed:1.0 green:0.88 blue:0.36 alpha:1.0];
    _countdownLabel.alpha = 1.0;
    if (CSAppContext.shared.save.reducedMotion) return;
    _countdownLabel.xScale = 1.35;
    _countdownLabel.yScale = 1.35;
    [_countdownLabel runAction:[SKAction scaleTo:1.0 duration:0.18]];
}

- (void)beginRace {
    if (_state != CSGameSceneStateCountdown) return;
    _state = CSGameSceneStatePlaying;
    _countdownRemaining = 0.0;
    CSAudioManager *audio = CSAppContext.shared.audio;
    [audio playSFX:@"sfx_go"];
    if (!_engineStarted) {
        [audio startEngine];
        _engineStarted = YES;
    }
    _countdownLabel.hidden = NO;
    _countdownLabel.text = @"GO!";
    _countdownLabel.textColor = [NSColor colorWithSRGBRed:0.62 green:0.96 blue:0.57 alpha:1.0];
    _countdownLabel.alpha = 1.0;
    [_countdownLabel removeAllActions];
    if (CSAppContext.shared.save.reducedMotion) {
        _countdownLabel.hidden = YES;
        _countdownSubtitle.hidden = YES;
    } else {
        [_countdownLabel runAction:[SKAction sequence:@[
            [SKAction waitForDuration:0.38],
            [SKAction group:@[[SKAction scaleTo:1.8 duration:0.35],
                              [SKAction fadeOutWithDuration:0.35]]],
            [SKAction hide],
        ]]];
        [_countdownSubtitle runAction:[SKAction sequence:@[
            [SKAction fadeOutWithDuration:0.28],
            [SKAction hide],
        ]]];
    }
}

- (void)finishRun {
    if (_result || _session == nil) return;
    _state = CSGameSceneStateEnding;
    _endingTimer = 3.1;
    _hintLabel.hidden = YES;
    _result = [CSAppContext.shared.save recordResult:_debugResult ?: [_session makeResult]];
    _debugResult = nil;

    CSAudioManager *audio = CSAppContext.shared.audio;
    [audio stopEngine];
    _engineStarted = NO;
    [audio setDucked:YES];
    if (_result.completed) {
        [audio playSFX:@"sfx_finish"];
        [self celebrate];
    } else {
        [audio playSFX:@"sfx_crash"];
        [self flashDamage];
    }

    [self configureEndOverlay];
    _endRoot.hidden = NO;
    [self focusEndButtonAtIndex:0];
}

- (void)configureEndOverlay {
    BOOL completed = _result.completed;
    _endTitleLabel.text = completed ? @"FINISH!" : @"OUT OF LIVES";
    _endTitleLabel.textColor = completed
        ? [NSColor colorWithSRGBRed:1.0 green:0.88 blue:0.35 alpha:1.0]
        : [NSColor colorWithSRGBRed:0.98 green:0.45 blue:0.56 alpha:1.0];
    _endSubtitleLabel.text = [NSString stringWithFormat:@"LEVEL %02ld  -  %@",
                              (long)_level.levelID, _level.name.uppercaseString];
    _endScoreLabel.text = [NSString stringWithFormat:@"SCORE %@", CSFormatNumber(_result.score)];
    _endBestLabel.hidden = !_result.newBest;
    _endContinueButton.text = completed ? @"CONTINUE" : @"SEE RESULTS";

    NSInteger earned = MIN(3, MAX(0, _result.stars));
    for (NSInteger i = 0; i < (NSInteger)_endStarIcons.count; i++) {
        SKSpriteNode *star = _endStarIcons[i];
        star.texture = [[CSAssetCatalog shared] textureNamed:
            (i < earned ? @"icon_star_full" : @"icon_star_empty") fallback:@"icon_star_empty"];
        star.size = CGSizeMake(27, 27);
        star.alpha = 0.0;
        [star removeAllActions];
        if (CSAppContext.shared.save.reducedMotion) {
            star.alpha = 1.0;
        } else {
            [star runAction:[SKAction sequence:@[
                [SKAction waitForDuration:0.25 + (NSTimeInterval)i * 0.16],
                [SKAction group:@[[SKAction fadeInWithDuration:0.15],
                                  [SKAction sequence:@[[SKAction scaleTo:1.3 duration:0.12],
                                                       [SKAction scaleTo:1.0 duration:0.12]]]]],
            ]]];
        }
    }
}

- (void)showResults {
    if (_didPresentResults || !_result) return;
    _didPresentResults = YES;
    _endRoot.hidden = YES;
    [CSAppContext.shared.audio stopEngine];
    _engineStarted = NO;
    [CSAppContext.shared.audio setDucked:NO];
    [CSAppContext.shared.viewController presentResults:_result];
}

- (void)retryLevel {
    [CSAppContext.shared.audio stopEngine];
    _engineStarted = NO;
    [CSAppContext.shared.viewController startGameForLevelID:_level.levelID];
}

- (void)debugFinishRunCompleted:(BOOL)completed {
    if (_result || _session == nil) return;
    CSRunResult *result = [_session makeResult];
    result.completed = completed;
    result.levelID = _level.levelID;
    result.worldID = _world.worldID;
    result.levelName = _level.name;
    result.carID = _car.carID;
    result.difficultyName = [_difficulty displayName];
    result.duration = 73.0;
    if (completed) {
        result.score = MAX(result.score, _level.star2 + 420);
        result.stars = 3;
        result.coins = MAX(result.coins, 48);
        result.bestCombo = MAX(result.bestCombo, 9);
        result.livesLeft = MAX(result.livesLeft, 2);
        result.newBest = YES;
    } else {
        result.score = MAX(result.score, 1840);
        result.stars = 0;
        result.coins = MAX(result.coins, 19);
        result.bestCombo = MAX(result.bestCombo, 4);
        result.livesLeft = 0;
    }
    _debugResult = result;
    [self finishRun];
}

- (void)quitToLevels {
    [CSAppContext.shared.audio stopEngine];
    _engineStarted = NO;
    [CSAppContext.shared.viewController presentLevelSelect];
}

#pragma mark - HUD

- (void)updateHUDWithDelta:(CGFloat)dt {
    NSString *score = CSFormatNumber(_session.score);
    _scoreLabel.text = score;
    _levelCaption.text = [NSString stringWithFormat:@"WORLD %ld  -  LEVEL %02ld/100",
                          (long)_level.worldID, (long)_level.levelID];
    _levelNameLabel.text = _level.name.uppercaseString;

    if (_lastLives != _session.lives) {
        _lastLives = _session.lives;
        for (NSInteger i = 0; i < (NSInteger)_heartIcons.count; i++) {
            NSString *name = i < _session.lives ? @"icon_heart_full" : @"icon_heart_empty";
            _heartIcons[i].texture = [[CSAssetCatalog shared] textureNamed:name fallback:name];
            _heartIcons[i].alpha = i < _session.lives ? 1.0 : 0.52;
        }
    }

    BOOL shield = _session.shieldActive;
    BOOL magnet = _session.magnetActive;
    _shieldIcon.hidden = !shield;
    _magnetIcon.hidden = !magnet;
    if (shield) {
        _shieldIcon.alpha = CSAppContext.shared.save.reducedMotion ? 1.0 : 0.7 + 0.3 * (sin(_elapsedPlay * 5.0) * 0.5 + 0.5);
    }
    if (magnet) {
        _magnetIcon.alpha = CSAppContext.shared.save.reducedMotion ? 1.0 : 0.7 + 0.3 * (sin(_elapsedPlay * 6.5 + 1.0) * 0.5 + 0.5);
    }

    CGFloat boost = CSClamp(_session.boostMeter, 0.0, 1.0);
    _boostFill.size = CGSizeMake(MAX(1.0, 101.0 * boost), 7.0);
    BOOL turboReady = boost >= 0.995;
    if (turboReady != _lastTurboReady) {
        _lastTurboReady = turboReady;
        _turboCaption.text = turboReady ? @"TURBO!" : @"TURBO";
        _turboCaption.textColor = turboReady
            ? [NSColor colorWithSRGBRed:1.0 green:0.89 blue:0.38 alpha:1.0]
            : [NSColor colorWithSRGBRed:1.0 green:0.91 blue:0.72 alpha:0.72];
    }
    _boostFill.color = turboReady
        ? [NSColor colorWithSRGBRed:1.0 green:0.89 blue:0.39 alpha:1.0]
        : [NSColor colorWithSRGBRed:0.94 green:0.55 blue:0.68 alpha:1.0];
    _boostFill.colorBlendFactor = 0.55;

    CGFloat progress = CSClamp(_session.progress, 0.0, 1.0);
    _progressFill.size = CGSizeMake(MAX(1.0, 220.0 * progress), 7.0);
    _progressLabel.text = [NSString stringWithFormat:@"%ld%%", (long)round(progress * 100.0)];

    NSInteger speed = (NSInteger)round(_session.speed * 0.82);
    if (speed != _lastSpeed) {
        _lastSpeed = speed;
        _speedLabel.text = [NSString stringWithFormat:@"%ld KM/H", (long)speed];
    }

    NSInteger combo = _session.combo;
    BOOL comboVisible = combo > 0;
    _comboLabel.hidden = !comboVisible;
    if (comboVisible) {
        NSString *comboText = [NSString stringWithFormat:@"x%ld COMBO", (long)_session.multiplier];
        if (![_comboLabel.text isEqualToString:comboText]) {
            _comboLabel.text = comboText;
            if (!CSAppContext.shared.save.reducedMotion) {
                _comboLabel.xScale = 1.22;
                _comboLabel.yScale = 1.22;
                [_comboLabel runAction:[SKAction scaleTo:1.0 duration:0.18]];
            }
        }
        _comboLabel.textColor = _session.multiplier >= 4
            ? [NSColor colorWithSRGBRed:1.0 green:0.63 blue:0.36 alpha:1.0]
            : [NSColor colorWithSRGBRed:1.0 green:0.87 blue:0.35 alpha:1.0];
    }
    if (combo == 0) _lastCombo = -1;

    if (turboReady && !CSAppContext.shared.save.reducedMotion) {
        _turboCaption.alpha = 0.7 + 0.3 * (sin(_elapsedPlay * 8.0) * 0.5 + 0.5);
    } else {
        _turboCaption.alpha = 1.0;
    }
    (void)dt;
}

- (void)showHint {
    if (_hintScheduled) return;
    _hintScheduled = YES;
    _hintLabel.hidden = NO;
    _hintLabel.alpha = 0.98;
    [_hintLabel removeAllActions];
    [_hintLabel runAction:[SKAction sequence:@[
        [SKAction waitForDuration:7.0],
        [SKAction fadeOutWithDuration:0.8],
    ]]];
}

- (void)updateEngineAudio {
    if (!_engineStarted) return;
    CGFloat offRoad = [_session.roadPath offRoadAmountForX:_session.playerX distance:_session.playerDistance];
    [CSAppContext.shared.audio updateEngineWithSpeedRatio:_session.speedRatio
                                                   offRoad:offRoad
                                                    paused:(_state != CSGameSceneStatePlaying &&
                                                            _state != CSGameSceneStateCountdown)];
}

#pragma mark - Pause

- (void)togglePause {
    if (_state == CSGameSceneStatePaused) {
        [self resumeGame];
    } else if (_state == CSGameSceneStatePlaying || _state == CSGameSceneStateCountdown) {
        [self pauseGame];
    }
}

- (void)pauseGame {
    if (_state == CSGameSceneStatePaused || _state == CSGameSceneStateEnding) return;
    _stateBeforePause = _state;
    _state = CSGameSceneStatePaused;
    _keyLeft = _keyRight = _keyThrottle = _keyBrake = NO;
    _boostRequested = NO;
    _mouseThrottle = NO;
    _mouseBrake = NO;
    // The control hint sits in the same strip as the pause help text. Hide it
    // so the two lines cannot draw on top of each other.
    _hintLabel.hidden = YES;
    _pauseRoot.hidden = NO;
    _soundButton.text = [CSAppContext.shared.audio isMuted] ? @"SOUND: OFF" : @"SOUND: ON";
    [self focusPauseButtonAtIndex:0];
    [CSAppContext.shared.audio setDucked:YES];
    [CSAppContext.shared.audio stopEngine];
    _engineStarted = NO;
}

- (void)resumeGame {
    if (_state != CSGameSceneStatePaused) return;
    _state = _stateBeforePause;
    _pauseRoot.hidden = YES;
    _hintLabel.hidden = _hintLabel.alpha <= 0.01;
    [CSAppContext.shared.audio setDucked:NO];
    if (!_engineStarted) {
        [CSAppContext.shared.audio startEngine];
        _engineStarted = YES;
    }
    _lastUpdateTime = 0.0;
}

- (void)togglePauseMute {
    [CSAppContext.shared.audio toggleMuted];
    _soundButton.text = [CSAppContext.shared.audio isMuted] ? @"SOUND: OFF" : @"SOUND: ON";
    [CSAppContext.shared.audio playSFX:@"sfx_click"];
}

- (void)focusPauseButtonAtIndex:(NSInteger)index {
    if (_pauseButtons.count == 0) return;
    NSInteger count = (NSInteger)_pauseButtons.count;
    NSInteger clamped = ((index % count) + count) % count;
    for (NSInteger i = 0; i < count; i++) {
        _pauseButtons[i].focused = (i == clamped);
    }
    _pauseFocusIndex = clamped;
}

- (void)focusEndButtonAtIndex:(NSInteger)index {
    if (_endButtons.count == 0) return;
    NSInteger count = (NSInteger)_endButtons.count;
    NSInteger clamped = ((index % count) + count) % count;
    for (NSInteger i = 0; i < count; i++) {
        _endButtons[i].focused = (i == clamped);
    }
    _endFocusIndex = clamped;
}

- (void)updatePauseHoverAtPoint:(CGPoint)point {
    for (NSUInteger i = 0; i < _pauseButtons.count; i++) {
        if ([_pauseButtons[i] containsScenePoint:point]) {
            if (_pauseFocusIndex != (NSInteger)i) {
                [self focusPauseButtonAtIndex:(NSInteger)i];
                [CSAppContext.shared.audio playSFX:@"sfx_hover"];
            }
            return;
        }
    }
}

- (void)updateEndHoverAtPoint:(CGPoint)point {
    for (NSUInteger i = 0; i < _endButtons.count; i++) {
        if ([_endButtons[i] containsScenePoint:point]) {
            if (_endFocusIndex != (NSInteger)i) {
                [self focusEndButtonAtIndex:(NSInteger)i];
                [CSAppContext.shared.audio playSFX:@"sfx_hover"];
            }
            return;
        }
    }
}

#pragma mark - Input

- (void)gameViewKeyDown:(NSEvent *)event {
    if (event.modifierFlags & NSEventModifierFlagCommand) return;
    unsigned short code = event.keyCode;
    NSString *characters = event.charactersIgnoringModifiers.lowercaseString;
    BOOL enter = (code == 36 || code == 76 || code == 49);
    BOOL up = (code == 126);
    BOOL down = (code == 125);
    BOOL left = (code == 123);
    BOOL right = (code == 124);
    BOOL escape = (code == 53);

    if (_state == CSGameSceneStatePaused) {
        if (escape) {
            [self resumeGame];
            return;
        }
        if (up) {
            [self focusPauseButtonAtIndex:_pauseFocusIndex - 1];
            [CSAppContext.shared.audio playSFX:@"sfx_hover"];
            return;
        }
        if (down || (code == 48)) {
            [self focusPauseButtonAtIndex:_pauseFocusIndex + 1];
            [CSAppContext.shared.audio playSFX:@"sfx_hover"];
            return;
        }
        if (enter) {
            if (_pauseFocusIndex >= 0 && _pauseFocusIndex < (NSInteger)_pauseButtons.count) {
                [_pauseButtons[_pauseFocusIndex] activate];
            }
            return;
        }
        if ([characters isEqualToString:@"r"]) {
            [self retryLevel];
            return;
        }
        if ([characters isEqualToString:@"q"]) {
            [self quitToLevels];
            return;
        }
        if ([characters isEqualToString:@"m"]) {
            [self togglePauseMute];
            return;
        }
        return;
    }

    if (_state == CSGameSceneStateEnding) {
        if (enter || escape) {
            [self showResults];
        } else if ([characters isEqualToString:@"r"]) {
            [self retryLevel];
        } else if ([characters isEqualToString:@"m"]) {
            [CSAppContext.shared.audio toggleMuted];
        }
        return;
    }

    if (escape || [characters isEqualToString:@"p"]) {
        [self togglePause];
        return;
    }
    if ([characters isEqualToString:@"m"]) {
        [CSAppContext.shared.audio toggleMuted];
        return;
    }

    if (left || [characters isEqualToString:@"a"]) {
        _keyLeft = YES;
        _mouseSteering = NO;
    } else if (right || [characters isEqualToString:@"d"]) {
        _keyRight = YES;
        _mouseSteering = NO;
    }
    if (up || [characters isEqualToString:@"w"]) _keyThrottle = YES;
    if (down || [characters isEqualToString:@"s"]) _keyBrake = YES;
    if (code == 49 && !event.isARepeat) {
        _boostRequested = YES;
    }
    if (code == 48) {
        _boostRequested = YES;
    }
}

- (void)gameViewKeyUp:(NSEvent *)event {
    unsigned short code = event.keyCode;
    NSString *characters = event.charactersIgnoringModifiers.lowercaseString;
    if (code == 123 || [characters isEqualToString:@"a"]) _keyLeft = NO;
    if (code == 124 || [characters isEqualToString:@"d"]) _keyRight = NO;
    if (code == 126 || [characters isEqualToString:@"w"]) _keyThrottle = NO;
    if (code == 125 || [characters isEqualToString:@"s"]) _keyBrake = NO;
}

- (void)gameViewMouseMovedToPoint:(CGPoint)point {
    if (_state == CSGameSceneStatePaused) {
        [self updatePauseHoverAtPoint:point];
        return;
    }
    if (_state == CSGameSceneStateEnding) {
        [self updateEndHoverAtPoint:point];
        return;
    }
    if (point.y > 31.0 && point.y < 313.0) {
        _mouseSteering = YES;
        _mouseTargetX = CSClamp(point.x, 12.0, 628.0);
    }
}

- (void)gameViewMouseDownAtPoint:(CGPoint)point button:(NSInteger)button {
    if (_state == CSGameSceneStatePaused) {
        if (button != 0) return;
        for (NSUInteger i = 0; i < _pauseButtons.count; i++) {
            if ([_pauseButtons[i] containsScenePoint:point]) {
                [self focusPauseButtonAtIndex:(NSInteger)i];
                [CSAppContext.shared.audio playSFX:@"sfx_click"];
                [_pauseButtons[i] activate];
                return;
            }
        }
        return;
    }
    if (_state == CSGameSceneStateEnding) {
        if (button != 0) return;
        for (NSUInteger i = 0; i < _endButtons.count; i++) {
            if ([_endButtons[i] containsScenePoint:point]) {
                [self focusEndButtonAtIndex:(NSInteger)i];
                [CSAppContext.shared.audio playSFX:@"sfx_click"];
                [_endButtons[i] activate];
                return;
            }
        }
        return;
    }
    if (button == 0 && [_hudPauseButton containsScenePoint:point]) {
        [CSAppContext.shared.audio playSFX:@"sfx_click"];
        [_hudPauseButton activate];
        return;
    }
    if (button == 0) {
        _mouseThrottle = YES;
    } else if (button == 1) {
        _mouseBrake = YES;
    }
    if (point.y > 31.0 && point.y < 313.0) {
        _mouseSteering = YES;
        _mouseTargetX = CSClamp(point.x, 12.0, 628.0);
    }
}

- (void)gameViewMouseDraggedToPoint:(CGPoint)point button:(NSInteger)button {
    if (_state == CSGameSceneStatePaused || _state == CSGameSceneStateEnding) return;
    if (button == 0 || button == 1) {
        if (point.y > 31.0 && point.y < 313.0) {
            _mouseSteering = YES;
            _mouseTargetX = CSClamp(point.x, 12.0, 628.0);
        }
    }
}

- (void)gameViewMouseUpAtPoint:(CGPoint)point button:(NSInteger)button {
    if (button == 0) _mouseThrottle = NO;
    if (button == 1) _mouseBrake = NO;
}

- (void)gameViewScrollWheel:(CGFloat)delta {
    (void)delta;
}

- (void)gameViewFocusLost {
    if (_state == CSGameSceneStatePlaying || _state == CSGameSceneStateCountdown) {
        [self pauseGame];
    }
}

#pragma mark - Frame update

- (void)update:(NSTimeInterval)currentTime {
    if (_lastUpdateTime <= 0.0) _lastUpdateTime = currentTime;
    CGFloat dt = (CGFloat)(currentTime - _lastUpdateTime);
    _lastUpdateTime = currentTime;
    dt = CSClamp(dt, 0.0, 0.05);

    if (_state == CSGameSceneStatePaused) return;

    if (_state == CSGameSceneStateCountdown) {
        [self updateCountdown:dt];
    } else if (_state == CSGameSceneStatePlaying) {
        [self stepGame:dt];
    } else if (_state == CSGameSceneStateEnding) {
        _endingTimer -= dt;
        if (_endingTimer <= 0.0) {
            [self showResults];
            return;
        }
    }

    [self updateWorldWithDelta:dt];
    [self updateHUDWithDelta:dt];
    [self updateEngineAudio];
}

@end
