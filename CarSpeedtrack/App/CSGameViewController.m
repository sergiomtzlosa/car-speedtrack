#import "CSGameViewController.h"
#import "CSGameView.h"
#import "CSAppContext.h"
#import "CSGameCatalog.h"
#import "CSSaveManager.h"
#import "CSAudioManager.h"
#import "CSMenuScene.h"
#import "CSLevelSelectScene.h"
#import "CSBriefingScene.h"
#import "CSGarageScene.h"
#import "CSScoresScene.h"
#import "CSSettingsScene.h"
#import "CSResultsScene.h"
#import "CSGameScene.h"

@interface CSGameViewController ()
@property (nonatomic, readwrite, nullable) SKScene *currentScene;
@end

@implementation CSGameViewController

- (void)loadView {
    CSGameView *view = [[CSGameView alloc] initWithFrame:NSMakeRect(0, 0, 1280, 720)];
    self.view = view;
}

- (CSGameView *)gameView {
    return (CSGameView *)self.view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CSGameView *view = [self gameView];
    view.showsFPS = CSAppContext.shared.showFPS;
    view.showsNodeCount = CSAppContext.shared.showFPS;
    view.showsDrawCount = NO;
    [self presentInitialScene];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self.view.window makeFirstResponder:self.view];
}

- (void)presentScene:(SKScene *)scene {
    if (!scene) return;
    CSGameView *view = [self gameView];
    if (view.scene == scene) return;
    view.inputTarget = nil;
    scene.scaleMode = SKSceneScaleModeAspectFit;
    scene.size = CGSizeMake(640, 360);
    SKTransition *transition = [SKTransition crossFadeWithDuration:0.18];
    transition.pausesIncomingScene = NO;
    transition.pausesOutgoingScene = YES;
    [view presentScene:scene transition:transition];
    self.currentScene = scene;
}

- (void)presentInitialScene {
    CSAppContext *context = CSAppContext.shared;
    NSString *name = context.initialSceneName ?: @"menu";
    NSInteger levelID = context.initialLevelID > 0 ? context.initialLevelID : [context.save nextLevelToPlay];
    levelID = MAX(1, MIN(100, levelID));
    if ([name isEqualToString:@"levels"]) {
        [self presentLevelSelect];
    } else if ([name isEqualToString:@"garage"]) {
        [self presentGarage];
    } else if ([name isEqualToString:@"scores"]) {
        [self presentScores];
        if (context.scoresGlobalMode) {
            [(CSScoresScene *)self.currentScene showGlobalMode];
        }
    } else if ([name isEqualToString:@"settings"]) {
        [self presentSettings];
    } else if ([name isEqualToString:@"briefing"]) {
        [self presentBriefingForLevelID:levelID];
    } else if ([name isEqualToString:@"game"]) {
        [self startGameForLevelID:levelID];
    } else if ([name isEqualToString:@"pause"]) {
        [self startGameForLevelID:levelID];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.60 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [(CSGameScene *)self.currentScene togglePause];
        });
    } else if ([name isEqualToString:@"gamefinish"] || [name isEqualToString:@"gameover"]) {
        BOOL completed = [name isEqualToString:@"gamefinish"];
        [self startGameForLevelID:levelID];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (![self.currentScene isKindOfClass:[CSGameScene class]]) return;
            [(CSGameScene *)self.currentScene debugFinishRunCompleted:completed];
        });
    } else if ([name isEqualToString:@"results"] || [name isEqualToString:@"results-fail"]) {
        BOOL completed = [name isEqualToString:@"results"];
        CSRunResult *result = [CSRunResult new];
        result.levelID = levelID;
        CSLevel *level = [context.catalog levelForID:levelID];
        result.levelName = level.name;
        result.worldID = level.worldID;
        // Debug results are not recorded, so make a completed demo run beat
        // the saved best. This keeps "NEW BEST!" and BEST SCORE coherent.
        NSInteger best = [context.save bestScoreForLevel:levelID];
        result.score = completed ? MAX(level.star3 + 420, best + 280) : 1840;
        result.completed = completed;
        result.stars = completed ? 3 : 0;
        result.coins = completed ? 48 : 19;
        result.bestCombo = completed ? 9 : 4;
        result.livesLeft = completed ? 2 : 0;
        result.duration = completed ? 73.0 : 41.0;
        result.difficultyName = completed ? @"Classic" : @"Spicy";
        result.newBest = completed;
        result.carID = context.selectedCarID;
        [self presentResults:result];
    } else {
        [self presentMenu];
    }
}

- (void)presentMenu {
    CSMenuScene *scene = [[CSMenuScene alloc] init];
    [self presentScene:scene];
}

- (void)presentLevelSelect {
    CSLevelSelectScene *scene = [[CSLevelSelectScene alloc] init];
    [self presentScene:scene];
}

- (void)presentBriefingForLevelID:(NSInteger)levelID {
    CSLevel *level = [CSAppContext.shared.catalog levelForID:levelID];
    if (!level) return;
    CSBriefingScene *scene = [[CSBriefingScene alloc] initWithLevelID:levelID];
    [self presentScene:scene];
}

- (void)presentGarage {
    [self presentScene:[[CSGarageScene alloc] init]];
}

- (void)presentScores {
    [self presentScene:[[CSScoresScene alloc] init]];
}

- (void)presentSettings {
    [self presentScene:[[CSSettingsScene alloc] init]];
}

- (void)startGameForLevelID:(NSInteger)levelID {
    CSLevel *level = [CSAppContext.shared.catalog levelForID:levelID];
    if (!level) return;
    CSGameScene *scene = [[CSGameScene alloc] initWithLevelID:levelID];
    [self presentScene:scene];
}

- (void)presentResults:(CSRunResult *)result {
    CSResultsScene *scene = [[CSResultsScene alloc] initWithResult:result];
    [self presentScene:scene];
}

- (void)menuPlayNextLevel {
    if ([self.currentScene isKindOfClass:[CSGameScene class]]) {
        [(CSGameScene *)self.currentScene togglePause];
        return;
    }
    NSInteger levelID = [CSAppContext.shared.save nextLevelToPlay];
    [self presentBriefingForLevelID:levelID];
}

- (void)menuTogglePause {
    if ([self.currentScene isKindOfClass:[CSGameScene class]]) {
        [(CSGameScene *)self.currentScene togglePause];
    }
}

- (void)menuRetry {
    if ([self.currentScene isKindOfClass:[CSGameScene class]]) {
        [(CSGameScene *)self.currentScene retryLevel];
    }
}

@end
