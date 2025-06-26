#import "CSScreenScene.h"
#import "CSModels.h"

NS_ASSUME_NONNULL_BEGIN

/// Post-race summary: score, stars, run stats, retry/next navigation and a
/// little celebration. The run has already been recorded by the game scene.
@interface CSResultsScene : CSScreenScene

- (instancetype)initWithResult:(CSRunResult *)result;

@end

NS_ASSUME_NONNULL_END
