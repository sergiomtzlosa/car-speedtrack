#import "CSLevelSelectScene.h"
#import "CSAppContext.h"
#import "CSGameCatalog.h"
#import "CSSaveManager.h"
#import "CSAssetCatalog.h"
#import "CSGameViewController.h"
#import "CSPixelLabelNode.h"

static NSArray<NSString *> *CSWrapLevelName(NSString *name, NSUInteger maxChars) {
    NSString *upper = name.uppercaseString;
    if (upper.length <= maxChars) return @[upper];
    NSArray<NSString *> *words = [upper componentsSeparatedByString:@" "];
    if (words.count < 2) {
        NSString *line = upper.length > maxChars ? [[upper substringToIndex:maxChars - 3] stringByAppendingString:@"..."] : upper;
        return @[line];
    }

    NSUInteger bestSplit = 1;
    NSUInteger bestScore = NSUIntegerMax;
    for (NSUInteger i = 1; i < words.count; i++) {
        NSString *first = [[words subarrayWithRange:NSMakeRange(0, i)] componentsJoinedByString:@" "];
        NSString *second = [[words subarrayWithRange:NSMakeRange(i, words.count - i)] componentsJoinedByString:@" "];
        NSUInteger longest = MAX(first.length, second.length);
        NSUInteger balance = first.length > second.length ? first.length - second.length : second.length - first.length;
        NSUInteger score = longest * 1000 + balance;
        if (score < bestScore) {
            bestScore = score;
            bestSplit = i;
        }
    }

    NSString *line1 = [[words subarrayWithRange:NSMakeRange(0, bestSplit)] componentsJoinedByString:@" "];
    NSString *line2 = [[words subarrayWithRange:NSMakeRange(bestSplit, words.count - bestSplit)] componentsJoinedByString:@" "];
    if (line1.length > maxChars) {
        line1 = [[line1 substringToIndex:maxChars - 3] stringByAppendingString:@"..."];
    }
    if (line2.length > maxChars) {
        line2 = [[line2 substringToIndex:maxChars - 3] stringByAppendingString:@"..."];
    }
    return @[line1, line2];
}

@implementation CSLevelSelectScene {
    NSInteger _currentWorld;
    NSMutableArray<CSPixelButtonNode *> *_cardButtons;
    NSMutableArray<CSPixelButtonNode *> *_tabButtons;
    SKSpriteNode *_worldMarker;
    CSPixelLabelNode *_worldLabel;
    CSPixelLabelNode *_starTotalLabel;
}

- (instancetype)init {
    self = [super initWithSize:CGSizeMake(640, 360)];
    if (self) {
        self.screenMusicName = @"music_menu";
        CSAppContext *context = CSAppContext.shared;
        NSInteger nextLevel = [context.save nextLevelToPlay];
        CSLevel *level = [context.catalog levelForID:nextLevel];
        _currentWorld = level ? level.worldID : 1;
        _cardButtons = [NSMutableArray array];
        _tabButtons = [NSMutableArray array];
        [self buildHeader];
        [self buildTabs];
        [self buildWorld];
    }
    return self;
}

- (void)buildHeader {
    SKSpriteNode *header = [SKSpriteNode spriteNodeWithColor:[NSColor colorWithSRGBRed:0.22 green:0.14 blue:0.27 alpha:0.88]
                                                        size:CGSizeMake(640, 52)];
    header.anchorPoint = CGPointZero;
    header.position = CGPointMake(0, 308);
    header.zPosition = 1;
    [self.contentRoot addChild:header];
    SKSpriteNode *line = [SKSpriteNode spriteNodeWithColor:[NSColor colorWithSRGBRed:1.0 green:0.84 blue:0.44 alpha:1.0]
                                                      size:CGSizeMake(640, 3)];
    line.anchorPoint = CGPointZero;
    line.position = CGPointMake(0, 308);
    line.zPosition = 2;
    [self.contentRoot addChild:line];

    [self addLabel:@"LEVEL SELECT" atPoint:CGPointMake(320, 338) scale:1.65
             color:[NSColor colorWithSRGBRed:1 green:0.97 blue:0.87 alpha:1]
         alignment:CSPixelTextAlignmentCenter zPosition:3];

    CSPixelButtonNode *back = [[CSPixelButtonNode alloc] initWithText:@"BACK"
                                                           textureName:@"ui_button_lavender"
                                                                  size:CGSizeMake(70, 24)
                                                             fontScale:0.75];
    back.position = CGPointMake(45, 338);
    __weak typeof(self) weakSelf = self;
    back.actionBlock = ^{
        [weakSelf goBack];
    };
    [self addButton:back];

    SKSpriteNode *star = [SKSpriteNode spriteNodeWithTexture:
        [[CSAssetCatalog shared] textureNamed:@"icon_star_full"]];
    star.size = CGSizeMake(16, 16);
    star.position = CGPointMake(536, 338);
    star.zPosition = 3;
    [self.contentRoot addChild:star];
    _starTotalLabel = [self addLabel:[NSString stringWithFormat:@"%ld / 300", (long)[CSAppContext.shared displayStars]]
                             atPoint:CGPointMake(552, 338) scale:0.7
                               color:[NSColor colorWithSRGBRed:1 green:0.94 blue:0.72 alpha:1]
                           alignment:CSPixelTextAlignmentLeft zPosition:3];
    _starTotalLabel.shadowEnabled = NO;
}

