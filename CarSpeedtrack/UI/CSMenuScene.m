#import "CSMenuScene.h"
#import "CSAppContext.h"
#import "CSGameCatalog.h"
#import "CSSaveManager.h"
#import "CSAssetCatalog.h"
#import "CSAudioManager.h"
#import "CSGameViewController.h"

@implementation CSMenuScene

- (instancetype)init {
    self = [super initWithSize:CGSizeMake(640, 360)];
    if (self) {
        self.screenMusicName = @"music_menu";
        [self buildMenu];
    }
    return self;
}

- (void)buildMenu {
    CSAppContext *context = CSAppContext.shared;
    CSAssetCatalog *assets = [CSAssetCatalog shared];

    SKSpriteNode *background = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"bg_menu"]];
    background.position = CGPointMake(320, 180);
    background.size = CGSizeMake(640, 360);
    background.zPosition = -99;
    [self addChild:background];

    SKSpriteNode *logo = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"logo_title"]];
    logo.position = CGPointMake(320, 303);
    logo.size = CGSizeMake(299, 102);
    logo.zPosition = 5;
    [self.contentRoot addChild:logo];

    [self addPanelWithTexture:@"ui_panel_dark" size:CGSizeMake(310, 248) position:CGPointMake(170, 128) zPosition:2];

    // A brand-new save has no completed runs and no stars. Greet those players
    // as newcomers instead of saying "welcome back" before their first race.
    // Do not use highestUnlocked here: a save can have every level unlocked
    // while still having no played runs.
    BOOL firstRun = !context.save.hasPlayedAnyRun && context.save.totalStars == 0;
    [self addLabel:firstRun ? @"WELCOME!" : @"WELCOME BACK!"
           atPoint:CGPointMake(86, 232) scale:0.82
             color:[NSColor colorWithSRGBRed:1.0 green:0.91 blue:0.64 alpha:1.0]
         alignment:CSPixelTextAlignmentLeft zPosition:6];

    NSInteger nextLevel = [context.save nextLevelToPlay];
    NSString *playText = [NSString stringWithFormat:@"PLAY LEVEL %02ld", (long)nextLevel];
    CSPixelButtonNode *play = [[CSPixelButtonNode alloc] initWithText:playText
                                                          textureName:@"ui_button_pink"
                                                                 size:CGSizeMake(266, 42)
                                                            fontScale:1.35
                                                            textColor:[NSColor colorWithSRGBRed:1 green:0.98 blue:0.94 alpha:1]];
    play.position = CGPointMake(170, 198);
    __weak typeof(self) weakSelf = self;
    __weak CSPixelButtonNode *weakPlay = play;
    play.actionBlock = ^{
        [weakPlay setFocused:NO];
        [weakSelf goToLevel:nextLevel];
    };
    [self addButton:play];

    NSArray<NSDictionary *> *items = @[
        @{@"title": @"LEVELS", @"texture": @"ui_button_yellow", @"point": [NSValue valueWithPoint:NSMakePoint(101, 150)],
          @"action": @"levels"},
        @{@"title": @"GARAGE", @"texture": @"ui_button_mint", @"point": [NSValue valueWithPoint:NSMakePoint(239, 150)],
          @"action": @"garage"},
        @{@"title": @"SCORES", @"texture": @"ui_button_sky", @"point": [NSValue valueWithPoint:NSMakePoint(101, 112)],
          @"action": @"scores"},
        @{@"title": @"SETTINGS", @"texture": @"ui_button_lavender", @"point": [NSValue valueWithPoint:NSMakePoint(239, 112)],
          @"action": @"settings"},
    ];
    for (NSDictionary *item in items) {
        CSPixelButtonNode *button = [[CSPixelButtonNode alloc] initWithText:item[@"title"]
                                                               textureName:item[@"texture"]
                                                                      size:CGSizeMake(130, 32)
                                                                 fontScale:0.95];
        button.position = [item[@"point"] pointValue];
        NSString *action = item[@"action"];
        button.actionBlock = ^{
            CSGameViewController *controller = CSAppContext.shared.viewController;
            if ([action isEqualToString:@"levels"]) [controller presentLevelSelect];
            else if ([action isEqualToString:@"garage"]) [controller presentGarage];
            else if ([action isEqualToString:@"scores"]) [controller presentScores];
            else [controller presentSettings];
        };
        [self addButton:button];
    }

    CSPixelButtonNode *quit = [[CSPixelButtonNode alloc] initWithText:@"QUIT"
                                                          textureName:@"ui_button_disabled"
                                                                 size:CGSizeMake(92, 26)
                                                            fontScale:0.8];
    quit.position = CGPointMake(71, 62);
    quit.actionBlock = ^{
        [NSApp terminate:nil];
    };
    [self addButton:quit];

    [self addLabel:@"TAKE A LITTLE ROAD TRIP - NO RUSH"
           atPoint:CGPointMake(167, 43) scale:0.64
             color:[NSColor colorWithSRGBRed:1 green:0.91 blue:0.78 alpha:0.9]
         alignment:CSPixelTextAlignmentCenter zPosition:6];

    // Selected car showcase on the right.
    [self addPanelWithTexture:@"ui_panel" size:CGSizeMake(264, 190) position:CGPointMake(474, 138) zPosition:2];
    [self addLabel:@"YOUR RIDE" atPoint:CGPointMake(474, 216) scale:0.8
             color:[NSColor colorWithSRGBRed:0.35 green:0.24 blue:0.41 alpha:0.85]
         alignment:CSPixelTextAlignmentCenter zPosition:6];

    CSCar *car = [context selectedCar];
    SKSpriteNode *carSprite = [SKSpriteNode spriteNodeWithTexture:
        [assets textureNamed:[NSString stringWithFormat:@"%@_0", car.assetPrefix] fallback:@"car_sunny-bug_0"]];
    carSprite.position = CGPointMake(474, 146);
    carSprite.size = CGSizeMake(36 * 2.05, 58 * 2.05);
    carSprite.zPosition = 7;
    [self.contentRoot addChild:carSprite];
    if (!context.save.reducedMotion) {
        SKAction *bob = [SKAction sequence:@[
            [SKAction moveByX:0 y:3 duration:0.9],
            [SKAction moveByX:0 y:-3 duration:0.9],
        ]];
        [carSprite runAction:[SKAction repeatActionForever:bob]];
    }

    [self addLabel:car.name.uppercaseString atPoint:CGPointMake(474, 86) scale:0.86
             color:[NSColor colorWithSRGBRed:0.28 green:0.18 blue:0.34 alpha:1]
         alignment:CSPixelTextAlignmentCenter zPosition:6];

    SKSpriteNode *star = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"icon_star_full"]];
    star.size = CGSizeMake(15, 15);
    star.position = CGPointMake(410, 63);
    star.zPosition = 6;
    [self.contentRoot addChild:star];
    NSInteger stars = [context displayStars];
    CSPixelLabelNode *starsLabel = [self addLabel:[NSString stringWithFormat:@"%ld / 300", (long)stars]
                                          atPoint:CGPointMake(421, 63) scale:0.75
                                            color:[NSColor colorWithSRGBRed:0.35 green:0.24 blue:0.41 alpha:1]
                                        alignment:CSPixelTextAlignmentLeft zPosition:6];
    starsLabel.shadowEnabled = NO;

    CSPixelLabelNode *help = [self addLabel:@"WASD / ARROWS - MOUSE - ENTER"
                                   atPoint:CGPointMake(564, 24) scale:0.6
                                     color:[NSColor colorWithSRGBRed:0.28 green:0.18 blue:0.34 alpha:0.9]
                                 alignment:CSPixelTextAlignmentRight zPosition:6];
    help.shadowEnabled = NO;

    [self addLabel:@"v1.0" atPoint:CGPointMake(622, 350) scale:0.5
             color:[NSColor colorWithSRGBRed:0.28 green:0.18 blue:0.34 alpha:0.5]
         alignment:CSPixelTextAlignmentRight zPosition:6].shadowEnabled = NO;
}

- (void)goToLevel:(NSInteger)levelID {
    [CSAppContext.shared.viewController presentBriefingForLevelID:levelID];
}

- (void)goBack {
    // The main menu is the root of the navigation stack.
}

@end
