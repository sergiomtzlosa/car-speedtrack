#import <XCTest/XCTest.h>
#import <math.h>
#import "CSTestSupport.h"
#import "CSGameCatalog.h"
#import "CSRoadPath.h"

@interface CSRoadPathTests : XCTestCase
@end

@implementation CSRoadPathTests

- (void)testRoadIsDeterministic {
    NSError *error = nil;
    CSGameCatalog *catalog = CSLoadTestCatalog(&error);
    XCTAssertNotNil(catalog, @"catalog failed: %@", error);
    CSLevel *level = [catalog levelForID:57];
    XCTAssertNotNil(level);

    CSRoadPath *first = [[CSRoadPath alloc] initWithLevel:level];
    CSRoadPath *second = [[CSRoadPath alloc] initWithLevel:level];
    XCTAssertEqual(first.seed, level.seed);
    XCTAssertEqualWithAccuracy(first.length, second.length, 0.0001);
    XCTAssertEqualWithAccuracy(first.baseRoadWidth, second.baseRoadWidth, 0.0001);

    for (CGFloat distance = 0; distance <= level.length; distance += 173.0) {
        XCTAssertEqualWithAccuracy([first centerXAtDistance:distance],
                                   [second centerXAtDistance:distance], 0.0001);
        XCTAssertEqualWithAccuracy([first leftEdgeAtDistance:distance],
                                   [second leftEdgeAtDistance:distance], 0.0001);
        XCTAssertEqualWithAccuracy([first rightEdgeAtDistance:distance],
                                   [second rightEdgeAtDistance:distance], 0.0001);
    }
}

- (void)testRoadStaysOnScreenAndLanesAreOrdered {
    NSError *error = nil;
    CSGameCatalog *catalog = CSLoadTestCatalog(&error);
    XCTAssertNotNil(catalog, @"catalog failed: %@", error);

    for (NSInteger levelID = 1; levelID <= 100; levelID += 9) {
        CSLevel *level = [catalog levelForID:levelID];
        CSRoadPath *road = [[CSRoadPath alloc] initWithLevel:level];
        for (CGFloat distance = 0; distance <= level.length + 600.0; distance += 311.0) {
            CGFloat center = [road centerXAtDistance:distance];
            CGFloat half = [road halfWidthAtDistance:distance];
            CGFloat left = [road leftEdgeAtDistance:distance];
            CGFloat right = [road rightEdgeAtDistance:distance];
            XCTAssertTrue(isfinite(center));
            XCTAssertTrue(isfinite(left));
            XCTAssertTrue(isfinite(right));
            XCTAssertGreaterThan(half, 0.0);
            XCTAssertLessThan(left, center);
            XCTAssertGreaterThan(right, center);
            XCTAssertGreaterThanOrEqual(left, 11.9);
            XCTAssertLessThanOrEqual(right, 628.1);

            CGFloat previous = -CGFLOAT_MAX;
            for (NSInteger lane = 0; lane < 3; lane++) {
                CGFloat laneX = [road laneCenterForLane:lane laneCount:3 atDistance:distance];
                XCTAssertTrue(isfinite(laneX));
                XCTAssertGreaterThan(laneX, previous);
                XCTAssertGreaterThanOrEqual(laneX, left);
                XCTAssertLessThanOrEqual(laneX, right);
                previous = laneX;
            }

            XCTAssertTrue(isfinite([road tangentAtDistance:distance]));
            XCTAssertEqualWithAccuracy([road offRoadAmountForX:center distance:distance], 0.0, 0.0001);
            XCTAssertEqualWithAccuracy([road offRoadAmountForX:center + half + 80.0 distance:distance],
                                       1.0, 0.0001);
        }
    }
}

- (void)testRoadHandlesDistancesBeyondTheFinish {
    NSError *error = nil;
    CSGameCatalog *catalog = CSLoadTestCatalog(&error);
    XCTAssertNotNil(catalog, @"catalog failed: %@", error);
    CSLevel *level = [catalog levelForID:100];
    CSRoadPath *road = [[CSRoadPath alloc] initWithLevel:level];

    CGFloat center = [road centerXAtDistance:level.length + 5000.0];
    CGFloat half = [road halfWidthAtDistance:level.length + 5000.0];
    XCTAssertTrue(isfinite(center));
    XCTAssertGreaterThanOrEqual(center - half, 11.9);
    XCTAssertLessThanOrEqual(center + half, 628.1);
    XCTAssertEqualWithAccuracy(center, 320.0, 0.001);

    XCTAssertEqualWithAccuracy([road offRoadAmountForX:center distance:level.length + 5000.0],
                               0.0, 0.0001);
    XCTAssertEqualWithAccuracy([road offRoadAmountForX:center + half * 4.0 distance:0.0],
                               1.0, 0.0001);
}

@end
