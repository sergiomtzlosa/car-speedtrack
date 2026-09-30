#import "CSSaveManager.h"
#import <math.h>

static const NSInteger CSSaveVersion = 1;
static NSString *const CSSaveFileName = @"save.json";

static NSDictionary *CSDefaultProgress(void) {
    return @{
        @"highestUnlocked": @1,
        @"levels": @{},
    };
}

static NSDictionary *CSDefaultScores(void) {
    return @{
        @"bestByLevel": @{},
        @"topRuns": @[],
    };
}

static NSString *CSISOString(NSDate *date) {
    static NSISO8601DateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSISO8601DateFormatter new];
        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    return [formatter stringFromDate:date];
}

static NSDictionary *CSDefaultProfile(void) {
    return @{
        @"selectedCar": @"sunny-bug",
        @"createdAt": CSISOString([NSDate date]),
    };
}

static NSDictionary *CSDefaultSettings(void) {
    return @{
        @"master": @0.8,
        @"music": @0.7,
        @"sfx": @0.85,
        @"engine": @0.5,
        @"muted": @NO,
        @"reducedMotion": @NO,
        @"difficulty": [[CSDifficultySettings defaultSettings] dictionaryRepresentation],
    };
}

static NSMutableDictionary *CSMutableCopyOfDictionary(id object) {
    if ([object isKindOfClass:[NSDictionary class]]) {
        return [NSMutableDictionary dictionaryWithDictionary:object];
    }
    return [NSMutableDictionary dictionary];
}

static NSMutableDictionary *CSMutableDefaultState(void) {
    return [@{
        @"version": @(CSSaveVersion),
        @"profile": CSMutableCopyOfDictionary(CSDefaultProfile()),
        @"settings": CSMutableCopyOfDictionary(CSDefaultSettings()),
        @"progress": CSMutableCopyOfDictionary(CSDefaultProgress()),
        @"scores": CSMutableCopyOfDictionary(CSDefaultScores()),
    } mutableCopy];
}

@interface CSSaveManager ()
@property (nonatomic, readwrite) NSURL *saveURL;
@property (nonatomic, readwrite) NSMutableDictionary<NSString *, id> *state;
@property (nonatomic, strong) NSISO8601DateFormatter *dateFormatter;
@end

@implementation CSSaveManager

- (instancetype)initWithDirectory:(nullable NSURL *)directory {
    self = [super init];
    if (self) {
        NSURL *base = directory;
        if (!base) {
            NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                            inDomains:NSUserDomainMask];
            base = [urls.firstObject URLByAppendingPathComponent:@"CarSpeedtrack" isDirectory:YES];
        }
        [[NSFileManager defaultManager] createDirectoryAtURL:base
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:NULL];
        _saveURL = [base URLByAppendingPathComponent:CSSaveFileName isDirectory:NO];
        _dateFormatter = [NSISO8601DateFormatter new];
        _dateFormatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        [self load];
    }
    return self;
}

