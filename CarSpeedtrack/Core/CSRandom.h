#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Small deterministic PCG32 random source. Used by road generation, scenery,
/// and the spawn director so a level can be replayed exactly.
@interface CSRandom : NSObject

@property (nonatomic, readonly) uint64_t seed;

- (instancetype)initWithSeed:(uint64_t)seed NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (uint32_t)nextUInt32;
- (uint64_t)nextUInt64;
- (double)nextDouble;
- (NSInteger)nextInt:(NSInteger)upperBound;
- (CGFloat)nextFloatFrom:(CGFloat)low to:(CGFloat)high;
- (BOOL)chance:(double)probability;

@end

NS_ASSUME_NONNULL_END