- (void)buildTabs {
    NSUInteger index = 0;
    NSArray<NSString *> *textures = @[@"ui_button_yellow", @"ui_button_mint", @"ui_button_sky",
                                      @"ui_button_pink", @"ui_button_lavender", @"ui_button_rose"];
    for (CSWorld *world in CSAppContext.shared.catalog.worlds) {
        CSPixelButtonNode *tab = [[CSPixelButtonNode alloc] initWithText:
            [NSString stringWithFormat:@"W%ld", (long)world.worldID]
                                                             textureName:textures[index % textures.count]
                                                                    size:CGSizeMake(52, 20)
                                                               fontScale:0.66];
        tab.position = CGPointMake(58 + (CGFloat)index * 56.0, 314);
        __weak typeof(self) weakSelf = self;
        NSInteger worldID = world.worldID;
        tab.actionBlock = ^{
            [weakSelf selectWorld:worldID];
        };
        [_tabButtons addObject:tab];
        [self addButton:tab];
        index++;
    }
    _worldMarker = [SKSpriteNode spriteNodeWithColor:NSColor.whiteColor size:CGSizeMake(53, 3)];
    _worldMarker.zPosition = 8;
    _worldMarker.position = CGPointMake(58, 301);
    [self.contentRoot addChild:_worldMarker];

    _worldLabel = [self addLabel:@"" atPoint:CGPointMake(320, 289) scale:0.82
                           color:[NSColor colorWithSRGBRed:0.30 green:0.19 blue:0.36 alpha:1]
                       alignment:CSPixelTextAlignmentCenter zPosition:3];
    _worldLabel.shadowEnabled = NO;
}

- (void)buildWorld {
    CSAppContext *context = CSAppContext.shared;
    CSWorld *world = [context.catalog worldForID:_currentWorld];
    _worldLabel.text = [NSString stringWithFormat:@"WORLD %ld - %@", (long)world.worldID,
                        world.name.uppercaseString];
    _worldMarker.color = [[CSAssetCatalog shared] colorFromHex:world.accentHex];
    NSInteger tabIndex = (NSInteger)(_currentWorld - 1);
    if (tabIndex >= 0 && tabIndex < (NSInteger)_tabButtons.count) {
        _worldMarker.position = CGPointMake(_tabButtons[tabIndex].position.x, 301);
    }

    for (CSPixelButtonNode *card in _cardButtons) {
        [self.buttons removeObject:card];
        [card removeFromParent];
    }
    [_cardButtons removeAllObjects];

    NSArray<CSLevel *> *levels = [context.catalog levelsInWorld:_currentWorld];
    for (NSUInteger i = 0; i < levels.count; i++) {
        CSLevel *level = levels[i];
        NSInteger column = (NSInteger)i % 5;
        NSInteger row = (NSInteger)i / 5;
        CGPoint position = CGPointMake(84 + (CGFloat)column * 118.0,
                                       231 - (CGFloat)row * 94.0);
        CSPixelButtonNode *card = [self makeCardForLevel:level position:position];
        [_cardButtons addObject:card];
        [self addButton:card];
    }
    [self focusButtonAtIndex:1 + tabIndex];
    _starTotalLabel.text = [NSString stringWithFormat:@"%ld / 300", (long)[context displayStars]];
}