- (void)load {
    _state = CSMutableDefaultState();
    NSData *data = [NSData dataWithContentsOfURL:self.saveURL];
    NSDictionary *saved = nil;
    if (data.length > 0) {
        NSError *jsonError = nil;
        saved = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (![saved isKindOfClass:[NSDictionary class]]) {
            [self quarantineCorruptSave];
            saved = nil;
        }
    }

    NSInteger version = [saved[@"version"] integerValue];
    if (saved && version > CSSaveVersion) {
        [self quarantineCorruptSave];
        saved = nil;
    }

    if (saved) {
        // Merge section by section: future/missing sections fall back to defaults.
        NSMutableDictionary *profile = CSMutableCopyOfDictionary(_state[@"profile"]);
        [profile addEntriesFromDictionary:CSMutableCopyOfDictionary(saved[@"profile"])];
        _state[@"profile"] = profile;

        NSMutableDictionary *settings = CSMutableCopyOfDictionary(_state[@"settings"]);
        [settings addEntriesFromDictionary:CSMutableCopyOfDictionary(saved[@"settings"])];
        _state[@"settings"] = settings;

        NSMutableDictionary *progress = CSMutableCopyOfDictionary(_state[@"progress"]);
        [progress addEntriesFromDictionary:CSMutableCopyOfDictionary(saved[@"progress"])];
        _state[@"progress"] = progress;

        NSMutableDictionary *scores = CSMutableCopyOfDictionary(_state[@"scores"]);
        [scores addEntriesFromDictionary:CSMutableCopyOfDictionary(saved[@"scores"])];
        _state[@"scores"] = scores;
    }

    NSMutableDictionary *settings = _state[@"settings"];
    settings[@"master"] = @([self clampedVolume:[settings[@"master"] doubleValue]]);
    settings[@"music"] = @([self clampedVolume:[settings[@"music"] doubleValue]]);
    settings[@"sfx"] = @([self clampedVolume:[settings[@"sfx"] doubleValue]]);
    settings[@"engine"] = @([self clampedVolume:[settings[@"engine"] doubleValue]]);
    settings[@"muted"] = @([settings[@"muted"] boolValue]);
    settings[@"reducedMotion"] = @([settings[@"reducedMotion"] boolValue]);
    if (![settings[@"difficulty"] isKindOfClass:[NSDictionary class]]) {
        settings[@"difficulty"] = [[CSDifficultySettings defaultSettings] dictionaryRepresentation];
    }

    NSMutableDictionary *progress = _state[@"progress"];
    NSInteger unlocked = [progress[@"highestUnlocked"] integerValue];
    progress[@"highestUnlocked"] = @(MIN(100, MAX(1, unlocked)));
    if (![progress[@"levels"] isKindOfClass:[NSDictionary class]]) {
        progress[@"levels"] = @{};
    }
    if (![_state[@"scores"] isKindOfClass:[NSDictionary class]]) {
        _state[@"scores"] = [CSDefaultScores() mutableCopy];
    }
    _state[@"version"] = @(CSSaveVersion);
    if (!saved) {
        [self saveNow];
    }
}

- (void)quarantineCorruptSave {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:self.saveURL.path]) return;
    NSString *stamp = [@([[NSDate date] timeIntervalSince1970]) stringValue];
    NSURL *backup = [[self.saveURL URLByDeletingLastPathComponent]
        URLByAppendingPathComponent:[NSString stringWithFormat:@"save.corrupt-%@.json", stamp]];
    [fm moveItemAtURL:self.saveURL toURL:backup error:NULL];
}

- (CGFloat)clampedVolume:(CGFloat)value {
    if (!isfinite(value)) return 0.8;
    return MIN(1.0, MAX(0.0, value));
}

- (void)saveNow {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.state
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:&error];
    if (!data) {
        NSLog(@"CarSpeedtrack: could not serialize save: %@", error);
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:self.saveURL.path]) {
        NSURL *backup = [[self.saveURL URLByDeletingLastPathComponent]
            URLByAppendingPathComponent:@"save.bak.json"];
        [fm removeItemAtURL:backup error:NULL];
        [fm copyItemAtURL:self.saveURL toURL:backup error:NULL];
    }
    if (![data writeToURL:self.saveURL options:NSDataWritingAtomic error:&error]) {
        NSLog(@"CarSpeedtrack: save failed: %@", error);
    }
}

- (void)resetProgress {
    NSMutableDictionary *progress = [CSDefaultProgress() mutableCopy];
    _state[@"progress"] = progress;
    _state[@"scores"] = CSDefaultScores();
    _state[@"profile"] = CSDefaultProfile();
    [self saveNow];
}

- (void)resetEverything {
    _state = CSMutableDefaultState();
    [self saveNow];
}

#pragma mark - Settings

- (NSString *)selectedCarID {
    NSString *carID = _state[@"profile"][@"selectedCar"];
    return [carID isKindOfClass:[NSString class]] && carID.length > 0 ? carID : @"sunny-bug";
}

- (void)setSelectedCarID:(NSString *)carID {
    if (carID.length == 0) return;
    NSMutableDictionary *profile = CSMutableCopyOfDictionary(_state[@"profile"]);
    profile[@"selectedCar"] = carID;
    _state[@"profile"] = profile;
    [self saveNow];
}

- (CSDifficultySettings *)difficultySettings {
    NSDictionary *dict = _state[@"settings"][@"difficulty"];
    return [CSDifficultySettings settingsFromDictionary:dict ?: @{}];
}

- (void)setDifficultySettings:(CSDifficultySettings *)settings {
    NSMutableDictionary *settingsDict = CSMutableCopyOfDictionary(_state[@"settings"]);
    settingsDict[@"difficulty"] = [settings dictionaryRepresentation];
    _state[@"settings"] = settingsDict;
    [self saveNow];
}

