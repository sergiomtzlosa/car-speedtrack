#import <XCTest/XCTest.h>
#import <math.h>
#import "CSTestSupport.h"
#import "CSGameCatalog.h"
#import "CSGameSession.h"
#import "CSModels.h"

@interface CSGameSessionTests : XCTestCase
@end

@implementation CSGameSessionTests

- (CSGameSession *)sessionForLevel:(NSInteger)levelID
                          difficulty:(CSDifficultyPreset)preset
                             runSeed:(uint64_t)seed {
    NSError *error = nil;
    CSGameCatalog *catalog = CSLoadTestCatalog(&error);
    XCTAssertNotNil(catalog, @"catalog failed: %@", error);
    CSLevel *level = [catalog levelForID:levelID];
    CSCar *car = catalog.cars.firstObject;
    CSDifficultySettings *difficulty = [CSDifficultySettings settingsForPreset:preset];
    return [[CSGameSession alloc] initWithLevel:level car:car difficulty:difficulty runSeed:seed];
}

- (void)testSessionStartsAndDrivesForward {
    CSGameSession *session = [self sessionForLevel:1 difficulty:CSDifficultyPresetClassic runSeed:1234];
    XCTAssertEqual(session.level.levelID, 1);
    XCTAssertEqual(session.lives, 3);
    XCTAssertEqual(session.laneCount, 3);
    XCTAssertEqualWithAccuracy(session.playerDistance, 0.0, 0.0001);
    XCTAssertEqualWithAccuracy(session.elapsed, 0.0, 0.0001);
    XCTAssertEqualWithAccuracy(session.progress, 0.0, 0.0001);
    XCTAssertFalse(session.isFinished);
    XCTAssertGreaterThan(session.activeEntities.count, 0);

    CSInputState input = CSInputStateMake();
    input.throttle = YES;
    for (NSInteger frame = 0; frame < 300; frame++) {
        [session stepWithInput:input dt:1.0 / 60.0];
    }

    XCTAssertGreaterThan(session.playerDistance, 500.0);
    XCTAssertGreaterThan(session.speed, 0.0);
    XCTAssertGreaterThan(session.progress, 0.0);
    XCTAssertEqualWithAccuracy(session.elapsed, 5.0, 0.02);

    NSArray<CSSessionEvent *> *events = [session drainEvents];
    XCTAssertNotNil(events);
    XCTAssertEqual([session drainEvents].count, 0);
    for (CSSessionEvent *event in events) {
        XCTAssertTrue(event.type >= CSGameEventPickup && event.type <= CSGameEventSlip);
        XCTAssertTrue(isfinite(event.screenPosition.x));
        XCTAssertTrue(isfinite(event.screenPosition.y));
    }

    for (CSGameEntity *entity in [session activeEntities]) {
        XCTAssertTrue(entity.active);
        XCTAssertGreaterThan(entity.radius, 0.0);
        XCTAssertTrue(entity.distance >= 0.0);
        XCTAssertTrue(entity.x >= 0.0 && entity.x <= 640.0);
    }

    CSRunResult *result = [session makeResult];
    XCTAssertEqual(result.levelID, 1);
    XCTAssertEqual(result.worldID, 1);
    XCTAssertEqual(result.levelName, session.level.name);
    XCTAssertEqualObjects(result.carID, session.car.carID);
    XCTAssertEqualObjects(result.difficultyName, @"Classic");
    XCTAssertFalse(result.completed);
    XCTAssertEqual(result.stars, 0);
    XCTAssertEqual(result.livesLeft, session.lives);
    XCTAssertGreaterThan(result.score, 0);
    XCTAssertGreaterThan(result.duration, 4.9);
}

