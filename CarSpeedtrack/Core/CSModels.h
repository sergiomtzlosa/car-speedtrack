#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CSDifficultyPreset) {
    CSDifficultyPresetChill = 0,
    CSDifficultyPresetClassic = 1,
    CSDifficultyPresetSpicy = 2,
    CSDifficultyPresetInsane = 3,
    CSDifficultyPresetCustom = 4,
};

typedef NS_ENUM(NSInteger, CSEntityKind) {
    CSEntityKindTraffic = 0,
    CSEntityKindHazard = 1,
    CSEntityKindPickup = 2,
};

typedef NS_ENUM(NSInteger, CSHazardKind) {
    CSHazardKindCone = 0,
    CSHazardKindSpike = 1,
    CSHazardKindPothole = 2,
    CSHazardKindJelly = 3,
    CSHazardKindPuddle = 4,
    CSHazardKindBeachball = 5,
    CSHazardKindTumbleweed = 6,
    CSHazardKindAsteroid = 7,
    CSHazardKindSnowball = 8,
    CSHazardKindEmber = 9,
};

typedef NS_ENUM(NSInteger, CSPickupKind) {
    CSPickupKindCoin = 0,
    CSPickupKindGem = 1,
    CSPickupKindHeart = 2,
    CSPickupKindShield = 3,
    CSPickupKindMagnet = 4,
    CSPickupKindStar = 5,
};

typedef NS_ENUM(NSInteger, CSGameEventType) {
    CSGameEventPickup = 0,
    CSGameEventHit = 1,
    CSGameEventNearMiss = 2,
    CSGameEventLifeGained = 3,
    CSGameEventShieldAbsorbed = 4,
    CSGameEventBoostStart = 5,
    CSGameEventFinish = 6,
    CSGameEventFail = 7,
    CSGameEventSlip = 8,
};

typedef NS_ENUM(NSInteger, CSMechanic) {
    CSMechanicWarmup = 0,
    CSMechanicSlick,
    CSMechanicCrosswind,
    CSMechanicTraffic,
    CSMechanicWaves,
    CSMechanicLowGrip,
    CSMechanicIce,
    CSMechanicBounce,
    CSMechanicAurora,
};

FOUNDATION_EXPORT NSString *CSDifficultyDisplayName(CSDifficultyPreset preset);
FOUNDATION_EXPORT CSDifficultyPreset CSDifficultyPresetFromString(NSString *name);
FOUNDATION_EXPORT NSString *CSDifficultyPresetKey(CSDifficultyPreset preset);
FOUNDATION_EXPORT CSHazardKind CSHazardKindFromString(NSString *name);
FOUNDATION_EXPORT NSString *CSHazardAssetName(CSHazardKind kind, NSInteger frame);
FOUNDATION_EXPORT CSMechanic CSMechanicFromString(NSString *name);

@interface CSWorld : NSObject
@property (nonatomic) NSInteger worldID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *blurb;
@property (nonatomic, copy) NSString *mechanic;
@property (nonatomic, copy) NSString *music;
@property (nonatomic, copy) NSString *accentHex;
@property (nonatomic, copy) NSString *ground;
@end

@interface CSLevel : NSObject
@property (nonatomic) NSInteger levelID;
@property (nonatomic) NSInteger worldID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) uint64_t seed;
@property (nonatomic) CGFloat length;
@property (nonatomic) CGFloat roadWidth;
@property (nonatomic) CGFloat curviness;
@property (nonatomic) CGFloat trafficDensity;
@property (nonatomic) CGFloat hazardDensity;
@property (nonatomic) CGFloat pickupDensity;
@property (nonatomic) CGFloat trafficSpeed;
@property (nonatomic) NSInteger baseLives;
@property (nonatomic) NSInteger star2;
@property (nonatomic) NSInteger star3;
@property (nonatomic, copy) NSArray<NSString *> *hazards;
@property (nonatomic, copy) NSString *mechanic;
@property (nonatomic, copy) NSString *ground;
@property (nonatomic, copy) NSString *music;
@property (nonatomic, copy, readonly) NSString *displayNumber;
@end

@interface CSCar : NSObject
@property (nonatomic, copy) NSString *carID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *tagline;
@property (nonatomic) NSInteger speed;
@property (nonatomic) NSInteger acceleration;
@property (nonatomic) NSInteger grip;
@property (nonatomic) NSInteger unlockStars;
@property (nonatomic, copy, readonly) NSString *assetPrefix;
@end

@interface CSDifficultySettings : NSObject <NSCopying>
@property (nonatomic) CSDifficultyPreset preset;
@property (nonatomic) CGFloat trafficFactor;
@property (nonatomic) CGFloat hazardFactor;
@property (nonatomic) CGFloat pickupFactor;
@property (nonatomic) CGFloat trafficSpeedFactor;
@property (nonatomic) NSInteger lives;
@property (nonatomic) BOOL assist;

+ (instancetype)defaultSettings;
+ (instancetype)settingsForPreset:(CSDifficultyPreset)preset;
- (instancetype)initWithPreset:(CSDifficultyPreset)preset;
- (NSString *)displayName;
- (NSString *)shortDescription;
- (CGFloat)scoreMultiplier;
- (NSDictionary<NSString *, id> *)dictionaryRepresentation;
+ (instancetype)settingsFromDictionary:(NSDictionary<NSString *, id> *)dictionary;
@end

@interface CSRunResult : NSObject
@property (nonatomic) NSInteger levelID;
@property (nonatomic) NSInteger worldID;
@property (nonatomic, copy) NSString *levelName;
@property (nonatomic) NSInteger score;
@property (nonatomic) NSInteger coins;
@property (nonatomic) NSInteger stars;
@property (nonatomic) NSInteger livesLeft;
@property (nonatomic) NSInteger bestCombo;
@property (nonatomic) BOOL completed;
@property (nonatomic) BOOL tookDamage;
@property (nonatomic) BOOL newBest;
@property (nonatomic, copy) NSString *carID;
@property (nonatomic, copy) NSString *difficultyName;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic, strong) NSDate *date;
@end

NS_ASSUME_NONNULL_END