- (CGFloat)volumeForKey:(NSString *)key {
    NSNumber *value = _state[@"settings"][key];
    return value ? [self clampedVolume:value.doubleValue] : 0.8;
}

- (void)setVolume:(CGFloat)value forKey:(NSString *)key {
    if (![key isKindOfClass:[NSString class]] || key.length == 0) return;
    NSMutableDictionary *settings = CSMutableCopyOfDictionary(_state[@"settings"]);
    settings[key] = @([self clampedVolume:value]);
    _state[@"settings"] = settings;
    [self saveNow];
}

- (BOOL)isMuted {
    return [_state[@"settings"][@"muted"] boolValue];
}

- (void)setMuted:(BOOL)muted {
    NSMutableDictionary *settings = CSMutableCopyOfDictionary(_state[@"settings"]);
    settings[@"muted"] = @(muted);
    _state[@"settings"] = settings;
    [self saveNow];
}

- (BOOL)reducedMotion {
    return [_state[@"settings"][@"reducedMotion"] boolValue];
}

- (void)setReducedMotion:(BOOL)reduced {
    NSMutableDictionary *settings = CSMutableCopyOfDictionary(_state[@"settings"]);
    settings[@"reducedMotion"] = @(reduced);
    _state[@"settings"] = settings;
    [self saveNow];
}

#pragma mark - Progress and scores

- (NSDictionary<NSString *, id> *)levelProgressForID:(NSInteger)levelID {
    NSDictionary *levels = _state[@"progress"][@"levels"];
    NSDictionary *entry = levels[[NSString stringWithFormat:@"%ld", (long)levelID]];
    return [entry isKindOfClass:[NSDictionary class]] ? entry : @{};
}

- (NSInteger)totalStars {
    NSDictionary *levels = _state[@"progress"][@"levels"];
    NSInteger total = 0;
    for (NSDictionary *entry in levels.allValues) {
        if ([entry isKindOfClass:[NSDictionary class]]) {
            total += MIN(3, MAX(0, [entry[@"stars"] integerValue]));
        }
    }
    return total;
}

- (NSInteger)highestUnlockedLevel {
    NSInteger value = [_state[@"progress"][@"highestUnlocked"] integerValue];
    return MIN(100, MAX(1, value));
}

- (NSInteger)nextLevelToPlay {
    // Start at the first level that has not been completed. This keeps the
    // Play button on level 1 even when a save has every level unlocked, and
    // still advances normally as levels are passed.
    for (NSInteger level = 1; level < 100; level++) {
        if (![self isLevelCompleted:level]) return level;
    }
    return 100;
}

