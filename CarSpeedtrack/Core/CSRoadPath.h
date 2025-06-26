#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "CSModels.h"

NS_ASSUME_NONNULL_BEGIN

/// Deterministic, smooth road centreline. This is the single source of truth
/// for rendering, spawning, collisions, and decorations.
@interface CSRoadPath : NSObject

@property (nonatomic, readonly) uint64_t seed;
@property (nonatomic, readonly) CGFloat length;
@property (nonatomic, readonly) CGFloat baseRoadWidth;
@property (nonatomic, readonly) CGFloat curviness;

- (instancetype)initWithLevel:(CSLevel *)level NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (CGFloat)centerXAtDistance:(CGFloat)distance;
- (CGFloat)halfWidthAtDistance:(CGFloat)distance;
- (CGFloat)leftEdgeAtDistance:(CGFloat)distance;
- (CGFloat)rightEdgeAtDistance:(CGFloat)distance;
- (CGFloat)laneCenterForLane:(NSInteger)lane laneCount:(NSInteger)laneCount atDistance:(CGFloat)distance;
- (CGFloat)tangentAtDistance:(CGFloat)distance;
- (CGFloat)offRoadAmountForX:(CGFloat)x distance:(CGFloat)distance;

@end

NS_ASSUME_NONNULL_END
