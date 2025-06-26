#import "CSScoresScene.h"
#import "CSAppContext.h"
#import "CSGameCatalog.h"
#import "CSSaveManager.h"
#import "CSAssetCatalog.h"
#import "CSAudioManager.h"
#import "CSGameViewController.h"

@implementation CSScoresScene {
    BOOL _globalMode;
    NSInteger _levelID;
    CSPixelLabelNode *_levelLabel;
    CSPixelLabelNode *_emptyLabel;
    SKNode *_tableRoot;
    SKSpriteNode *_tabMarker;
    CSPixelButtonNode *_levelPrev;
    CSPixelButtonNode *_levelNext;
    CSPixelButtonNode *_byLevelTab;
    CSPixelButtonNode *_globalTab;
}

- (instancetype)init {
    self = [super initWithSize:CGSizeMake(640, 360)];
    if (self) {
        self.screenMusicName = @"music_menu";
        _levelID = [CSAppContext.shared.save nextLevelToPlay];
        _tableRoot = [SKNode node];
        _tableRoot.zPosition = 4;
        [self.contentRoot addChild:_tableRoot];
        [self buildScreen];
        [self refreshTable];
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
    [self addLabel:@"HIGH SCORES" atPoint:CGPointMake(320, 338) scale:1.7
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

    SKSpriteNode *trophy = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"icon_trophy"]];
    trophy.size = CGSizeMake(24, 26);
    trophy.position = CGPointMake(592, 338);
    trophy.zPosition = 3;
    [self.contentRoot addChild:trophy];

    _byLevelTab = [[CSPixelButtonNode alloc] initWithText:@"BY LEVEL"
                                               textureName:@"ui_button_pink"
                                                      size:CGSizeMake(112, 24)
                                                 fontScale:0.7];
    _byLevelTab.position = CGPointMake(255, 292);
    _byLevelTab.actionBlock = ^{ [weakSelf setGlobalMode:NO]; };
    [self addButton:_byLevelTab];

    _globalTab = [[CSPixelButtonNode alloc] initWithText:@"BEST RUNS"
                                              textureName:@"ui_button_sky"
                                                     size:CGSizeMake(112, 24)
                                                fontScale:0.7];
    _globalTab.position = CGPointMake(385, 292);
    _globalTab.actionBlock = ^{ [weakSelf setGlobalMode:YES]; };
    [self addButton:_globalTab];

    _tabMarker = [SKSpriteNode spriteNodeWithColor:[NSColor colorWithSRGBRed:0.93 green:0.44 blue:0.62 alpha:1]
                                              size:CGSizeMake(112, 3)];
    _tabMarker.position = CGPointMake(255, 278);
    _tabMarker.zPosition = 5;
    [self.contentRoot addChild:_tabMarker];

    _levelPrev = [[CSPixelButtonNode alloc] initWithIcon:@"icon_arrow_left"
                                             textureName:@"ui_button_lavender"
                                                    size:CGSizeMake(23, 22)];
    _levelPrev.position = CGPointMake(178, 260);
    _levelPrev.actionBlock = ^{ [weakSelf changeLevel:-1]; };
    [self addButton:_levelPrev];

    _levelNext = [[CSPixelButtonNode alloc] initWithIcon:@"icon_arrow_right"
                                             textureName:@"ui_button_lavender"
                                                    size:CGSizeMake(23, 22)];
    _levelNext.position = CGPointMake(462, 260);
    _levelNext.actionBlock = ^{ [weakSelf changeLevel:1]; };
    [self addButton:_levelNext];

    _levelLabel = [self addLabel:@"" atPoint:CGPointMake(320, 260) scale:0.7
                           color:[NSColor colorWithSRGBRed:0.33 green:0.21 blue:0.39 alpha:1]
                       alignment:CSPixelTextAlignmentCenter zPosition:4];

    [self addPanelWithTexture:@"ui_panel" size:CGSizeMake(574, 204) position:CGPointMake(320, 148) zPosition:2];

    _emptyLabel = [self addLabel:@"NO RUNS YET - GO MAKE ONE!" atPoint:CGPointMake(320, 148) scale:0.85
                           color:[NSColor colorWithSRGBRed:0.48 green:0.36 blue:0.51 alpha:0.8]
                       alignment:CSPixelTextAlignmentCenter zPosition:4];
    _emptyLabel.hidden = YES;

    [self addLabel:@"SCORES ARE SAVED LOCALLY" atPoint:CGPointMake(320, 28) scale:0.55
             color:[NSColor colorWithSRGBRed:0.33 green:0.21 blue:0.39 alpha:0.65]
         alignment:CSPixelTextAlignmentCenter zPosition:4].shadowEnabled = NO;
}

- (void)changeLevel:(NSInteger)delta {
    _levelID = MAX(1, MIN(100, _levelID + delta));
    [CSAppContext.shared.audio playSFX:@"sfx_click"];
    [self refreshTable];
}