- (BOOL)hasPlayedAnyRun {
    NSDictionary *levels = _state[@"progress"][@"levels"];
    if (![levels isKindOfClass:[NSDictionary class]]) return NO;
    for (NSDictionary *entry in levels.allValues) {
        if ([entry isKindOfClass:[NSDictionary class]] && [entry[@"plays"] integerValue] > 0) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isLevelCompleted:(NSInteger)levelID {
    return [[self levelProgressForID:levelID][@"completed"] boolValue];
}

- (NSInteger)starsForLevel:(NSInteger)levelID {
    return MIN(3, MAX(0, [[self levelProgressForID:levelID][@"stars"] integerValue]));
}

- (NSInteger)bestScoreForLevel:(NSInteger)levelID {
    return MAX(0, [[self levelProgressForID:levelID][@"bestScore"] integerValue]);
}

- (NSInteger)bestComboForLevel:(NSInteger)levelID {
    return MAX(0, [[self levelProgressForID:levelID][@"bestCombo"] integerValue]);
}

- (NSInteger)playCountForLevel:(NSInteger)levelID {
    return MAX(0, [[self levelProgressForID:levelID][@"plays"] integerValue]);
}

- (BOOL)isCarUnlocked:(CSCar *)car {
    return [self totalStars] >= car.unlockStars;
}

- (NSArray<NSDictionary<NSString *, id> *> *)topScoresForLevel:(NSInteger)levelID {
    NSArray *scores = _state[@"scores"][@"bestByLevel"][[NSString stringWithFormat:@"%ld", (long)levelID]];
    if (![scores isKindOfClass:[NSArray class]]) return @[];
    return scores;
}

- (NSArray<NSDictionary<NSString *, id> *> *)topRuns {
    NSArray *runs = _state[@"scores"][@"topRuns"];
    return [runs isKindOfClass:[NSArray class]] ? runs : @[];
}

- (CSRunResult *)recordResult:(CSRunResult *)result {
    NSInteger oldBest = [self bestScoreForLevel:result.levelID];
    result.newBest = result.score > oldBest;

    NSMutableDictionary *progress = CSMutableCopyOfDictionary(_state[@"progress"]);
    NSMutableDictionary *levels = CSMutableCopyOfDictionary(progress[@"levels"]);
    NSString *key = [NSString stringWithFormat:@"%ld", (long)result.levelID];
    NSMutableDictionary *entry = CSMutableCopyOfDictionary(levels[key]);
    entry[@"completed"] = @([entry[@"completed"] boolValue] || result.completed);
    entry[@"stars"] = @(MAX([entry[@"stars"] integerValue], MIN(3, MAX(0, result.stars))));
    entry[@"bestScore"] = @(MAX([entry[@"bestScore"] integerValue], MAX(0, result.score)));
    entry[@"bestCombo"] = @(MAX([entry[@"bestCombo"] integerValue], MAX(0, result.bestCombo)));
    entry[@"plays"] = @([entry[@"plays"] integerValue] + 1);
    if (result.completed && !result.tookDamage) {
        entry[@"bestClean"] = @YES;
    }
    levels[key] = entry;
    progress[@"levels"] = levels;
    if (result.completed) {
        NSInteger unlocked = MAX([progress[@"highestUnlocked"] integerValue], MIN(100, result.levelID + 1));
        progress[@"highestUnlocked"] = @(unlocked);
    }
    _state[@"progress"] = progress;

    NSMutableDictionary *scores = CSMutableCopyOfDictionary(_state[@"scores"]);
    NSMutableDictionary *byLevel = CSMutableCopyOfDictionary(scores[@"bestByLevel"]);
    NSMutableArray *levelScores = [NSMutableArray array];
    id existing = byLevel[key];
    if ([existing isKindOfClass:[NSArray class]]) [levelScores addObjectsFromArray:existing];
    NSDictionary *scoreEntry = @{
        @"levelID": @(result.levelID),
        @"levelName": result.levelName ?: @"",
        @"score": @(MAX(0, result.score)),
        @"coins": @(MAX(0, result.coins)),
        @"stars": @(MIN(3, MAX(0, result.stars))),
        @"combo": @(MAX(0, result.bestCombo)),
        @"completed": @(result.completed),
        @"difficulty": result.difficultyName ?: @"Classic",
        @"car": result.carID ?: @"sunny-bug",
        @"duration": @(MAX(0, result.duration)),
        @"date": [self.dateFormatter stringFromDate:result.date ?: [NSDate date]],
    };
    [levelScores addObject:scoreEntry];
    [levelScores sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSInteger sa = [a[@"score"] integerValue], sb = [b[@"score"] integerValue];
        if (sa != sb) return sa > sb ? NSOrderedAscending : NSOrderedDescending;
        return [a[@"date"] compare:b[@"date"]];
    }];
    if (levelScores.count > 10) {
        [levelScores removeObjectsInRange:NSMakeRange(10, levelScores.count - 10)];
    }
    byLevel[key] = levelScores;
    scores[@"bestByLevel"] = byLevel;

    NSMutableArray *topRuns = [NSMutableArray array];
    NSArray *savedRuns = scores[@"topRuns"];
    if ([savedRuns isKindOfClass:[NSArray class]]) [topRuns addObjectsFromArray:savedRuns];
    [topRuns addObject:scoreEntry];
    [topRuns sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSInteger sa = [a[@"score"] integerValue], sb = [b[@"score"] integerValue];
        if (sa != sb) return sa > sb ? NSOrderedAscending : NSOrderedDescending;
        return [a[@"date"] compare:b[@"date"]];
    }];
    if (topRuns.count > 50) {
        [topRuns removeObjectsInRange:NSMakeRange(50, topRuns.count - 50)];
    }
    scores[@"topRuns"] = topRuns;
    _state[@"scores"] = scores;
    [self saveNow];
    return result;
}

- (NSDictionary<NSString *, id> *)rawState {
    return [self.state copy];
}

@end
