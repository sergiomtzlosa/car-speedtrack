#import "CSRoadPath.h"
#import "CSRandom.h"
#import <math.h>

static CGFloat CSSmoothstep(CGFloat edge0, CGFloat edge1, CGFloat x) {
    if (edge1 <= edge0) return 1.0;
    CGFloat t = MIN(1.0, MAX(0.0, (x - edge0) / (edge1 - edge0)));
    return t * t * (3.0 - 2.0 * t);
}

@implementation CSRoadPath {
    CGFloat _phase[4];
    CGFloat _frequency[3];
    CGFloat _weight[3];
    CGFloat _amplitude;
    CGFloat _widthWobble;
}

- (instancetype)initWithLevel:(CSLevel *)level {
    self = [super init];
    if (self) {
        _seed = level.seed;
        _length = MAX(1000.0, level.length);
        _baseRoadWidth = level.roadWidth > 100 ? level.roadWidth : 408.0;
        _curviness = MIN(1.0, MAX(0.0, level.curviness));

        CSRandom *random = [[CSRandom alloc] initWithSeed:level.seed ^ 0x5EEDBEEFCAFEULL];
        for (NSInteger i = 0; i < 4; i++) {
            _phase[i] = [random nextFloatFrom:0 to:(CGFloat)(M_PI * 2.0)];
        }
        _frequency[0] = 0.00155;
        _frequency[1] = 0.0037;
        _frequency[2] = 0.0079;
        _weight[0] = 0.58;
        _weight[1] = 0.29;
        _weight[2] = 0.13;

        CGFloat margin = 320.0 - (_baseRoadWidth * 0.5) - 18.0;
        _amplitude = MIN(MAX(28.0, 28.0 + _curviness * 128.0), MAX(10.0, margin));
        _widthWobble = _baseRoadWidth * 0.045;
    }
    return self;
}

- (CGFloat)straightEnvelopeAtDistance:(CGFloat)distance {
    CGFloat start = CSSmoothstep(0.0, 650.0, distance);
    CGFloat finish = 1.0 - CSSmoothstep(self.length - 520.0, self.length, distance);
    return start * MAX(0.0, finish);
}

- (CGFloat)centerXAtDistance:(CGFloat)distance {
    CGFloat s = MAX(0.0, distance);
    CGFloat env = [self straightEnvelopeAtDistance:s];
    CGFloat curve = 0.0;
    for (NSInteger i = 0; i < 3; i++) {
        curve += _weight[i] * sin(s * _frequency[i] + _phase[i]);
    }
    CGFloat center = 320.0 + env * _amplitude * curve;
    CGFloat half = [self halfWidthAtDistance:s];
    return MIN(640.0 - half - 12.0, MAX(half + 12.0, center));
}

- (CGFloat)halfWidthAtDistance:(CGFloat)distance {
    CGFloat s = MAX(0.0, distance);
    CGFloat wobble = 1.0 + 0.045 * sin(s * 0.0013 + _phase[3]);
    return _baseRoadWidth * 0.5 * wobble;
}

- (CGFloat)leftEdgeAtDistance:(CGFloat)distance {
    return [self centerXAtDistance:distance] - [self halfWidthAtDistance:distance];
}

- (CGFloat)rightEdgeAtDistance:(CGFloat)distance {
    return [self centerXAtDistance:distance] + [self halfWidthAtDistance:distance];
}

- (CGFloat)laneCenterForLane:(NSInteger)lane laneCount:(NSInteger)laneCount atDistance:(CGFloat)distance {
    NSInteger count = MAX(1, laneCount);
    NSInteger index = MIN(MAX(0, lane), count - 1);
    CGFloat half = [self halfWidthAtDistance:distance];
    CGFloat laneWidth = (half * 2.0) / (CGFloat)count;
    return [self leftEdgeAtDistance:distance] + laneWidth * ((CGFloat)index + 0.5);
}

- (CGFloat)tangentAtDistance:(CGFloat)distance {
    CGFloat span = 2.0;
    CGFloat before = [self centerXAtDistance:distance - span];
    CGFloat after = [self centerXAtDistance:distance + span];
    return (after - before) / (span * 2.0);
}

- (CGFloat)offRoadAmountForX:(CGFloat)x distance:(CGFloat)distance {
    CGFloat half = [self halfWidthAtDistance:distance];
    CGFloat center = [self centerXAtDistance:distance];
    CGFloat delta = fabs(x - center);
    if (delta <= half) return 0.0;
    // Ramp to full off-road grip loss within 80 points of the edge.
    return MIN(1.0, (delta - half) / 80.0);
}

@end
