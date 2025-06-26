#import "CSGameSession.h"
#import "CSRandom.h"

CSInputState CSInputStateMake(void) {
    CSInputState input;
    memset(&input, 0, sizeof(input));
    return input;
}

@implementation CSGameEntity
@end

@implementation CSSessionEvent
@end

@interface CSGameSession ()
@property (nonatomic, readwrite) CGFloat playerDistance;
@property (nonatomic, readwrite) CGFloat playerX;
@property (nonatomic, readwrite) CGFloat speed;
@property (nonatomic, readwrite) CGFloat lateralVelocity;
@property (nonatomic, readwrite) NSInteger lives;
@property (nonatomic, readwrite) NSInteger score;
@property (nonatomic, readwrite) NSInteger coins;
@property (nonatomic, readwrite) NSInteger combo;
@property (nonatomic, readwrite) NSInteger multiplier;
@property (nonatomic, readwrite) NSInteger bestCombo;
@property (nonatomic, readwrite) CGFloat boostMeter;
@property (nonatomic, readwrite) BOOL boosting;
@property (nonatomic, readwrite) BOOL shieldActive;
@property (nonatomic, readwrite) BOOL tookDamage;
@property (nonatomic, readwrite) BOOL isFinished;
@property (nonatomic, readwrite) BOOL isCompleted;
@property (nonatomic, readwrite) BOOL isFailed;
@property (nonatomic, readwrite) CGFloat cameraShake;
@property (nonatomic, readwrite) NSTimeInterval elapsed;
@property (nonatomic, strong) CSRandom *random;
@property (nonatomic, strong) NSMutableArray<CSGameEntity *> *entityStore;
@property (nonatomic, strong) NSMutableArray<CSSessionEvent *> *eventStore;
@property (nonatomic) CGFloat spawnCursor;
@property (nonatomic) NSInteger entityCounter;
@property (nonatomic) CGFloat scoreAccumulator;
@property (nonatomic) CGFloat invulnerabilityTimer;
@property (nonatomic) CGFloat magnetTimer;
@property (nonatomic) CGFloat boostTimer;
@property (nonatomic) CGFloat slipTimer;
@property (nonatomic) CGFloat gripResponse;
@property (nonatomic) CGFloat speedAcceleration;
@property (nonatomic) CSMechanic mechanic;
@property (nonatomic) NSInteger steeringFrame;
@property (nonatomic) BOOL brakingFrame;
@end

@implementation CSGameSession

- (instancetype)initWithLevel:(CSLevel *)level
                          car:(CSCar *)car
                   difficulty:(CSDifficultySettings *)difficulty
                      runSeed:(uint64_t)runSeed {
    self = [super init];
    if (self) {
        _level = level;
        _car = car;
        _difficulty = difficulty;
        _roadPath = [[CSRoadPath alloc] initWithLevel:level];
        _laneCount = 3;
        _mechanic = CSMechanicFromString(level.mechanic);

        uint64_t mixedSeed = level.seed ^ (runSeed * 0xD1B54A32D192ED03ULL) ^ 0xA24BAED4963EE407ULL;
        _random = [[CSRandom alloc] initWithSeed:mixedSeed];
        _entityStore = [NSMutableArray array];
        _eventStore = [NSMutableArray array];
        _entityCounter = 1;
        _lives = MAX(1, difficulty.lives);
        _playerDistance = 0.0;
        _playerX = [self.roadPath centerXAtDistance:0.0];
        _maxSpeed = 244.0 * (0.93 + (CGFloat)car.speed * 0.032);
        _speed = _maxSpeed * 0.52;
        CGFloat accelResponse = 2.8 + (CGFloat)car.acceleration * 0.32;
        _gripResponse = 0.78 + (CGFloat)car.grip * 0.055;
        _speedAcceleration = accelResponse;
        _spawnCursor = 820.0;
        _multiplier = 1;
        _boostMeter = 0.25;
        _cameraShake = 0.0;
        [self spawnThroughDistance:2200.0];
    }
    return self;
}

- (void)dealloc {
    // Explicitly empty; kept for symmetry and ARC clarity.
}

#pragma mark - Public derived values

- (CGFloat)speedRatio {
    return self.maxSpeed > 0 ? self.speed / self.maxSpeed : 0;
}

- (CGFloat)progress {
    return self.level.length > 0 ? MIN(1.0, MAX(0.0, self.playerDistance / self.level.length)) : 0;
}

