#import "CSGameCatalog.h"

@interface CSGameCatalog ()
@property (nonatomic, copy) NSDictionary<NSNumber *, CSLevel *> *levelMap;
@property (nonatomic, copy) NSDictionary<NSNumber *, CSWorld *> *worldMap;
@property (nonatomic, copy) NSDictionary<NSString *, CSCar *> *carMap;
@end

static NSError *CSCatalogError(NSString *message) {
    return [NSError errorWithDomain:@"CarSpeedtrack.Catalog"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation CSGameCatalog

+ (nullable instancetype)bundledCatalogWithError:(NSError **)error {
    NSURL *levels = [[NSBundle mainBundle] URLForResource:@"levels" withExtension:@"json" subdirectory:@"Data"];
    NSURL *cars = [[NSBundle mainBundle] URLForResource:@"cars" withExtension:@"json" subdirectory:@"Data"];
    if (!levels) {
        levels = [[NSBundle mainBundle] URLForResource:@"levels" withExtension:@"json"];
    }
    if (!cars) {
        cars = [[NSBundle mainBundle] URLForResource:@"cars" withExtension:@"json"];
    }
    if (!levels || !cars) {
        if (error) *error = CSCatalogError(@"The level and car data are missing from the app bundle.");
        return nil;
    }
    return [[self alloc] initWithLevelsURL:levels carsURL:cars error:error];
}

- (nullable instancetype)initWithLevelsURL:(NSURL *)levelsURL
                                   carsURL:(NSURL *)carsURL
                                     error:(NSError **)error {
    self = [super init];
    if (!self) return nil;

    NSError *readError = nil;
    NSData *levelsData = [NSData dataWithContentsOfURL:levelsURL options:0 error:&readError];
    NSData *carsData = [NSData dataWithContentsOfURL:carsURL options:0 error:&readError];
    if (!levelsData || !carsData) {
        if (error) *error = readError ?: CSCatalogError(@"Could not read game data.");
        return nil;
    }

    NSDictionary *levelPayload = [NSJSONSerialization JSONObjectWithData:levelsData options:0 error:&readError];
    NSDictionary *carPayload = [NSJSONSerialization JSONObjectWithData:carsData options:0 error:&readError];
    if (![levelPayload isKindOfClass:[NSDictionary class]] || ![carPayload isKindOfClass:[NSDictionary class]]) {
        if (error) *error = readError ?: CSCatalogError(@"Game data is not a JSON object.");
        return nil;
    }

    NSMutableArray<CSWorld *> *worlds = [NSMutableArray array];
    NSMutableDictionary<NSNumber *, CSWorld *> *worldMap = [NSMutableDictionary dictionary];
    for (NSDictionary *dict in levelPayload[@"worlds"] ?: @[]) {
        if (![dict isKindOfClass:[NSDictionary class]]) continue;
        CSWorld *world = [CSWorld new];
        world.worldID = [dict[@"id"] integerValue];
        world.name = [dict[@"name"] isKindOfClass:[NSString class]] ? dict[@"name"] : @"World";
        world.blurb = dict[@"blurb"] ?: @"";
        world.mechanic = dict[@"mechanic"] ?: @"warmup";
        world.music = dict[@"music"] ?: @"music_menu";
        world.accentHex = dict[@"accent"] ?: @"#8EDB78";
        world.ground = dict[@"ground"] ?: [NSString stringWithFormat:@"ground_%ld", (long)world.worldID];
        [worlds addObject:world];
        worldMap[@(world.worldID)] = world;
    }

    NSMutableArray<CSLevel *> *levels = [NSMutableArray array];
    NSMutableDictionary<NSNumber *, CSLevel *> *levelMap = [NSMutableDictionary dictionary];
    for (NSDictionary *dict in levelPayload[@"levels"] ?: @[]) {
        if (![dict isKindOfClass:[NSDictionary class]]) continue;
        CSLevel *level = [CSLevel new];
        level.levelID = [dict[@"id"] integerValue];
        level.worldID = [dict[@"world"] integerValue];
        level.name = dict[@"name"] ?: @"Level";
        level.seed = [dict[@"seed"] unsignedLongLongValue];
        level.length = [dict[@"length"] doubleValue];
        level.roadWidth = [dict[@"roadWidth"] doubleValue];
        level.curviness = [dict[@"curviness"] doubleValue];
        level.trafficDensity = [dict[@"trafficDensity"] doubleValue];
        level.hazardDensity = [dict[@"hazardDensity"] doubleValue];
        level.pickupDensity = [dict[@"pickupDensity"] doubleValue];
        level.trafficSpeed = [dict[@"trafficSpeed"] doubleValue];
        level.baseLives = [dict[@"baseLives"] integerValue] ?: 3;
        level.star2 = [dict[@"star2"] integerValue];
        level.star3 = [dict[@"star3"] integerValue];
        NSMutableArray<NSString *> *hazards = [NSMutableArray array];
        for (id hazard in dict[@"hazards"] ?: @[]) {
            if ([hazard isKindOfClass:[NSString class]]) [hazards addObject:hazard];
        }
        level.hazards = hazards;
        level.mechanic = dict[@"mechanic"] ?: @"warmup";
        level.ground = dict[@"ground"] ?: @"ground_1";
        level.music = dict[@"music"] ?: @"music_world_1";
        if (level.levelID > 0 && level.length > 0) {
            [levels addObject:level];
            levelMap[@(level.levelID)] = level;
        }
    }
    [levels sortUsingComparator:^NSComparisonResult(CSLevel *a, CSLevel *b) {
        return a.levelID < b.levelID ? NSOrderedAscending : (a.levelID > b.levelID ? NSOrderedDescending : NSOrderedSame);
    }];
    [worlds sortUsingComparator:^NSComparisonResult(CSWorld *a, CSWorld *b) {
        return a.worldID < b.worldID ? NSOrderedAscending : (a.worldID > b.worldID ? NSOrderedDescending : NSOrderedSame);
    }];

    NSMutableArray<CSCar *> *cars = [NSMutableArray array];
    NSMutableDictionary<NSString *, CSCar *> *carMap = [NSMutableDictionary dictionary];
    for (NSDictionary *dict in carPayload[@"cars"] ?: @[]) {
        if (![dict isKindOfClass:[NSDictionary class]]) continue;
        CSCar *car = [CSCar new];
        car.carID = dict[@"id"] ?: @"";
        car.name = dict[@"name"] ?: @"Car";
        car.tagline = dict[@"tagline"] ?: @"";
        car.speed = MAX(1, MIN(5, [dict[@"speed"] integerValue]));
        car.acceleration = MAX(1, MIN(5, [dict[@"accel"] integerValue]));
        car.grip = MAX(1, MIN(5, [dict[@"grip"] integerValue]));
        car.unlockStars = MAX(0, [dict[@"unlockStars"] integerValue]);
        if (car.carID.length > 0) {
            [cars addObject:car];
            carMap[car.carID] = car;
        }
    }
    [cars sortUsingComparator:^NSComparisonResult(CSCar *a, CSCar *b) {
        if (a.unlockStars != b.unlockStars) return a.unlockStars < b.unlockStars ? NSOrderedAscending : NSOrderedDescending;
        return [a.carID compare:b.carID];
    }];

    if (levels.count != 100 || worlds.count != 10 || cars.count < 8) {
        if (error) {
            *error = CSCatalogError([NSString stringWithFormat:
                @"Expected 100 levels, 10 worlds and 8 cars; found %lu, %lu and %lu.",
                (unsigned long)levels.count, (unsigned long)worlds.count, (unsigned long)cars.count]);
        }
        return nil;
    }
    // Every level must belong to a world.
    for (CSLevel *level in levels) {
        if (!worldMap[@(level.worldID)]) {
            if (error) *error = CSCatalogError([NSString stringWithFormat:@"Level %ld has unknown world.", (long)level.levelID]);
            return nil;
        }
    }

    _worlds = [worlds copy];
    _levels = [levels copy];
    _cars = [cars copy];
    _levelMap = [levelMap copy];
    _worldMap = [worldMap copy];
    _carMap = [carMap copy];
    return self;
}

- (nullable CSLevel *)levelForID:(NSInteger)levelID {
    return self.levelMap[@(levelID)];
}

- (nullable CSWorld *)worldForID:(NSInteger)worldID {
    return self.worldMap[@(worldID)];
}

- (nullable CSCar *)carForID:(NSString *)carID {
    return self.carMap[carID];
}

- (NSArray<CSLevel *> *)levelsInWorld:(NSInteger)worldID {
    NSMutableArray<CSLevel *> *result = [NSMutableArray array];
    for (CSLevel *level in self.levels) {
        if (level.worldID == worldID) [result addObject:level];
    }
    return result;
}

- (NSArray<CSCar *> *)carsUnlockedAtStars:(NSInteger)stars {
    NSMutableArray<CSCar *> *result = [NSMutableArray array];
    for (CSCar *car in self.cars) {
        if (stars >= car.unlockStars) [result addObject:car];
    }
    return result;
}

- (BOOL)isCarUnlocked:(CSCar *)car atStars:(NSInteger)stars {
    return stars >= car.unlockStars;
}

- (nullable CSLevel *)levelAfter:(CSLevel *)level {
    return [self levelForID:level.levelID + 1];
}

- (NSInteger)totalStarsAvailable {
    return (NSInteger)self.levels.count * 3;
}

@end
