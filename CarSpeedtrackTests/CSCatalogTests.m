#import <XCTest/XCTest.h>
#import "CSTestSupport.h"
#import "CSGameCatalog.h"
#import "CSModels.h"

@interface CSCatalogTests : XCTestCase
@end

@implementation CSCatalogTests

- (void)testCatalogLoadsCompleteCampaign {
    NSError *error = nil;
    CSGameCatalog *catalog = CSLoadTestCatalog(&error);
    XCTAssertNotNil(catalog, @"catalog failed: %@", error);

    XCTAssertEqual(catalog.levels.count, 100);
    XCTAssertEqual(catalog.worlds.count, 10);
    XCTAssertEqual(catalog.cars.count, 8);
    XCTAssertEqual(catalog.totalStarsAvailable, 300);

    for (NSInteger levelID = 1; levelID <= 100; levelID++) {
        CSLevel *level = [catalog levelForID:levelID];
        XCTAssertNotNil(level, @"missing level %ld", (long)levelID);
        XCTAssertEqual(level.levelID, levelID);
        XCTAssertEqual(level.worldID, (levelID - 1) / 10 + 1);
        XCTAssertTrue(level.name.length > 0);
        XCTAssertTrue(level.mechanic.length > 0);
        XCTAssertTrue(level.ground.length > 0);
        XCTAssertTrue(level.music.length > 0);
        XCTAssertGreaterThan(level.length, 1000.0);
        XCTAssertGreaterThanOrEqual(level.roadWidth, 300.0);
        XCTAssertGreaterThanOrEqual(level.curviness, 0.0);
        XCTAssertLessThanOrEqual(level.curviness, 1.0);
        XCTAssertGreaterThanOrEqual(level.baseLives, 1);
        XCTAssertGreaterThan(level.star3, level.star2);
        XCTAssertTrue(level.hazards.count > 0);
    }

    for (NSInteger worldID = 1; worldID <= 10; worldID++) {
        CSWorld *world = [catalog worldForID:worldID];
        XCTAssertNotNil(world);
        XCTAssertEqual(world.worldID, worldID);
        XCTAssertTrue(world.name.length > 0);
        XCTAssertTrue(world.blurb.length > 0);
        XCTAssertTrue(world.accentHex.length == 7);
        XCTAssertEqual([catalog levelsInWorld:worldID].count, 10);
    }

    XCTAssertNil([catalog levelForID:0]);
    XCTAssertNil([catalog levelForID:101]);
    XCTAssertNil([catalog worldForID:11]);
    XCTAssertEqual([catalog levelAfter:[catalog levelForID:1]], [catalog levelForID:2]);
    XCTAssertEqual([catalog levelAfter:[catalog levelForID:99]], [catalog levelForID:100]);
    XCTAssertNil([catalog levelAfter:[catalog levelForID:100]]);
}

- (void)testCarsAreBalancedAndUnlockedByStars {
    NSError *error = nil;
    CSGameCatalog *catalog = CSLoadTestCatalog(&error);
    XCTAssertNotNil(catalog, @"catalog failed: %@", error);

    NSInteger previousUnlock = -1;
    CSCar *previousCar = nil;
    for (CSCar *car in catalog.cars) {
        XCTAssertTrue(car.carID.length > 0);
        XCTAssertTrue(car.name.length > 0);
        XCTAssertTrue(car.tagline.length > 0);
        XCTAssertGreaterThanOrEqual(car.speed, 1);
        XCTAssertLessThanOrEqual(car.speed, 5);
        XCTAssertGreaterThanOrEqual(car.acceleration, 1);
        XCTAssertLessThanOrEqual(car.acceleration, 5);
        XCTAssertGreaterThanOrEqual(car.grip, 1);
        XCTAssertLessThanOrEqual(car.grip, 5);
        XCTAssertGreaterThanOrEqual(car.unlockStars, previousUnlock);
        XCTAssertEqualObjects(car.assetPrefix, ([NSString stringWithFormat:@"car_%@", car.carID]));
        previousUnlock = car.unlockStars;
        previousCar = car;
    }
    XCTAssertEqual(catalog.cars.firstObject.unlockStars, 0);
    XCTAssertEqualObjects([catalog carForID:catalog.cars.firstObject.carID], catalog.cars.firstObject);
    XCTAssertNil([catalog carForID:@"not-a-car"]);

    XCTAssertGreaterThanOrEqual([catalog carsUnlockedAtStars:0].count, 1);
    XCTAssertEqual([catalog carsUnlockedAtStars:300].count, catalog.cars.count);
    XCTAssertTrue([catalog isCarUnlocked:catalog.cars.firstObject atStars:0]);
    XCTAssertTrue([catalog isCarUnlocked:previousCar atStars:300]);
}

