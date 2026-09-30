#import <Foundation/Foundation.h>
#import "CSModels.h"

NS_ASSUME_NONNULL_BEGIN

@class CSGameCatalog;
@class CSSaveManager;
@class CSAudioManager;
@class CSGameViewController;

/// Shared game services and QA launch options. One instance lives for the
/// lifetime of the application.
@interface CSAppContext : NSObject

@property (class, readonly) CSAppContext *shared;

@property (nonatomic, readonly) CSGameCatalog *catalog;
@property (nonatomic, readonly) CSSaveManager *save;
@property (nonatomic, readonly) CSAudioManager *audio;
@property (nonatomic, weak, nullable) CSGameViewController *viewController;

@property (nonatomic) BOOL unlockAll;
@property (nonatomic, copy, nullable) NSString *carOverride;
@property (nonatomic, strong, nullable) CSDifficultySettings *difficultyOverride;
@property (nonatomic) BOOL skipCountdown;
@property (nonatomic) BOOL showFPS;
@property (nonatomic, copy, nullable) NSString *initialSceneName;
@property (nonatomic) NSInteger initialLevelID;
@property (nonatomic) BOOL scoresGlobalMode;
@property (nonatomic, copy, nullable) NSString *snapshotPath;
@property (nonatomic) NSTimeInterval snapshotDelay;
@property (nonatomic, readonly) BOOL debugging;

+ (void)bootstrap;

- (BOOL)isLevelUnlocked:(NSInteger)levelID;
- (NSInteger)displayStars;
- (CSDifficultySettings *)difficultyForNewRun;
- (NSString *)selectedCarID;
- (CSCar *)selectedCar;
- (void)setSelectedCarID:(NSString *)carID;
- (void)applyAudioSettings;
- (void)playClick;

@end

NS_ASSUME_NONNULL_END