- (BOOL)invulnerable {
    return self.invulnerabilityTimer > 0;
}

- (BOOL)magnetActive {
    return self.magnetTimer > 0;
}

- (NSArray<CSGameEntity *> *)activeEntities {
    NSMutableArray<CSGameEntity *> *result = [NSMutableArray array];
    for (CSGameEntity *entity in self.entityStore) {
        if (entity.active) [result addObject:entity];
    }
    return result;
}

- (NSArray<CSSessionEvent *> *)drainEvents {
    if (self.eventStore.count == 0) return @[];
    NSArray *events = [self.eventStore copy];
    [self.eventStore removeAllObjects];
    return events;
}

#pragma mark - Simulation

- (void)stepWithInput:(CSInputState)input dt:(NSTimeInterval)dt {
    if (self.isFinished) return;
    CGFloat frame = (CGFloat)MIN(0.1, MAX(0.0, dt));
    if (frame <= 0) return;

    self.elapsed += frame;
    self.invulnerabilityTimer = MAX(0.0, self.invulnerabilityTimer - frame);
    self.magnetTimer = MAX(0.0, self.magnetTimer - frame);
    self.slipTimer = MAX(0.0, self.slipTimer - frame);
    self.cameraShake = MAX(0.0, self.cameraShake - frame * 3.2);

    [self updatePlayerWithInput:input dt:frame];
    [self spawnThroughDistance:self.playerDistance + 2100.0];
    [self updateEntitiesWithInput:input dt:frame];
    [self updateCollisions];

    CGFloat distancePoints = self.speed * frame * 0.085 * self.difficulty.scoreMultiplier;
    self.scoreAccumulator += distancePoints;
    NSInteger whole = (NSInteger)floor(self.scoreAccumulator);
    if (whole > 0) {
        self.score += whole;
        self.scoreAccumulator -= whole;
    }

    if (self.playerDistance >= self.level.length) {
        [self finishLevel];
    }
    [self pruneEntities];
}

- (void)updatePlayerWithInput:(CSInputState)input dt:(CGFloat)dt {
    BOOL throttle = input.throttle || input.mouseThrottle;
    BOOL brake = input.brake || input.mouseBrake;
    self.brakingFrame = brake && !throttle;

    CGFloat offRoad = [self.roadPath offRoadAmountForX:self.playerX distance:self.playerDistance];
    CGFloat targetSpeed = self.maxSpeed * (brake ? 0.26 : (throttle ? 1.0 : 0.56));
    targetSpeed *= (1.0 - offRoad * 0.42);

    if (self.boosting) {
        self.boostTimer -= dt;
        targetSpeed = self.maxSpeed * 1.42;
        self.boostMeter = MAX(0.0, self.boostTimer / 1.9);
        if (self.boostTimer <= 0) {
            self.boosting = NO;
            self.boostMeter = 0;
        }
    } else if (input.boostPressed && self.boostMeter >= 0.999) {
        self.boosting = YES;
        self.boostTimer = 1.9;
        self.boostMeter = 1.0;
        [self emitEvent:CSGameEventBoostStart message:@"TURBO!" points:0 x:self.playerX distance:self.playerDistance];
    }

    CGFloat approach = self.speedAcceleration * (self.boosting ? 4.8 : 3.1);
    if (self.speed < targetSpeed) {
        self.speed = MIN(targetSpeed, self.speed + (targetSpeed - self.speed) * approach * dt + 28.0 * dt);
    } else {
        self.speed = MAX(targetSpeed, self.speed - (self.speed - targetSpeed) * (brake ? 4.8 : 2.6) * dt);
    }
    self.speed = MAX(35.0, self.speed);

    CGFloat grip = self.gripResponse;
    if (self.mechanic == CSMechanicIce || self.mechanic == CSMechanicLowGrip) grip *= 0.58;
    if (self.slipTimer > 0) grip *= 0.48;
    if (offRoad > 0) grip *= 0.8;
    grip *= (0.9 + 0.1 * (1.0 - MIN(1.0, self.difficulty.trafficFactor / 1.8)));

    CGFloat maxLateral = 188.0 * grip + 20.0;
    CGFloat desired = 0.0;
    BOOL keyboardSteering = input.steerLeft || input.steerRight;
    if (keyboardSteering) {
        desired = input.steerRight ? maxLateral : -maxLateral;
        if (input.steerLeft && input.steerRight) desired = 0;
    } else if (input.mouseActive) {
        desired = (input.mouseX - self.playerX) * 4.6;
        desired = MIN(maxLateral, MAX(-maxLateral, desired));
    }
    CGFloat lateralResponse = 8.2 * grip;
    self.lateralVelocity += (desired - self.lateralVelocity) * MIN(1.0, lateralResponse * dt);
    if (!keyboardSteering && !input.mouseActive) {
        self.lateralVelocity *= pow(0.035, dt);
    }

    CGFloat wind = 0;
    if (self.mechanic == CSMechanicCrosswind || self.mechanic == CSMechanicAurora) {
        wind = sin(self.elapsed * 0.72 + (CGFloat)(self.level.seed % 1000) * 0.01) * (17.0 + self.level.curviness * 22.0);
    } else if (self.mechanic == CSMechanicWaves) {
        wind = sin(self.elapsed * 1.15) * 13.0;
    }
    self.lateralVelocity += wind * dt;
    self.playerX += self.lateralVelocity * dt;

    if (self.difficulty.assist && offRoad > 0.08) {
        CGFloat center = [self.roadPath centerXAtDistance:self.playerDistance];
        self.playerX += (center - self.playerX) * 0.75 * dt;
    }

    CGFloat minX = 12.0;
    CGFloat maxX = 628.0;
    if (self.playerX < minX) {
        self.playerX = minX;
        self.lateralVelocity = MAX(0.0, self.lateralVelocity);
    } else if (self.playerX > maxX) {
        self.playerX = maxX;
        self.lateralVelocity = MIN(0.0, self.lateralVelocity);
    }

    self.playerDistance += self.speed * dt;
    if (fabs(self.lateralVelocity) > 24.0) {
        self.steeringFrame = self.lateralVelocity > 0 ? 2 : 1;
    } else {
        self.steeringFrame = self.brakingFrame ? 3 : 0;
    }
}

