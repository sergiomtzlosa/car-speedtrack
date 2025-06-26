#import "CSRandom.h"

@implementation CSRandom {
    uint64_t _state;
    uint64_t _inc;
}

- (instancetype)initWithSeed:(uint64_t)seed {
    self = [super init];
    if (self) {
        _seed = seed;
        _state = 0u;
        _inc = (seed << 1u) | 1u;
        [self nextUInt32];
        _state += seed;
        [self nextUInt32];
    }
    return self;
}

- (uint32_t)nextUInt32 {
    uint64_t old = _state;
    _state = old * 6364136223846793005ULL + _inc;
    uint32_t xorshifted = (uint32_t)(((old >> 18u) ^ old) >> 27u);
    uint32_t rot = (uint32_t)(old >> 59u);
    return (xorshifted >> rot) | (xorshifted << ((-(int32_t)rot) & 31));
}

- (uint64_t)nextUInt64 {
    return ((uint64_t)[self nextUInt32] << 32u) | [self nextUInt32];
}

- (double)nextDouble {
    return (double)[self nextUInt32] / 4294967296.0;
}

- (NSInteger)nextInt:(NSInteger)upperBound {
    if (upperBound <= 0) {
        return 0;
    }
    return (NSInteger)([self nextDouble] * (double)upperBound);
}

- (CGFloat)nextFloatFrom:(CGFloat)low to:(CGFloat)high {
    return low + (CGFloat)[self nextDouble] * (high - low);
}

- (BOOL)chance:(double)probability {
    return [self nextDouble] < probability;
}

@end
