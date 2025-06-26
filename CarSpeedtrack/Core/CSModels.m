#import "CSModels.h"

NSString *CSDifficultyDisplayName(CSDifficultyPreset preset) {
    switch (preset) {
        case CSDifficultyPresetChill: return @"Chill";
        case CSDifficultyPresetClassic: return @"Classic";
        case CSDifficultyPresetSpicy: return @"Spicy";
        case CSDifficultyPresetInsane: return @"Insane";
        case CSDifficultyPresetCustom: return @"Custom";
    }
    return @"Classic";
}

NSString *CSDifficultyPresetKey(CSDifficultyPreset preset) {
    switch (preset) {
        case CSDifficultyPresetChill: return @"chill";
        case CSDifficultyPresetClassic: return @"classic";
        case CSDifficultyPresetSpicy: return @"spicy";
        case CSDifficultyPresetInsane: return @"insane";
        case CSDifficultyPresetCustom: return @"custom";
    }
    return @"classic";
}

CSDifficultyPreset CSDifficultyPresetFromString(NSString *name) {
    if ([name isEqualToString:@"chill"]) return CSDifficultyPresetChill;
    if ([name isEqualToString:@"spicy"]) return CSDifficultyPresetSpicy;
    if ([name isEqualToString:@"insane"]) return CSDifficultyPresetInsane;
    if ([name isEqualToString:@"custom"]) return CSDifficultyPresetCustom;
    return CSDifficultyPresetClassic;
}

CSHazardKind CSHazardKindFromString(NSString *name) {
    if ([name isEqualToString:@"spike"]) return CSHazardKindSpike;
    if ([name isEqualToString:@"pothole"]) return CSHazardKindPothole;
    if ([name isEqualToString:@"jelly"]) return CSHazardKindJelly;
    if ([name isEqualToString:@"puddle"]) return CSHazardKindPuddle;
    if ([name isEqualToString:@"beachball"]) return CSHazardKindBeachball;
    if ([name isEqualToString:@"tumbleweed"]) return CSHazardKindTumbleweed;
    if ([name isEqualToString:@"asteroid"]) return CSHazardKindAsteroid;
    if ([name isEqualToString:@"snowball"]) return CSHazardKindSnowball;
    if ([name isEqualToString:@"ember"]) return CSHazardKindEmber;
    return CSHazardKindCone;
}

NSString *CSHazardAssetName(CSHazardKind kind, NSInteger frame) {
    switch (kind) {
        case CSHazardKindCone: return @"hazard_cone";
        case CSHazardKindSpike: return @"hazard_spike";
        case CSHazardKindPothole: return @"hazard_pothole";
        case CSHazardKindJelly: return @"hazard_jelly";
        case CSHazardKindPuddle: return @"hazard_puddle";
        case CSHazardKindBeachball: return [NSString stringWithFormat:@"hazard_beachball_%ld", (long)(frame & 1)];
        case CSHazardKindTumbleweed: return [NSString stringWithFormat:@"hazard_tumbleweed_%ld", (long)(frame & 1)];
        case CSHazardKindAsteroid: return [NSString stringWithFormat:@"hazard_asteroid_%ld", (long)(frame & 1)];
        case CSHazardKindSnowball: return [NSString stringWithFormat:@"hazard_snowball_%ld", (long)(frame & 1)];
        case CSHazardKindEmber: return [NSString stringWithFormat:@"hazard_ember_%ld", (long)(frame & 1)];
    }
    return @"hazard_cone";
}

CSMechanic CSMechanicFromString(NSString *name) {
    if ([name isEqualToString:@"slick"]) return CSMechanicSlick;
    if ([name isEqualToString:@"crosswind"]) return CSMechanicCrosswind;
    if ([name isEqualToString:@"traffic"]) return CSMechanicTraffic;
    if ([name isEqualToString:@"waves"]) return CSMechanicWaves;
    if ([name isEqualToString:@"lowgrip"]) return CSMechanicLowGrip;
    if ([name isEqualToString:@"ice"]) return CSMechanicIce;
    if ([name isEqualToString:@"bounce"]) return CSMechanicBounce;
    if ([name isEqualToString:@"aurora"]) return CSMechanicAurora;
    return CSMechanicWarmup;
}

@implementation CSWorld
- (instancetype)init {
    self = [super init];
    if (self) {
        _name = @"";
        _blurb = @"";
        _mechanic = @"warmup";
        _music = @"music_menu";
        _accentHex = @"#8EDB78";
        _ground = @"ground_1";
    }
    return self;
}
@end

@implementation CSLevel
- (instancetype)init {
    self = [super init];
    if (self) {
        _name = @"Level";
        _hazards = @[@"cone"];
        _mechanic = @"warmup";
        _ground = @"ground_1";
        _music = @"music_world_1";
    }
    return self;
}
- (NSString *)displayNumber {
    return [NSString stringWithFormat:@"%02ld", (long)self.levelID];
}
@end

@implementation CSCar
- (NSString *)assetPrefix {
    return [NSString stringWithFormat:@"car_%@", self.carID];
}
@end

@implementation CSDifficultySettings

+ (instancetype)defaultSettings {
    return [[self alloc] initWithPreset:CSDifficultyPresetClassic];
}

+ (instancetype)settingsForPreset:(CSDifficultyPreset)preset {
    return [[self alloc] initWithPreset:preset];
}