- (void)spawnThroughDistance:(CGFloat)targetDistance {
    while (self.spawnCursor < targetDistance) {
        [self spawnRowAtDistance:self.spawnCursor];
        CGFloat gap = 238.0 + [self.random nextFloatFrom:0 to:95.0];
        gap -= self.level.hazardDensity * 22.0;
        self.spawnCursor += MAX(178.0, gap);
    }
}

- (void)spawnRowAtDistance:(CGFloat)distance {
    NSMutableArray<NSNumber *> *lanes = [@[@0, @1, @2] mutableCopy];
    for (NSInteger i = lanes.count - 1; i > 0; i--) {
        NSInteger j = [self.random nextInt:i + 1];
        [lanes exchangeObjectAtIndex:i withObjectAtIndex:j];
    }

    CGFloat trafficPressure = MIN(1.5, self.level.trafficDensity * self.difficulty.trafficFactor);
    CGFloat hazardPressure = MIN(1.5, self.level.hazardDensity * self.difficulty.hazardFactor);
    CGFloat pressure = MIN(1.55, (trafficPressure + hazardPressure) * 0.55);
    NSInteger blocked = [self.random chance:MIN(0.58, pressure * 0.50)] ? 2 : 1;
    if (pressure < 0.23) blocked = [self.random chance:0.55] ? 1 : 0;
    blocked = MIN(2, MAX(0, blocked));

    for (NSInteger i = 0; i < blocked; i++) {
        NSInteger lane = lanes[i].integerValue;
        CGFloat x = [self.roadPath laneCenterForLane:lane laneCount:self.laneCount atDistance:distance];
        BOOL makeTraffic = [self.random chance:trafficPressure / MAX(0.001, trafficPressure + hazardPressure)];
        if (makeTraffic) {
            CSGameEntity *entity = [self newEntityOfKind:CSEntityKindTraffic subkind:[self.random nextInt:5]];
            entity.distance = distance + [self.random nextFloatFrom:-18.0 to:24.0];
            entity.x = x;
            entity.lane = lane;
            entity.radius = 17.0;
            entity.forwardSpeed = MAX(42.0, self.maxSpeed * (self.level.trafficSpeed + 0.10) *
                                            self.difficulty.trafficSpeedFactor *
                                            [self.random nextFloatFrom:0.86 to:1.14]);
            [self.entityStore addObject:entity];
        } else {
            NSArray<NSString *> *hazards = self.level.hazards.count ? self.level.hazards : @[@"cone"];
            NSString *hazardName = hazards[[self.random nextInt:hazards.count]];
            CSHazardKind hazard = CSHazardKindFromString(hazardName);
            CSGameEntity *entity = [self newEntityOfKind:CSEntityKindHazard subkind:hazard];
            entity.distance = distance + [self.random nextFloatFrom:-12.0 to:22.0];
            entity.lane = lane;
            entity.x = [self.roadPath laneCenterForLane:lane laneCount:self.laneCount atDistance:entity.distance];
            entity.radius = [self hazardRadius:hazard];
            if (hazard == CSHazardKindBeachball || hazard == CSHazardKindTumbleweed) {
                entity.lateralSpeed = [self.random nextFloatFrom:28.0 to:66.0] * ([self.random chance:0.5] ? 1 : -1);
            }
            [self.entityStore addObject:entity];
        }
    }

    if ([self.random chance:MIN(0.96, 0.54 + self.level.pickupDensity * 0.38 * self.difficulty.pickupFactor)]) {
        NSInteger freeLane = lanes.lastObject.integerValue;
        NSInteger count = 2 + [self.random nextInt:3];
        for (NSInteger i = 0; i < count; i++) {
            CGFloat s = distance + 30.0 + i * 54.0;
            CSGameEntity *pickup = [self newEntityOfKind:CSEntityKindPickup subkind:CSPickupKindCoin];
            pickup.distance = s;
            pickup.lane = freeLane;
            pickup.x = [self.roadPath laneCenterForLane:freeLane laneCount:self.laneCount atDistance:s];
            pickup.radius = 10.0;
            if (i == count - 1) {
                double r = [self.random nextDouble];
                if (r < 0.07) pickup.subkind = CSPickupKindGem;
                else if (r < 0.095) pickup.subkind = CSPickupKindShield;
                else if (r < 0.122) pickup.subkind = CSPickupKindHeart;
                else if (r < 0.148) pickup.subkind = CSPickupKindMagnet;
                else if (r < 0.170) pickup.subkind = CSPickupKindStar;
            }
            [self.entityStore addObject:pickup];
        }
    }
}

