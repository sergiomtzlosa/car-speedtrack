#import <Foundation/Foundation.h>

@class CSGameCatalog;

NS_ASSUME_NONNULL_BEGIN

/// Class anchor so tests can find resources copied next to the test bundle.
@interface CSTestSupport : NSObject
@end

/// Loads levels.json and cars.json from the test bundle.
FOUNDATION_EXPORT CSGameCatalog * _Nullable CSLoadTestCatalog(NSError **error);

/// Loads a flat JSON resource from the test bundle.
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable CSLoadTestJSON(NSString *name,
                                                                          NSError **error);

/// Creates and returns a unique empty directory under the system temp folder.
FOUNDATION_EXPORT NSURL *CSCreateTestDirectory(void);

FOUNDATION_EXPORT void CSRemoveTestDirectory(NSURL *directory);

NS_ASSUME_NONNULL_END