- (CSPixelButtonNode *)makeCardForLevel:(CSLevel *)level position:(CGPoint)position {
    CSAppContext *context = CSAppContext.shared;
    BOOL unlocked = [context isLevelUnlocked:level.levelID];
    BOOL completed = [context.save isLevelCompleted:level.levelID];
    NSInteger stars = [context.save starsForLevel:level.levelID];
    NSInteger best = [context.save bestScoreForLevel:level.levelID];

    CSPixelButtonNode *card = [[CSPixelButtonNode alloc] initWithText:@""
                                                          textureName:completed ? @"ui_panel" : @"ui_panel_cream"
                                                                 size:CGSizeMake(112, 88)
                                                            fontScale:0.62];
    card.position = position;
    card.enabled = unlocked;
    if (!unlocked) {
        card.panel.alpha = 0.9;
    }

    CGFloat left = -48.0;
    CSPixelLabelNode *number = [[CSPixelLabelNode alloc] initWithText:
        [NSString stringWithFormat:@"%02ld", (long)level.levelID] fontScale:0.95
                                                                  color:[NSColor colorWithSRGBRed:0.37 green:0.24 blue:0.44 alpha:1]];
    number.alignment = CSPixelTextAlignmentLeft;
    number.position = CGPointMake(left, 26);
    number.zPosition = 5;
    [card.panel addChild:number];

    // The card's usable width is 96 px. At 12 pt Menlo a line fits 13
    // characters, so wrap on word boundaries instead of counting to 17.
    NSArray<NSString *> *nameLines = CSWrapLevelName(level.name, 13);
    NSString *line1 = nameLines.firstObject;
    NSString *line2 = nameLines.count > 1 ? nameLines[1] : @"";
    BOOL twoLines = line2.length > 0;
    CGFloat nameY = twoLines ? 9 : 3;
    CSPixelLabelNode *name = [[CSPixelLabelNode alloc] initWithText:line1 fontScale:0.62
                                                              color:[NSColor colorWithSRGBRed:0.25 green:0.16 blue:0.30 alpha:1]];
    name.position = CGPointMake(0, nameY);
    name.maxWidth = 96;
    name.zPosition = 5;
    [card.panel addChild:name];
    if (twoLines) {
        CSPixelLabelNode *second = [[CSPixelLabelNode alloc] initWithText:line2 fontScale:0.62
                                                                   color:[NSColor colorWithSRGBRed:0.25 green:0.16 blue:0.30 alpha:1]];
        second.position = CGPointMake(0, -5);
        second.maxWidth = 96;
        second.zPosition = 5;
        [card.panel addChild:second];
    }

    if (!unlocked) {
        SKSpriteNode *lock = [SKSpriteNode spriteNodeWithTexture:
            [[CSAssetCatalog shared] textureNamed:@"icon_lock"]];
        lock.size = CGSizeMake(16, 18);
        lock.position = CGPointMake(0, twoLines ? -23 : -21);
        lock.zPosition = 5;
        [card.panel addChild:lock];
    } else {
        CGFloat starY = twoLines ? -17 : -15;
        for (NSInteger s = 0; s < 3; s++) {
            NSString *icon = s < stars ? @"icon_star_full" : @"icon_star_empty";
            SKSpriteNode *star = [SKSpriteNode spriteNodeWithTexture:
                [[CSAssetCatalog shared] textureNamed:icon]];
            star.size = CGSizeMake(11, 11);
            star.position = CGPointMake(-15 + s * 15, starY);
            star.zPosition = 5;
            [card.panel addChild:star];
        }
        if (best > 0) {
            CSPixelLabelNode *bestLabel = [[CSPixelLabelNode alloc] initWithText:
                [NSString stringWithFormat:@"BEST %ld", (long)best] fontScale:0.50
                                                                         color:[NSColor colorWithSRGBRed:0.42 green:0.28 blue:0.46 alpha:0.9]];
            bestLabel.position = CGPointMake(0, -30);
            bestLabel.zPosition = 5;
            [card.panel addChild:bestLabel];
        }
    }

    if (unlocked) {
        __weak typeof(self) weakSelf = self;
        NSInteger levelID = level.levelID;
        card.actionBlock = ^{
            [CSAppContext.shared.viewController presentBriefingForLevelID:levelID];
            (void)weakSelf;
        };
    }
    return card;
}

- (void)selectWorld:(NSInteger)worldID {
    if (worldID == _currentWorld) return;
    _currentWorld = MAX(1, MIN(10, worldID));
    [self buildWorld];
}

- (void)goBack {
    [CSAppContext.shared.viewController presentMenu];
}

@end
