#import <SpriteKit/SpriteKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Live top-down race scene: procedural road rendering, traffic, pickups,
/// hazards, the HUD, pause menu, and the finish/failure hand-off to results.
@interface CSGameScene : SKScene

- (instancetype)initWithLevelID:(NSInteger)levelID;
- (void)togglePause;
- (void)retryLevel;

/// QA hook used by the snapshot harness to display the finish/failure overlay
/// without having to drive a whole race.
- (void)debugFinishRunCompleted:(BOOL)completed;

@end

NS_ASSUME_NONNULL_END