- (CSGameEntity *)newEntityOfKind:(CSEntityKind)kind subkind:(NSInteger)subkind {
    CSGameEntity *entity = [CSGameEntity new];
    entity.entityID = self.entityCounter++;
    entity.kind = kind;
    entity.subkind = subkind;
    entity.active = YES;
    entity.age = 0;
    return entity;
}

- (CGFloat)hazardRadius:(CSHazardKind)kind {
    switch (kind) {
        case CSHazardKindCone: return 10;
        case CSHazardKindSpike: return 17;
        case CSHazardKindPothole: return 15;
        case CSHazardKindJelly: return 16;
        case CSHazardKindPuddle: return 16;
        case CSHazardKindBeachball: return 13;
        case CSHazardKindTumbleweed: return 13;
        case CSHazardKindAsteroid: return 14;
        case CSHazardKindSnowball: return 12;
        case CSHazardKindEmber: return 12;
    }
    return 12;
}

- (void)updateEntitiesWithInput:(CSInputState)input dt:(CGFloat)dt {
    for (CSGameEntity *entity in self.entityStore) {
        if (!entity.active) continue;
        entity.age += dt;
        if (entity.kind == CSEntityKindTraffic) {
            entity.distance += entity.forwardSpeed * dt;
            entity.x = [self.roadPath laneCenterForLane:entity.lane laneCount:self.laneCount atDistance:entity.distance];
        } else if (entity.kind == CSEntityKindHazard && fabs(entity.lateralSpeed) > 0.01) {
            entity.x += entity.lateralSpeed * dt;
            CGFloat left = [self.roadPath leftEdgeAtDistance:entity.distance] + entity.radius + 4;
            CGFloat right = [self.roadPath rightEdgeAtDistance:entity.distance] - entity.radius - 4;
            if (entity.x < left) {
                entity.x = left;
                entity.lateralSpeed = fabs(entity.lateralSpeed);
            } else if (entity.x > right) {
                entity.x = right;
                entity.lateralSpeed = -fabs(entity.lateralSpeed);
            }
        } else if (entity.kind == CSEntityKindPickup && self.magnetActive) {
            CGFloat ds = entity.distance - self.playerDistance;
            if (ds > -30 && ds < 220 && fabs(entity.x - self.playerX) < 170) {
                entity.x += (self.playerX - entity.x) * MIN(1.0, 2.4 * dt);
            }
        }
    }
}

