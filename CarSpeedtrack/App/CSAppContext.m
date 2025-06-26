#import "CSAppContext.h"
#import "CSGameCatalog.h"
#import "CSSaveManager.h"
#import "CSAudioManager.h"
#import <AppKit/AppKit.h>

@implementation CSAppContext

+ (CSAppContext *)shared {
    static CSAppContext *context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [[CSAppContext alloc] initPrivate];
    });
    return context;
}

+ (void)bootstrap {
    (void)[self shared];
}

- (instancetype)initPrivate {
    self = [super init];
    if (!self) return nil;

    NSArray<NSString *> *arguments = [NSProcessInfo processInfo].arguments;
    BOOL noSave = [arguments containsObject:@"--no-save"];
    _debugging = [arguments containsObject:@"--debug"] || noSave;
    _showFPS = [arguments containsObject:@"--show-fps"];
    _skipCountdown = [arguments containsObject:@"--skip-countdown"];
    _unlockAll = [arguments containsObject:@"--unlock-all"];

    NSString *scene = [self valueForArgument:@"--scene" inArguments:arguments];
    _initialSceneName = scene ?: @"menu";
    NSString *level = [self valueForArgument:@"--level" inArguments:arguments];
    _initialLevelID = level.length ? MAX(1, MIN(100, level.integerValue)) : 0;
    _carOverride = [self valueForArgument:@"--car" inArguments:arguments];
    _snapshotPath = [self valueForArgument:@"--snapshot" inArguments:arguments];
    NSString *snapshotDelay = [self valueForArgument:@"--snapshot-delay" inArguments:arguments];
    _snapshotDelay = snapshotDelay.length ? MAX(0.2, snapshotDelay.doubleValue) : 0.9;

    NSError *error = nil;
    _catalog = [CSGameCatalog bundledCatalogWithError:&error];
    if (!_catalog) {
        NSLog(@"CarSpeedtrack: catalogue failed: %@", error.localizedDescription);
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"CarSpeedtrack could not start";
        alert.informativeText = error.localizedDescription ?: @"The generated level data is missing.";
        [alert runModal];
        exit(1);
    }

    NSURL *directory = nil;
    if (noSave) {
        directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"CarSpeedtrackDebug"]
                               isDirectory:YES];
    }
    _save = [[CSSaveManager alloc] initWithDirectory:directory];
    _audio = [[CSAudioManager alloc] initWithSaveManager:_save];

    NSString *difficulty = [self valueForArgument:@"--difficulty" inArguments:arguments];
    if (difficulty) {
        _difficultyOverride = [CSDifficultySettings settingsForPreset:CSDifficultyPresetFromString(difficulty)];
        [_save setDifficultySettings:_difficultyOverride];
    }
    if (noSave) {
        _unlockAll = YES;
    }
    if ([arguments containsObject:@"--mute"] && !_save.isMuted) {
        [_save setMuted:YES];
    }
    if ([arguments containsObject:@"--reduce-motion"]) {
        [_save setReducedMotion:YES];
    }
    [_audio reloadSettings];
    return self;
}

- (NSString *)valueForArgument:(NSString *)flag inArguments:(NSArray<NSString *> *)arguments {
    NSUInteger index = [arguments indexOfObject:flag];
    if (index == NSNotFound || index + 1 >= arguments.count) return nil;
    NSString *value = arguments[index + 1];
    return [value hasPrefix:@"--"] ? nil : value;
}

- (BOOL)isLevelUnlocked:(NSInteger)levelID {
    if (self.unlockAll) return YES;
    return levelID <= [self.save highestUnlockedLevel];
}

- (NSInteger)displayStars {
    return self.unlockAll ? 300 : [self.save totalStars];
}

- (CSDifficultySettings *)difficultyForNewRun {
    return self.difficultyOverride ?: [self.save difficultySettings];
}

- (NSString *)selectedCarID {
    return self.carOverride ?: [self.save selectedCarID];
}

- (CSCar *)selectedCar {
    return [self.catalog carForID:self.selectedCarID] ?: self.catalog.cars.firstObject;
}

- (void)setSelectedCarID:(NSString *)carID {
    self.carOverride = nil;
    [self.save setSelectedCarID:carID];
}

- (void)applyAudioSettings {
    [self.audio reloadSettings];
}

- (void)playClick {
    [self.audio playSFX:@"sfx_click"];
}

@end