- (instancetype)initWithPreset:(CSDifficultyPreset)preset {
    self = [super init];
    if (self) {
        _preset = preset;
        _assist = NO;
        switch (preset) {
            case CSDifficultyPresetChill:
                _trafficFactor = 0.7;
                _hazardFactor = 0.7;
                _pickupFactor = 1.2;
                _trafficSpeedFactor = 0.9;
                _lives = 5;
                _assist = YES;
                break;
            case CSDifficultyPresetSpicy:
                _trafficFactor = 1.3;
                _hazardFactor = 1.3;
                _pickupFactor = 0.9;
                _trafficSpeedFactor = 1.1;
                _lives = 2;
                break;
            case CSDifficultyPresetInsane:
                _trafficFactor = 1.6;
                _hazardFactor = 1.6;
                _pickupFactor = 0.8;
                _trafficSpeedFactor = 1.2;
                _lives = 1;
                break;
            case CSDifficultyPresetCustom:
                _trafficFactor = 1.0;
                _hazardFactor = 1.0;
                _pickupFactor = 1.0;
                _trafficSpeedFactor = 1.0;
                _lives = 3;
                break;
            case CSDifficultyPresetClassic:
            default:
                _trafficFactor = 1.0;
                _hazardFactor = 1.0;
                _pickupFactor = 1.0;
                _trafficSpeedFactor = 1.0;
                _lives = 3;
                break;
        }
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    CSDifficultySettings *copy = [[[self class] allocWithZone:zone] init];
    copy.preset = self.preset;
    copy.trafficFactor = self.trafficFactor;
    copy.hazardFactor = self.hazardFactor;
    copy.pickupFactor = self.pickupFactor;
    copy.trafficSpeedFactor = self.trafficSpeedFactor;
    copy.lives = self.lives;
    copy.assist = self.assist;
    return copy;
}

- (NSString *)displayName {
    return CSDifficultyDisplayName(self.preset);
}

- (NSString *)shortDescription {
    if (self.preset == CSDifficultyPresetCustom) {
        return [NSString stringWithFormat:@"Custom - %ld lives", (long)self.lives];
    }
    return [NSString stringWithFormat:@"%@ - %ld lives", [self displayName], (long)self.lives];
}

- (CGFloat)scoreMultiplier {
    switch (self.preset) {
        case CSDifficultyPresetChill: return 0.8;
        case CSDifficultyPresetSpicy: return 1.35;
        case CSDifficultyPresetInsane: return 1.8;
        case CSDifficultyPresetCustom: {
            CGFloat difficulty = (self.trafficFactor + self.hazardFactor) * 0.5;
            CGFloat value = 0.75 + (difficulty - 0.7) * 0.75 + (3.0 - (CGFloat)self.lives) * 0.18;
            return MIN(2.0, MAX(0.65, value));
        }
        case CSDifficultyPresetClassic:
        default: return 1.0;
    }
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    return @{
        @"preset": CSDifficultyPresetKey(self.preset),
        @"traffic": @(self.trafficFactor),
        @"hazards": @(self.hazardFactor),
        @"pickups": @(self.pickupFactor),
        @"trafficSpeed": @(self.trafficSpeedFactor),
        @"lives": @(self.lives),
        @"assist": @(self.assist),
    };
}

+ (instancetype)settingsFromDictionary:(NSDictionary<NSString *, id> *)dictionary {
    CSDifficultyPreset preset = CSDifficultyPresetFromString(dictionary[@"preset"] ?: @"classic");
    CSDifficultySettings *settings = [[self alloc] initWithPreset:preset];
    if (preset == CSDifficultyPresetCustom) {
        if ([dictionary[@"traffic"] respondsToSelector:@selector(doubleValue)]) settings.trafficFactor = [dictionary[@"traffic"] doubleValue];
        if ([dictionary[@"hazards"] respondsToSelector:@selector(doubleValue)]) settings.hazardFactor = [dictionary[@"hazards"] doubleValue];
        if ([dictionary[@"pickups"] respondsToSelector:@selector(doubleValue)]) settings.pickupFactor = [dictionary[@"pickups"] doubleValue];
        if ([dictionary[@"trafficSpeed"] respondsToSelector:@selector(doubleValue)]) settings.trafficSpeedFactor = [dictionary[@"trafficSpeed"] doubleValue];
        if ([dictionary[@"lives"] respondsToSelector:@selector(integerValue)]) settings.lives = [dictionary[@"lives"] integerValue];
        if ([dictionary[@"assist"] respondsToSelector:@selector(boolValue)]) settings.assist = [dictionary[@"assist"] boolValue];
        settings.trafficFactor = MIN(1.8, MAX(0.5, settings.trafficFactor));
        settings.hazardFactor = MIN(1.8, MAX(0.5, settings.hazardFactor));
        settings.pickupFactor = MIN(1.5, MAX(0.5, settings.pickupFactor));
        settings.trafficSpeedFactor = MIN(1.5, MAX(0.7, settings.trafficSpeedFactor));
        settings.lives = MIN(5, MAX(1, settings.lives));
    }
    return settings;
}

@end

@implementation CSRunResult
- (instancetype)init {
    self = [super init];
    if (self) {
        _levelName = @"";
        _carID = @"sunny-bug";
        _difficultyName = @"Classic";
        _date = [NSDate date];
        _stars = 0;
        _score = 0;
    }
    return self;
}
@end