- (void)setGlobalMode:(BOOL)global {
    if (_globalMode == global) return;
    _globalMode = global;
    _levelPrev.hidden = global;
    _levelNext.hidden = global;
    _levelPrev.enabled = !global;
    _levelNext.enabled = !global;
    _levelLabel.hidden = global;
    _tabMarker.position = CGPointMake(global ? 385 : 255, 278);
    [self refreshTable];
    [CSAppContext.shared.audio playSFX:@"sfx_click"];
}

- (void)refreshTable {
    CSAppContext *context = CSAppContext.shared;
    CSLevel *level = [context.catalog levelForID:_levelID];
    _levelLabel.text = [NSString stringWithFormat:@"LEVEL %02ld - %@", (long)level.levelID,
                        level.name.uppercaseString];
    [_tableRoot removeAllChildren];

    NSArray<NSDictionary *> *rows = _globalMode
        ? [context.save topRuns]
        : [context.save topScoresForLevel:_levelID];
    _emptyLabel.hidden = rows.count > 0;

    NSArray<NSString *> *columns = _globalMode
        ? @[@"#", @"SCORE", @"LEVEL", @"CAR", @"MODE", @"DATE"]
        : @[@"#", @"SCORE", @"STARS", @"CAR", @"MODE", @"DATE"];
    NSArray<NSNumber *> *xPositions = _globalMode
        ? @[@52, @82, @162, @292, @377, @460]
        : @[@52, @82, @160, @235, @350, @448];

    for (NSInteger i = 0; i < columns.count; i++) {
        CSPixelLabelNode *columnLabel = [[CSPixelLabelNode alloc] initWithText:columns[i] fontScale:0.54
                                                                        color:[NSColor colorWithSRGBRed:0.45 green:0.33 blue:0.48 alpha:0.9]];
        columnLabel.alignment = CSPixelTextAlignmentLeft;
        columnLabel.position = CGPointMake(xPositions[i].doubleValue, 236);
        [_tableRoot addChild:columnLabel];
    }
    SKSpriteNode *line = [SKSpriteNode spriteNodeWithColor:
        [NSColor colorWithSRGBRed:0.62 green:0.48 blue:0.64 alpha:0.4] size:CGSizeMake(534, 1)];
    line.position = CGPointMake(320, 226);
    line.zPosition = 4;
    [_tableRoot addChild:line];

    NSInteger limit = MIN(10, (NSInteger)rows.count);
    for (NSInteger i = 0; i < limit; i++) {
        NSDictionary *row = rows[i];
        CGFloat y = 211 - i * 17;
        if (i % 2 == 1) {
            SKSpriteNode *stripe = [SKSpriteNode spriteNodeWithColor:
                [NSColor colorWithSRGBRed:0.52 green:0.40 blue:0.56 alpha:0.06]
                                                                  size:CGSizeMake(546, 15)];
            stripe.position = CGPointMake(320, y);
            stripe.zPosition = 3;
            [_tableRoot addChild:stripe];
        }
        NSString *rank = [NSString stringWithFormat:@"%ld", (long)(i + 1)];
        NSString *score = [NSString stringWithFormat:@"%ld", (long)[row[@"score"] integerValue]];
        NSString *stars = [NSString stringWithFormat:@"%ld", (long)[row[@"stars"] integerValue]];
        NSString *car = [row[@"car"] isKindOfClass:[NSString class]] ? [row[@"car"] uppercaseString] : @"-";
        NSString *mode = [row[@"difficulty"] isKindOfClass:[NSString class]] ? [row[@"difficulty"] uppercaseString] : @"CLASSIC";
        NSString *date = [row[@"date"] isKindOfClass:[NSString class]] ? row[@"date"] : @"";
        if (date.length > 10) date = [date substringToIndex:10];
        NSString *levelText = _globalMode
            ? [NSString stringWithFormat:@"%02ld %@", (long)[row[@"levelID"] integerValue],
               [row[@"levelName"] isKindOfClass:[NSString class]] ? [row[@"levelName"] uppercaseString] : @""]
            : stars;
        if (_globalMode && levelText.length > 22) levelText = [levelText substringToIndex:21];
        NSArray<NSString *> *values = @[rank, score, levelText, car, mode, date];
        NSColor *color = i == 0
            ? [NSColor colorWithSRGBRed:0.65 green:0.25 blue:0.42 alpha:1]
            : [NSColor colorWithSRGBRed:0.27 green:0.18 blue:0.33 alpha:1];
        for (NSInteger c = 0; c < values.count; c++) {
            CSPixelLabelNode *label = [[CSPixelLabelNode alloc] initWithText:values[c] fontScale:0.55
                                                                       color:color];
            label.alignment = CSPixelTextAlignmentLeft;
            label.position = CGPointMake(xPositions[c].doubleValue, y);
            label.zPosition = 5;
            [_tableRoot addChild:label];
        }
    }
}

- (void)goBack {
    [CSAppContext.shared.viewController presentMenu];
}

@end
