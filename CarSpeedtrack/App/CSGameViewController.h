#import <Cocoa/Cocoa.h>
#import "CSModels.h"

NS_ASSUME_NONNULL_BEGIN

@class SKScene;

@interface CSGameViewController : NSViewController

@property (nonatomic, readonly, nullable) SKScene *currentScene;

- (void)presentMenu;
- (void)presentLevelSelect;
- (void)presentBriefingForLevelID:(NSInteger)levelID;
- (void)presentGarage;
- (void)presentScores;
- (void)presentSettings;
- (void)startGameForLevelID:(NSInteger)levelID;
- (void)presentResults:(CSRunResult *)result;

- (void)menuPlayNextLevel;
- (void)menuTogglePause;
- (void)menuRetry;

@end

NS_ASSUME_NONNULL_END