#pragma mark - Difficulty

- (void)testDifficultyPresetsRoundTripAndScale {
    NSArray<NSString *> *keys = @[@"chill", @"classic", @"spicy", @"insane", @"custom"];
    for (NSString *key in keys) {
        CSDifficultyPreset preset = CSDifficultyPresetFromString(key);
        XCTAssertEqualObjects(CSDifficultyPresetKey(preset), key);
        XCTAssertTrue(CSDifficultyDisplayName(preset).length > 0);
    }
    XCTAssertEqual(CSDifficultyPresetFromString(@"nonsense"), CSDifficultyPresetClassic);

    CSDifficultySettings *chill = [CSDifficultySettings settingsForPreset:CSDifficultyPresetChill];
    CSDifficultySettings *classic = [CSDifficultySettings settingsForPreset:CSDifficultyPresetClassic];
    CSDifficultySettings *spicy = [CSDifficultySettings settingsForPreset:CSDifficultyPresetSpicy];
    CSDifficultySettings *insane = [CSDifficultySettings settingsForPreset:CSDifficultyPresetInsane];

    XCTAssertEqual(chill.lives, 5);
    XCTAssertTrue(chill.assist);
    XCTAssertEqual(classic.lives, 3);
    XCTAssertFalse(classic.assist);
    XCTAssertEqual(spicy.lives, 2);
    XCTAssertEqual(insane.lives, 1);

    XCTAssertLessThan(chill.scoreMultiplier, classic.scoreMultiplier);
    XCTAssertGreaterThan(spicy.scoreMultiplier, classic.scoreMultiplier);
    XCTAssertGreaterThan(insane.scoreMultiplier, spicy.scoreMultiplier);
    XCTAssertTrue([classic.shortDescription containsString:@"3"]);

    CSDifficultySettings *copy = [chill copy];
    copy.lives = 2;
    XCTAssertEqual(chill.lives, 5);
    XCTAssertEqual(copy.lives, 2);
}

- (void)testCustomDifficultySerializationAndClamping {
    CSDifficultySettings *custom = [CSDifficultySettings settingsForPreset:CSDifficultyPresetCustom];
    custom.trafficFactor = 1.7;
    custom.hazardFactor = 0.6;
    custom.pickupFactor = 1.4;
    custom.trafficSpeedFactor = 1.3;
    custom.lives = 5;
    custom.assist = YES;

    NSDictionary *dictionary = [custom dictionaryRepresentation];
    CSDifficultySettings *restored = [CSDifficultySettings settingsFromDictionary:dictionary];
    XCTAssertEqual(restored.preset, CSDifficultyPresetCustom);
    XCTAssertEqualWithAccuracy(restored.trafficFactor, 1.7, 0.0001);
    XCTAssertEqualWithAccuracy(restored.hazardFactor, 0.6, 0.0001);
    XCTAssertEqualWithAccuracy(restored.pickupFactor, 1.4, 0.0001);
    XCTAssertEqualWithAccuracy(restored.trafficSpeedFactor, 1.3, 0.0001);
    XCTAssertEqual(restored.lives, 5);
    XCTAssertTrue(restored.assist);

    NSDictionary *outOfRange = @{
        @"preset": @"custom",
        @"traffic": @99,
        @"hazards": @(-5),
        @"pickups": @0,
        @"trafficSpeed": @99,
        @"lives": @99,
        @"assist": @YES,
    };
    CSDifficultySettings *clamped = [CSDifficultySettings settingsFromDictionary:outOfRange];
    XCTAssertEqualWithAccuracy(clamped.trafficFactor, 1.8, 0.0001);
    XCTAssertEqualWithAccuracy(clamped.hazardFactor, 0.5, 0.0001);
    XCTAssertEqualWithAccuracy(clamped.pickupFactor, 0.5, 0.0001);
    XCTAssertEqualWithAccuracy(clamped.trafficSpeedFactor, 1.5, 0.0001);
    XCTAssertEqual(clamped.lives, 5);
    XCTAssertTrue(clamped.assist);

    CSDifficultySettings *fallback = [CSDifficultySettings settingsFromDictionary:
        @{@"preset": @"unknown-preset"}];
    XCTAssertEqual(fallback.preset, CSDifficultyPresetClassic);
    XCTAssertEqual(fallback.lives, 3);
}

@end