- (void)testSessionFinishesOrFailsButAlwaysTerminates {
    CSGameSession *session = [self sessionForLevel:1 difficulty:CSDifficultyPresetChill runSeed:424242];
    NSInteger steps = 0;
    while (!session.isFinished && steps < 60000) {
        CSInputState input = CSInputStateMake();
        CGFloat center = [session.roadPath centerXAtDistance:session.playerDistance];
        CGFloat delta = session.playerX - center;
        if (delta > 6.0) input.steerLeft = YES;
        else if (delta < -6.0) input.steerRight = YES;
        input.throttle = YES;
        input.boostPressed = session.boostMeter >= 0.999;
        [session stepWithInput:input dt:1.0 / 60.0];
        steps++;
    }

    XCTAssertTrue(session.isFinished, @"session did not finish after %ld frames", (long)steps);
    XCTAssertTrue(session.isCompleted || session.isFailed);
    if (session.isCompleted) {
        XCTAssertGreaterThanOrEqual(session.progress, 0.999);
        XCTAssertGreaterThan(session.lives, 0);
    } else {
        XCTAssertEqual(session.lives, 0);
    }

    CSRunResult *result = [session makeResult];
    XCTAssertEqual(result.completed, session.isCompleted);
    XCTAssertEqual(result.livesLeft, session.lives);
    XCTAssertEqual(result.levelID, session.level.levelID);
    XCTAssertGreaterThanOrEqual(result.stars, 0);
    XCTAssertLessThanOrEqual(result.stars, 3);
    XCTAssertGreaterThan(result.score, 0);

    CSInputState input = CSInputStateMake();
    CGFloat distanceAtFinish = session.playerDistance;
    [session stepWithInput:input dt:1.0 / 60.0];
    XCTAssertEqualWithAccuracy(session.playerDistance, distanceAtFinish, 0.0001);
}

- (void)testEveryLevelBuildsAPlayableSession {
    NSError *error = nil;
    CSGameCatalog *catalog = CSLoadTestCatalog(&error);
    XCTAssertNotNil(catalog, @"catalog failed: %@", error);
    CSCar *car = catalog.cars.firstObject;
    CSDifficultySettings *difficulty = [CSDifficultySettings settingsForPreset:CSDifficultyPresetClassic];

    for (CSLevel *level in catalog.levels) {
        CSGameSession *session = [[CSGameSession alloc] initWithLevel:level
                                                                  car:car
                                                           difficulty:difficulty
                                                              runSeed:(uint64_t)(level.levelID * 7919 + 17)];
        XCTAssertNotNil(session, @"level %ld failed to create a session", (long)level.levelID);
        XCTAssertEqual(session.level.levelID, level.levelID);
        XCTAssertGreaterThan(session.lives, 0);
        XCTAssertGreaterThan(session.activeEntities.count, 0);
        XCTAssertTrue(isfinite([session.roadPath centerXAtDistance:0.0]));
        XCTAssertTrue(isfinite([session.roadPath centerXAtDistance:level.length * 0.5]));
        XCTAssertTrue(isfinite([session.roadPath centerXAtDistance:level.length]));

        for (NSInteger frame = 0; frame < 120 && !session.isFinished; frame++) {
            CSInputState input = CSInputStateMake();
            CGFloat center = [session.roadPath centerXAtDistance:session.playerDistance];
            CGFloat delta = session.playerX - center;
            if (delta > 6.0) input.steerLeft = YES;
            else if (delta < -6.0) input.steerRight = YES;
            input.throttle = YES;
            [session stepWithInput:input dt:1.0 / 60.0];
        }

        XCTAssertTrue(isfinite(session.playerX), @"level %ld produced a non-finite x", (long)level.levelID);
        XCTAssertTrue(isfinite(session.playerDistance), @"level %ld produced a non-finite distance", (long)level.levelID);
        XCTAssertTrue(isfinite(session.speed), @"level %ld produced a non-finite speed", (long)level.levelID);
        XCTAssertGreaterThanOrEqual(session.score, 0);
        XCTAssertLessThan(session.activeEntities.count, 400);
    }
}

- (void)testSessionIsDeterministicForASeed {
    CSGameSession *first = [self sessionForLevel:3 difficulty:CSDifficultyPresetSpicy runSeed:99];
    CSGameSession *second = [self sessionForLevel:3 difficulty:CSDifficultyPresetSpicy runSeed:99];

    CSInputState input = CSInputStateMake();
    input.throttle = YES;
    input.steerRight = YES;
    for (NSInteger frame = 0; frame < 600; frame++) {
        [first stepWithInput:input dt:1.0 / 60.0];
        [second stepWithInput:input dt:1.0 / 60.0];
    }

    XCTAssertEqualWithAccuracy(first.playerDistance, second.playerDistance, 0.0001);
    XCTAssertEqualWithAccuracy(first.playerX, second.playerX, 0.0001);
    XCTAssertEqualWithAccuracy(first.speed, second.speed, 0.0001);
    XCTAssertEqual(first.score, second.score);
    XCTAssertEqual(first.lives, second.lives);
    XCTAssertEqual(first.coins, second.coins);
    XCTAssertEqual(first.activeEntities.count, second.activeEntities.count);
}

@end
