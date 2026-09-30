#import "CSScreenScene.h"

NS_ASSUME_NONNULL_BEGIN

@interface CSScoresScene : CSScreenScene
- (instancetype)init;
/// Debug/QA helper for snapshotting the global BEST RUNS table.
- (void)showGlobalMode;
@end

NS_ASSUME_NONNULL_END
