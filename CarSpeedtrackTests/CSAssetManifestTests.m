#import <XCTest/XCTest.h>
#import "CSTestSupport.h"
#import "CSGameCatalog.h"
#import "CSModels.h"

@interface CSAssetManifestTests : XCTestCase
@end

@implementation CSAssetManifestTests

- (NSSet<NSString *> *)assetNamesFromManifest:(NSDictionary *)manifest {
    NSMutableSet<NSString *> *names = [NSMutableSet set];
    for (NSDictionary *asset in manifest[@"assets"] ?: @[]) {
        if ([asset isKindOfClass:[NSDictionary class]] && [asset[@"name"] isKindOfClass:[NSString class]]) {
            [names addObject:asset[@"name"]];
        }
    }
    return names;
}

- (void)testArtManifestCoversGeneratedSprites {
    NSError *error = nil;
    NSDictionary *manifest = CSLoadTestJSON(@"art_manifest", &error);
    XCTAssertNotNil(manifest, @"%@", error);
    XCTAssertTrue([manifest[@"nearestFiltering"] boolValue]);

    NSArray *assets = manifest[@"assets"];
    XCTAssertGreaterThan(assets.count, 200);
    NSSet<NSString *> *names = [self assetNamesFromManifest:manifest];
    XCTAssertEqual(names.count, assets.count, @"duplicate asset names in manifest");

    CSGameCatalog *catalog = CSLoadTestCatalog(&error);
    XCTAssertNotNil(catalog, @"%@", error);

    for (CSCar *car in catalog.cars) {
        for (NSInteger frame = 0; frame < 4; frame++) {
            NSString *name = [NSString stringWithFormat:@"%@_%ld", car.assetPrefix, (long)frame];
            XCTAssertTrue([names containsObject:name], @"missing car frame %@", name);
        }
    }

    for (CSLevel *level in catalog.levels) {
        XCTAssertTrue([names containsObject:level.ground], @"missing ground %@", level.ground);
        for (NSString *hazardName in level.hazards) {
            CSHazardKind kind = CSHazardKindFromString(hazardName);
            for (NSInteger frame = 0; frame < 2; frame++) {
                NSString *asset = CSHazardAssetName(kind, frame);
                XCTAssertTrue([names containsObject:asset], @"missing hazard asset %@", asset);
            }
        }
    }

    for (NSInteger code = 32; code <= 126; code++) {
        NSString *glyph = [NSString stringWithFormat:@"glyph_%03ld", (long)code];
        XCTAssertTrue([names containsObject:glyph], @"missing glyph %@", glyph);
    }

    NSArray<NSString *> *required = @[@"bg_menu", @"bg_screen", @"logo_title", @"ui_panel",
                                      @"ui_panel_cream", @"ui_panel_dark", @"icon_star_full",
                                      @"icon_star_empty", @"icon_heart_full", @"icon_heart_empty",
                                      @"pickup_coin_0", @"pickup_gem", @"pickup_heart",
                                      @"pickup_shield", @"pickup_magnet", @"pickup_star",
                                      @"traffic_0", @"traffic_1", @"traffic_2", @"traffic_3",
                                      @"traffic_4"];
    for (NSString *name in required) {
        XCTAssertTrue([names containsObject:name], @"missing UI/entity asset %@", name);
    }
}

- (void)testFontMetricsAreComplete {
    NSError *error = nil;
    NSDictionary *font = CSLoadTestJSON(@"font", &error);
    XCTAssertNotNil(font, @"%@", error);
    XCTAssertEqual([font[@"cellW"] integerValue], 12);
    XCTAssertEqual([font[@"cellH"] integerValue], 20);
    XCTAssertEqual([font[@"advance"] integerValue], 9);
    XCTAssertEqual([font[@"lineHeight"] integerValue], 18);
    XCTAssertEqual([font[@"firstChar"] integerValue], 32);
    XCTAssertEqual([font[@"lastChar"] integerValue], 126);
}

- (void)testAudioManifestCoversEveryTrackUsedByTheCampaign {
    NSError *error = nil;
    NSDictionary *audio = CSLoadTestJSON(@"audio_manifest", &error);
    XCTAssertNotNil(audio, @"%@", error);
    XCTAssertEqual([audio[@"sampleRate"] integerValue], 44100);
    XCTAssertEqual([audio[@"channels"] integerValue], 1);

    NSMutableSet<NSString *> *music = [NSMutableSet set];
    for (NSDictionary *entry in audio[@"music"] ?: @[]) {
        [music addObject:entry[@"file"]];
    }
    NSMutableSet<NSString *> *sfx = [NSMutableSet set];
    for (NSDictionary *entry in audio[@"sfx"] ?: @[]) {
        [sfx addObject:entry[@"file"]];
    }

    XCTAssertTrue([music containsObject:@"music_menu"]);
    XCTAssertTrue([music containsObject:@"music_win"]);
    XCTAssertTrue([music containsObject:@"music_lose"]);
    for (NSString *name in @[@"sfx_click", @"sfx_hover", @"sfx_crash", @"sfx_finish",
                             @"sfx_unlock", @"sfx_boost", @"sfx_coin", @"engine_loop"]) {
        XCTAssertTrue([sfx containsObject:name], @"missing sfx %@", name);
    }

    CSGameCatalog *catalog = CSLoadTestCatalog(&error);
    XCTAssertNotNil(catalog, @"%@", error);
    for (CSWorld *world in catalog.worlds) {
        XCTAssertTrue([music containsObject:world.music], @"missing world music %@", world.music);
    }
    for (CSLevel *level in catalog.levels) {
        XCTAssertTrue([music containsObject:level.music], @"missing level music %@", level.music);
    }
}

@end
