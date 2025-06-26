#import "CSBriefingScene.h"
#import "CSAppContext.h"
#import "CSGameCatalog.h"
#import "CSSaveManager.h"
#import "CSAssetCatalog.h"
#import "CSGameViewController.h"
#import "CSAudioManager.h"

static NSString *CSBriefingTextForMechanic(NSString *mechanic) {
    if ([mechanic isEqualToString:@"slick"]) return @"Jelly slicks make the wheel go light.\nEase off and keep a happy line.";
    if ([mechanic isEqualToString:@"crosswind"]) return @"Gusts push you sideways. Steer into\nthe wind and enjoy the view.";
    if ([mechanic isEqualToString:@"traffic"]) return @"Busy lanes and hurried taxis.\nNear misses boost your combo!";
    if ([mechanic isEqualToString:@"waves"]) return @"Rolling waves nudge the car around.\nStay loose and ride them out.";
    if ([mechanic isEqualToString:@"lowgrip"]) return @"Moon dust means floaty drifts.\nStart turning nice and early.";
    if ([mechanic isEqualToString:@"ice"]) return @"The road is slippery. Plan corners\nbefore you reach them.";
    if ([mechanic isEqualToString:@"bounce"]) return @"Bouncy hazards knock you off course.\nGive them plenty of room.";
    if ([mechanic isEqualToString:@"aurora"]) return @"Every trick, all at once, under\nthe dancing lights. You've got this.";
    return @"Steer through friendly cones, scoop up\ncoins, and cross the finish line.";
}

@implementation CSBriefingScene {
    NSInteger _levelID;
    CSDifficultySettings *_settings;
    CSPixelLabelNode *_difficultyLabel;
    NSArray<NSString *> *_difficultyKeys;
}

- (instancetype)initWithLevelID:(NSInteger)levelID {
    self = [super initWithSize:CGSizeMake(640, 360)];
    if (self) {
        _levelID = levelID;
        _settings = [[CSAppContext.shared difficultyForNewRun] copy];
        _difficultyKeys = @[@"chill", @"classic", @"spicy", @"insane", @"custom"];
        self.screenMusicName = @"music_menu";
        [self buildScreen];
    }
    return self;
}