- (void)updateCollisions {
    for (CSGameEntity *entity in self.entityStore) {
        if (!entity.active) continue;
        CGFloat ds = entity.distance - self.playerDistance;
        CGFloat dx = entity.x - self.playerX;

        if (entity.kind == CSEntityKindTraffic) {
            CGFloat hitX = entity.radius + 15.0;
            CGFloat hitS = entity.radius + 19.0;
            if (!entity.hit && fabs(ds) < hitS && fabs(dx) < hitX) {
                entity.hit = YES;
                entity.active = NO;
                [self playerHitByEntity:entity];
            } else if (!entity.passed && fabs(ds) < 48.0 && fabs(dx) >= hitX && fabs(dx) < 84.0) {
                entity.passed = YES;
                [self awardNearMissAtX:entity.x distance:entity.distance];
            } else if (!entity.passed && ds < -42.0) {
                entity.passed = YES;
            }
        } else if (entity.kind == CSEntityKindHazard) {
            if (!entity.hit && fabs(ds) < (entity.radius + 19.0) && fabs(dx) < (entity.radius + 14.0)) {
                entity.hit = YES;
                entity.active = NO;
                [self playerHitHazard:entity];
            }
        } else if (entity.kind == CSEntityKindPickup) {
            if (fabs(ds) < 27.0 && fabs(dx) < 26.0) {
                entity.active = NO;
                [self collectPickup:entity];
            }
        }
    }
}

- (void)playerHitByEntity:(CSGameEntity *)entity {
    [self dealDamageWithMessage:@"TRAFFIC!" x:entity.x distance:entity.distance];
}

- (void)playerHitHazard:(CSGameEntity *)entity {
    CSHazardKind hazard = (CSHazardKind)entity.subkind;
    switch (hazard) {
        case CSHazardKindPothole: {
            self.speed *= 0.72;
            self.cameraShake = 0.5;
            [self emitEvent:CSGameEventHit message:@"BUMP!" points:0 x:entity.x distance:entity.distance];
            break;
        }
        case CSHazardKindJelly:
        case CSHazardKindPuddle: {
            self.slipTimer = 1.35;
            self.lateralVelocity += (entity.x < self.playerX ? -1 : 1) * 80.0;
            self.cameraShake = 0.25;
            [self emitEvent:CSGameEventSlip message:@"SLIP!" points:0 x:entity.x distance:entity.distance];
            break;
        }
        case CSHazardKindBeachball:
        case CSHazardKindTumbleweed: {
            self.speed *= 0.82;
            self.lateralVelocity += (entity.x < self.playerX ? -1 : 1) * 95.0;
            self.cameraShake = 0.35;
            [self emitEvent:CSGameEventHit message:@"BOUNCE!" points:0 x:entity.x distance:entity.distance];
            break;
        }
        case CSHazardKindCone:
        case CSHazardKindSpike:
        case CSHazardKindAsteroid:
        case CSHazardKindSnowball:
        case CSHazardKindEmber:
            [self dealDamageWithMessage:@"OUCH!" x:entity.x distance:entity.distance];
            break;
    }
}

- (void)dealDamageWithMessage:(NSString *)message x:(CGFloat)x distance:(CGFloat)distance {
    self.tookDamage = YES;
    if (self.invulnerabilityTimer > 0) return;
    if (self.shieldActive) {
        self.shieldActive = NO;
        self.invulnerabilityTimer = 1.15;
        self.cameraShake = 0.6;
        [self emitEvent:CSGameEventShieldAbsorbed message:@"SHIELD!" points:0 x:x distance:distance];
        return;
    }
    self.lives = MAX(0, self.lives - 1);
    self.invulnerabilityTimer = 2.0;
    self.speed *= 0.52;
    self.combo = 0;
    self.multiplier = 1;
    self.cameraShake = 1.0;
    self.boostMeter = MAX(0.0, self.boostMeter - 0.25);
    [self emitEvent:CSGameEventHit message:message points:-1 x:x distance:distance];
    if (self.lives <= 0) {
        self.isFailed = YES;
        self.isFinished = YES;
        [self emitEvent:CSGameEventFail message:@"NO LIVES LEFT" points:0 x:self.playerX distance:self.playerDistance];
    }
}

- (void)awardNearMissAtX:(CGFloat)x distance:(CGFloat)distance {
    self.combo += 1;
    self.bestCombo = MAX(self.bestCombo, self.combo);
    self.multiplier = MIN(10, 1 + self.combo / 8);
    NSInteger points = (NSInteger)round(18.0 * self.multiplier * self.difficulty.scoreMultiplier);
    self.score += points;
    self.boostMeter = MIN(1.0, self.boostMeter + 0.035);
    [self emitEvent:CSGameEventNearMiss message:[NSString stringWithFormat:@"NEAR MISS +%ld", (long)points]
              points:points x:x distance:distance];
}

