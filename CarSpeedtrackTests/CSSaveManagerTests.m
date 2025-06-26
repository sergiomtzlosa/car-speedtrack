#import <XCTest/XCTest.h>
#import "CSTestSupport.h"
#import "CSGameCatalog.h"
#import "CSSaveManager.h"
#import "CSModels.h"

@interface CSSaveManagerTests : XCTestCase
@end

@implementation CSSaveManagerTests {
    NSURL *_directory;
    CSSaveManager *_save;
}

- (void)setUp {
    [super setUp];
    _directory = CSCreateTestDirectory();
    _save = [[CSSaveManager alloc] initWithDirectory:_directory];
}

- (void)tearDown {
    _save = nil;
    CSRemoveTestDirectory(_directory);
    _directory = nil;
    [super tearDown];
}

- (CSRunResult *)resultForLevel:(NSInteger)levelID
                          score:(NSInteger)score
                          stars:(NSInteger)stars
                      completed:(BOOL)completed {
    CSRunResult *result = [CSRunResult new];
    result.levelID = levelID;
    result.worldID = (levelID - 1) / 10 + 1;
    result.levelName = [NSString stringWithFormat:@"Level %ld", (long)levelID];
    result.score = score;
    result.stars = stars;
    result.completed = completed;
    result.coins = MAX(0, score / 100);
    result.bestCombo = MAX(1, score / 500);
    result.difficultyName = @"Classic";
    result.carID = @"sunny-bug";
    result.duration = 60.0;
    return result;
}

- (void)testDefaultsAndSettingsRoundTrip {
    XCTAssertNotNil(_save.saveURL);
    XCTAssertEqualObjects(_save.selectedCarID, @"sunny-bug");
    XCTAssertEqual(_save.highestUnlockedLevel, 1);
    XCTAssertEqual(_save.nextLevelToPlay, 1);
    XCTAssertEqual(_save.totalStars, 0);
    XCTAssertEqual([_save difficultySettings].preset, CSDifficultyPresetClassic);
    XCTAssertEqualWithAccuracy([_save volumeForKey:@"master"], 0.8, 0.0001);
    XCTAssertEqualWithAccuracy([_save volumeForKey:@"music"], 0.7, 0.0001);
    XCTAssertEqualWithAccuracy([_save volumeForKey:@"sfx"], 0.85, 0.0001);
    XCTAssertEqualWithAccuracy([_save volumeForKey:@"engine"], 0.5, 0.0001);

    [_save setVolume:2.0 forKey:@"master"];
    [_save setVolume:-1.0 forKey:@"sfx"];
    XCTAssertEqualWithAccuracy([_save volumeForKey:@"master"], 1.0, 0.0001);
    XCTAssertEqualWithAccuracy([_save volumeForKey:@"sfx"], 0.0, 0.0001);

    [_save setMuted:YES];
    [_save setReducedMotion:YES];
    [_save setSelectedCarID:@"sunny-bug"];
    CSDifficultySettings *custom = [CSDifficultySettings settingsForPreset:CSDifficultyPresetCustom];
    custom.trafficFactor = 1.6;
    custom.lives = 4;
    [_save setDifficultySettings:custom];

    CSSaveManager *reloaded = [[CSSaveManager alloc] initWithDirectory:_directory];
    XCTAssertTrue(reloaded.isMuted);
    XCTAssertTrue(reloaded.reducedMotion);
    XCTAssertEqualWithAccuracy([reloaded volumeForKey:@"master"], 1.0, 0.0001);
    XCTAssertEqualWithAccuracy([reloaded volumeForKey:@"sfx"], 0.0, 0.0001);
    XCTAssertEqual([reloaded difficultySettings].preset, CSDifficultyPresetCustom);
    XCTAssertEqual([reloaded difficultySettings].lives, 4);
    XCTAssertEqualWithAccuracy([reloaded difficultySettings].trafficFactor, 1.6, 0.0001);
}