- (void)buildScreen {
    CSAppContext *context = CSAppContext.shared;
    CSLevel *level = [context.catalog levelForID:_levelID];
    CSWorld *world = [context.catalog worldForID:level.worldID];
    CSCar *car = [context selectedCar];
    CSAssetCatalog *assets = [CSAssetCatalog shared];
    NSColor *accent = [assets colorFromHex:world.accentHex];

    SKSpriteNode *topBar = [SKSpriteNode spriteNodeWithColor:accent size:CGSizeMake(640, 66)];
    topBar.anchorPoint = CGPointZero;
    topBar.position = CGPointMake(0, 294);
    topBar.zPosition = 1;
    [self.contentRoot addChild:topBar];

    [self addLabel:[NSString stringWithFormat:@"LEVEL %02ld", (long)level.levelID]
           atPoint:CGPointMake(320, 338) scale:1.6
             color:[NSColor colorWithSRGBRed:0.22 green:0.13 blue:0.28 alpha:1]
         alignment:CSPixelTextAlignmentCenter zPosition:3];
    [self addLabel:[NSString stringWithFormat:@"%@  -  %@", world.name.uppercaseString, level.name.uppercaseString]
           atPoint:CGPointMake(320, 314) scale:0.7
             color:[NSColor colorWithSRGBRed:0.26 green:0.17 blue:0.32 alpha:0.85]
         alignment:CSPixelTextAlignmentCenter zPosition:3].shadowEnabled = NO;

    CSPixelButtonNode *back = [[CSPixelButtonNode alloc] initWithText:@"BACK"
                                                           textureName:@"ui_button_lavender"
                                                                  size:CGSizeMake(70, 24)
                                                             fontScale:0.75];
    back.position = CGPointMake(45, 331);
    __weak typeof(self) weakSelf = self;
    back.actionBlock = ^{
        [CSAppContext.shared.viewController presentLevelSelect];
        (void)weakSelf;
    };
    [self addButton:back];

    [self addPanelWithTexture:@"ui_panel" size:CGSizeMake(588, 226) position:CGPointMake(320, 166) zPosition:2];

    [self addLabel:@"YOUR RIDE" atPoint:CGPointMake(150, 253) scale:0.66
             color:[NSColor colorWithSRGBRed:0.42 green:0.30 blue:0.46 alpha:1]
         alignment:CSPixelTextAlignmentCenter zPosition:4].shadowEnabled = NO;
    SKSpriteNode *carSprite = [SKSpriteNode spriteNodeWithTexture:
        [assets textureNamed:[NSString stringWithFormat:@"%@_0", car.assetPrefix] fallback:@"car_sunny-bug_0"]];
    carSprite.size = CGSizeMake(36 * 1.85, 58 * 1.85);
    carSprite.position = CGPointMake(150, 178);
    carSprite.zPosition = 4;
    [self.contentRoot addChild:carSprite];
    if (!context.save.reducedMotion) {
        [carSprite runAction:[SKAction repeatActionForever:[SKAction sequence:@[
            [SKAction moveByX:0 y:2.5 duration:0.9],
            [SKAction moveByX:0 y:-2.5 duration:0.9],
        ]]]];
    }
    [self addLabel:car.name.uppercaseString atPoint:CGPointMake(150, 104) scale:0.82
             color:[NSColor colorWithSRGBRed:0.27 green:0.17 blue:0.33 alpha:1]
         alignment:CSPixelTextAlignmentCenter zPosition:4];
    [self addLabel:[NSString stringWithFormat:@"SPD %ld   ACC %ld   GRP %ld",
                    (long)car.speed, (long)car.acceleration, (long)car.grip]
           atPoint:CGPointMake(150, 85) scale:0.62
             color:[NSColor colorWithSRGBRed:0.42 green:0.30 blue:0.46 alpha:0.95]
         alignment:CSPixelTextAlignmentCenter zPosition:4].shadowEnabled = NO;

    SKSpriteNode *divider = [SKSpriteNode spriteNodeWithColor:
        [NSColor colorWithSRGBRed:0.80 green:0.69 blue:0.72 alpha:0.5] size:CGSizeMake(2, 190)];
    divider.position = CGPointMake(268, 166);
    divider.zPosition = 3;
    [self.contentRoot addChild:divider];

    [self addLabel:level.name.uppercaseString atPoint:CGPointMake(292, 248) scale:1.05
             color:[NSColor colorWithSRGBRed:0.25 green:0.15 blue:0.31 alpha:1]
         alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;

    CSPixelLabelNode *description = [self addLabel:CSBriefingTextForMechanic(level.mechanic)
                                           atPoint:CGPointMake(292, 218) scale:0.64
                                             color:[NSColor colorWithSRGBRed:0.37 green:0.25 blue:0.42 alpha:1]
                                         alignment:CSPixelTextAlignmentLeft zPosition:4];
    description.shadowEnabled = NO;

    [self addLabel:[NSString stringWithFormat:@"TRACK %.1fK  -  %ld LIVES", level.length / 1000.0,
                    (long)_settings.lives]
           atPoint:CGPointMake(292, 187) scale:0.68
             color:[NSColor colorWithSRGBRed:0.31 green:0.20 blue:0.37 alpha:1]
         alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;

    CGFloat hazardX = 294;
    for (NSString *hazardName in level.hazards) {
        CSHazardKind kind = CSHazardKindFromString(hazardName);
        NSString *asset = CSHazardAssetName(kind, 0);
        SKSpriteNode *icon = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:asset]];
        icon.size = CGSizeMake(22, 22);
        icon.position = CGPointMake(hazardX, 163);
        icon.zPosition = 4;
        [self.contentRoot addChild:icon];
        hazardX += 28;
    }

    SKSpriteNode *star2 = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"icon_star_full"]];
    star2.size = CGSizeMake(12, 12);
    star2.position = CGPointMake(292, 142);
    star2.zPosition = 4;
    [self.contentRoot addChild:star2];
    [self addLabel:[NSString stringWithFormat:@"2 STARS  %ld", (long)level.star2]
           atPoint:CGPointMake(301, 142) scale:0.57
             color:[NSColor colorWithSRGBRed:0.42 green:0.30 blue:0.46 alpha:1]
         alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;
    SKSpriteNode *star3 = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"icon_star_full"]];
    star3.size = CGSizeMake(12, 12);
    star3.position = CGPointMake(432, 142);
    star3.zPosition = 4;
    [self.contentRoot addChild:star3];
    [self addLabel:[NSString stringWithFormat:@"3 STARS  %ld", (long)level.star3]
           atPoint:CGPointMake(441, 142) scale:0.57
             color:[NSColor colorWithSRGBRed:0.42 green:0.30 blue:0.46 alpha:1]
         alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;

    [self addLabel:@"DIFFICULTY" atPoint:CGPointMake(292, 116) scale:0.63
             color:[NSColor colorWithSRGBRed:0.31 green:0.20 blue:0.37 alpha:1]
         alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;
    CSPixelButtonNode *prev = [[CSPixelButtonNode alloc] initWithIcon:@"icon_arrow_left"
                                                           textureName:@"ui_button_sky"
                                                                  size:CGSizeMake(23, 22)];
    prev.position = CGPointMake(390, 116);
    prev.actionBlock = ^{ [weakSelf changeDifficulty:-1]; };
    [self addButton:prev];

    _difficultyLabel = [self addLabel:@"" atPoint:CGPointMake(458, 116) scale:0.68
                                color:[NSColor colorWithSRGBRed:0.25 green:0.15 blue:0.31 alpha:1]
                            alignment:CSPixelTextAlignmentCenter zPosition:4];
    _difficultyLabel.shadowEnabled = NO;

    CSPixelButtonNode *next = [[CSPixelButtonNode alloc] initWithIcon:@"icon_arrow_right"
                                                           textureName:@"ui_button_sky"
                                                                  size:CGSizeMake(23, 22)];
    next.position = CGPointMake(533, 116);
    next.actionBlock = ^{ [weakSelf changeDifficulty:1]; };
    [self addButton:next];

    CSPixelButtonNode *garage = [[CSPixelButtonNode alloc] initWithText:@"GARAGE"
                                                             textureName:@"ui_button_lavender"
                                                                    size:CGSizeMake(92, 30)
                                                               fontScale:0.75];
    garage.position = CGPointMake(330, 82);
    garage.actionBlock = ^{
        [CSAppContext.shared.viewController presentGarage];
    };
    [self addButton:garage];

    CSPixelButtonNode *start = [[CSPixelButtonNode alloc] initWithText:@"START RACE"
                                                            textureName:@"ui_button_mint"
                                                                   size:CGSizeMake(170, 38)
                                                              fontScale:1.15];
    start.position = CGPointMake(466, 82);
    NSInteger startLevelID = _levelID;
    start.actionBlock = ^{
        [CSAppContext.shared.viewController startGameForLevelID:startLevelID];
    };
    [self addButton:start];
    [self focusButtonAtIndex:(NSInteger)[self.buttons indexOfObject:start]];

    NSString *coach = _levelID == 1
        ? @"A / D OR ARROWS STEER  -  W GO  -  S BRAKE  -  SPACE TURBO"
        : @"ESC PAUSES  -  EARN STARS TO UNLOCK NEW CARS";
    [self addLabel:coach atPoint:CGPointMake(320, 34) scale:0.54
             color:[NSColor colorWithSRGBRed:0.35 green:0.23 blue:0.41 alpha:0.85]
         alignment:CSPixelTextAlignmentCenter zPosition:4].shadowEnabled = NO;

    [self updateDifficultyLabel];
}

- (void)changeDifficulty:(NSInteger)delta {
    NSUInteger found = [_difficultyKeys indexOfObject:CSDifficultyPresetKey(_settings.preset)];
    NSInteger index = found == NSNotFound ? 1 : (NSInteger)found;
    index = (index + delta + (NSInteger)_difficultyKeys.count) % (NSInteger)_difficultyKeys.count;
    CSDifficultyPreset preset = CSDifficultyPresetFromString(_difficultyKeys[index]);
    _settings = [CSDifficultySettings settingsForPreset:preset];
    [CSAppContext.shared.save setDifficultySettings:_settings];
    [self updateDifficultyLabel];
    [CSAppContext.shared.audio playSFX:@"sfx_click"];
}

- (void)updateDifficultyLabel {
    if (_settings.preset == CSDifficultyPresetCustom) {
        _difficultyLabel.text = [NSString stringWithFormat:@"CUSTOM - %ld LIVES", (long)_settings.lives];
    } else {
        _difficultyLabel.text = [NSString stringWithFormat:@"%@ - %ld LIVES",
                                 [_settings displayName].uppercaseString, (long)_settings.lives];
    }
}

- (void)goBack {
    [CSAppContext.shared.viewController presentLevelSelect];
}

@end