- (void)collectPickup:(CSGameEntity *)entity {
    CSPickupKind kind = (CSPickupKind)entity.subkind;
    NSInteger basePoints = 25;
    switch (kind) {
        case CSPickupKindCoin:
            basePoints = 25;
            self.coins += 1;
            self.boostMeter = MIN(1.0, self.boostMeter + 0.025);
            break;
        case CSPickupKindGem:
            basePoints = 110;
            self.coins += 1;
            self.boostMeter = MIN(1.0, self.boostMeter + 0.06);
            break;
        case CSPickupKindHeart:
            if (self.lives < 5) {
                self.lives += 1;
                [self emitEvent:CSGameEventLifeGained message:@"+1 LIFE" points:0
                             x:entity.x distance:entity.distance];
                return;
            }
            basePoints = 140;
            break;
        case CSPickupKindShield:
            self.shieldActive = YES;
            [self emitEvent:CSGameEventPickup message:@"SHIELD" points:0 x:entity.x distance:entity.distance];
            return;
        case CSPickupKindMagnet:
            self.magnetTimer = 9.0;
            [self emitEvent:CSGameEventPickup message:@"MAGNET" points:0 x:entity.x distance:entity.distance];
            return;
        case CSPickupKindStar:
            basePoints = 500;
            self.boostMeter = MIN(1.0, self.boostMeter + 0.35);
            break;
    }

    self.combo += 1;
    self.bestCombo = MAX(self.bestCombo, self.combo);
    self.multiplier = MIN(10, 1 + self.combo / 8);
    NSInteger points = (NSInteger)round((CGFloat)basePoints * self.multiplier * self.difficulty.scoreMultiplier);
    self.score += points;
    NSString *message = [NSString stringWithFormat:@"+%ld", (long)points];
    [self emitEvent:CSGameEventPickup message:message points:points x:entity.x distance:entity.distance];
}

- (void)finishLevel {
    if (self.isFinished) return;
    self.isCompleted = YES;
    self.isFinished = YES;
    NSInteger bonus = 1500 + self.lives * 250 + (self.tookDamage ? 0 : 750);
    self.score += (NSInteger)round((CGFloat)bonus * self.difficulty.scoreMultiplier);
    self.cameraShake = 0.35;
    [self emitEvent:CSGameEventFinish message:@"FINISH!" points:bonus x:self.playerX distance:self.playerDistance];
}

- (void)pruneEntities {
    NSIndexSet *toRemove = [self.entityStore indexesOfObjectsPassingTest:^BOOL(CSGameEntity *entity, NSUInteger idx, BOOL *stop) {
        if (!entity.active) return YES;
        if (entity.distance < self.playerDistance - 180.0) return YES;
        return NO;
    }];
    [self.entityStore removeObjectsAtIndexes:toRemove];
}

- (void)emitEvent:(CSGameEventType)type message:(NSString *)message points:(NSInteger)points
                x:(CGFloat)x distance:(CGFloat)distance {
    CSSessionEvent *event = [CSSessionEvent new];
    event.type = type;
    event.message = message;
    event.points = points;
    // The scene uses a player screen-Y of 96 and SpriteKit's upward Y axis.
    event.screenPosition = CGPointMake(x, 96.0 + (distance - self.playerDistance));
    [self.eventStore addObject:event];
}

- (CSRunResult *)makeResult {
    CSRunResult *result = [CSRunResult new];
    result.levelID = self.level.levelID;
    result.worldID = self.level.worldID;
    result.levelName = self.level.name;
    result.score = self.score;
    result.coins = self.coins;
    result.livesLeft = self.lives;
    result.bestCombo = self.bestCombo;
    result.completed = self.isCompleted;
    result.tookDamage = self.tookDamage;
    result.carID = self.car.carID;
    result.difficultyName = [self.difficulty displayName];
    result.duration = self.elapsed;
    result.date = [NSDate date];
    if (self.isCompleted) {
        if (self.score >= self.level.star3) result.stars = 3;
        else if (self.score >= self.level.star2) result.stars = 2;
        else result.stars = 1;
    } else {
        result.stars = 0;
    }
    return result;
}

@end