- (void)testRecordingResultsUpdatesProgressAndScores {
    CSRunResult *first = [self resultForLevel:1 score:5000 stars:3 completed:YES];
    CSRunResult *recorded = [_save recordResult:first];
    XCTAssertEqual(recorded, first);
    XCTAssertTrue(recorded.newBest);
    XCTAssertTrue([_save isLevelCompleted:1]);
    XCTAssertEqual([_save starsForLevel:1], 3);
    XCTAssertEqual([_save bestScoreForLevel:1], 5000);
    XCTAssertEqual([_save playCountForLevel:1], 1);
    XCTAssertEqual(_save.totalStars, 3);
    XCTAssertEqual(_save.highestUnlockedLevel, 2);
    XCTAssertEqual(_save.nextLevelToPlay, 2);

    CSRunResult *lower = [self resultForLevel:1 score:1000 stars:1 completed:YES];
    [_save recordResult:lower];
    XCTAssertFalse(lower.newBest);
    XCTAssertEqual([_save bestScoreForLevel:1], 5000);
    XCTAssertEqual([_save starsForLevel:1], 3);
    XCTAssertEqual([_save playCountForLevel:1], 2);

    CSRunResult *second = [self resultForLevel:2 score:3200 stars:2 completed:YES];
    [_save recordResult:second];
    XCTAssertEqual(_save.totalStars, 5);
    XCTAssertEqual(_save.highestUnlockedLevel, 3);
    XCTAssertEqual(_save.nextLevelToPlay, 3);

    CSRunResult *failed = [self resultForLevel:3 score:700 stars:0 completed:NO];
    [_save recordResult:failed];
    XCTAssertFalse([_save isLevelCompleted:3]);
    XCTAssertEqual([_save playCountForLevel:3], 1);
    XCTAssertEqual(_save.highestUnlockedLevel, 3);

    NSArray<NSDictionary *> *scores = [_save topScoresForLevel:1];
    XCTAssertEqual(scores.count, 2);
    XCTAssertEqual([scores.firstObject[@"score"] integerValue], 5000);
    XCTAssertEqual([_save topRuns].count, 4);

    CSCar *locked = [CSCar new];
    locked.unlockStars = 99;
    CSCar *free = [CSCar new];
    free.unlockStars = 0;
    XCTAssertFalse([_save isCarUnlocked:locked]);
    XCTAssertTrue([_save isCarUnlocked:free]);
}

- (void)testTopScoresAreCappedAtTen {
    for (NSInteger i = 1; i <= 12; i++) {
        CSRunResult *result = [self resultForLevel:4 score:i * 100 stars:1 completed:YES];
        [_save recordResult:result];
    }
    NSArray<NSDictionary *> *scores = [_save topScoresForLevel:4];
    XCTAssertEqual(scores.count, 10);
    XCTAssertEqual([scores.firstObject[@"score"] integerValue], 1200);
    XCTAssertEqual([scores.lastObject[@"score"] integerValue], 300);
    XCTAssertEqual([_save playCountForLevel:4], 12);
}

- (void)testResetProgressKeepsSettingsButClearsCampaign {
    [_save recordResult:[self resultForLevel:1 score:4000 stars:3 completed:YES]];
    [_save setSelectedCarID:@"sunny-bug"];
    CSDifficultySettings *custom = [CSDifficultySettings settingsForPreset:CSDifficultyPresetCustom];
    custom.lives = 2;
    [_save setDifficultySettings:custom];

    [_save resetProgress];
    XCTAssertEqual(_save.totalStars, 0);
    XCTAssertEqual(_save.highestUnlockedLevel, 1);
    XCTAssertEqual([_save bestScoreForLevel:1], 0);
    XCTAssertFalse([_save isLevelCompleted:1]);
    XCTAssertEqual([_save topRuns].count, 0);
    XCTAssertEqualObjects(_save.selectedCarID, @"sunny-bug");
    XCTAssertEqual([_save difficultySettings].preset, CSDifficultyPresetCustom);
    XCTAssertEqual([_save difficultySettings].lives, 2);

    [_save resetEverything];
    XCTAssertEqual([_save difficultySettings].preset, CSDifficultyPresetClassic);
    XCTAssertEqualWithAccuracy([_save volumeForKey:@"master"], 0.8, 0.0001);
}

- (void)testCorruptSaveIsQuarantinedAndReplacedWithDefaults {
    [_save saveNow];
    NSData *garbage = [@"{not valid json" dataUsingEncoding:NSUTF8StringEncoding];
    [garbage writeToURL:_save.saveURL options:NSDataWritingAtomic error:NULL];

    CSSaveManager *reloaded = [[CSSaveManager alloc] initWithDirectory:_directory];
    XCTAssertEqual(reloaded.totalStars, 0);
    XCTAssertEqual(reloaded.highestUnlockedLevel, 1);
    XCTAssertEqualObjects(reloaded.selectedCarID, @"sunny-bug");

    NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_directory.path
                                                                                     error:NULL];
    BOOL foundQuarantine = NO;
    for (NSString *file in files) {
        if ([file hasPrefix:@"save.corrupt-"]) foundQuarantine = YES;
    }
    XCTAssertTrue(foundQuarantine);
}

@end
