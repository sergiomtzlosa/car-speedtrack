#import <Foundation/Foundation.h>
#import "CSModels.h"

NS_ASSUME_NONNULL_BEGIN

/// Versioned local JSON profile: settings, campaign progress, car choice,
/// per-level top scores and a global top-runs list.
@interface CSSaveManager : NSObject

@property (nonatomic, readonly) NSURL *saveURL;

/// A nil directory uses ~/Library/Application Support/CarSpeedtrack.
- (instancetype)initWithDirectory:(nullable NSURL *)directory NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)load;
- (void)saveNow;
- (void)resetProgress;
- (void)resetEverything;

- (NSString *)selectedCarID;
- (void)setSelectedCarID:(NSString *)carID;

- (CSDifficultySettings *)difficultySettings;
- (void)setDifficultySettings:(CSDifficultySettings *)settings;

- (CGFloat)volumeForKey:(NSString *)key;
- (void)setVolume:(CGFloat)value forKey:(NSString *)key;
- (BOOL)isMuted;
- (void)setMuted:(BOOL)muted;
- (BOOL)reducedMotion;
- (void)setReducedMotion:(BOOL)reduced;

- (NSInteger)totalStars;
- (NSInteger)highestUnlockedLevel;
- (NSInteger)nextLevelToPlay;
- (BOOL)isLevelCompleted:(NSInteger)levelID;
- (NSInteger)starsForLevel:(NSInteger)levelID;
- (NSInteger)bestScoreForLevel:(NSInteger)levelID;
- (NSInteger)bestComboForLevel:(NSInteger)levelID;
- (NSInteger)playCountForLevel:(NSInteger)levelID;
- (BOOL)isCarUnlocked:(CSCar *)car;

- (NSArray<NSDictionary<NSString *, id> *> *)topScoresForLevel:(NSInteger)levelID;
- (NSArray<NSDictionary<NSString *, id> *> *)topRuns;

/// Records a finished (or failed) run, updates bests/unlocks and returns the
/// same result object with `newBest` set.
- (CSRunResult *)recordResult:(CSRunResult *)result;

@property (nonatomic, readonly) NSDictionary<NSString *, id> *rawState;

@end

NS_ASSUME_NONNULL_END
