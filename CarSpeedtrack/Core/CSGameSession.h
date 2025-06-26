#import <Foundation/Foundation.h>
#import "CSModels.h"
#import "CSRoadPath.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    BOOL steerLeft;
    BOOL steerRight;
    BOOL throttle;
    BOOL brake;
    BOOL boostPressed;
    BOOL mouseActive;
    CGFloat mouseX;
    BOOL mouseThrottle;
    BOOL mouseBrake;
} CSInputState;

FOUNDATION_EXPORT CSInputState CSInputStateMake(void);

@interface CSGameEntity : NSObject
@property (nonatomic) NSInteger entityID;
@property (nonatomic) CSEntityKind kind;
@property (nonatomic) NSInteger subkind;
@property (nonatomic) CGFloat distance;
@property (nonatomic) CGFloat x;
@property (nonatomic) CGFloat forwardSpeed;
@property (nonatomic) CGFloat lateralSpeed;
@property (nonatomic) NSInteger lane;
@property (nonatomic) CGFloat radius;
@property (nonatomic) BOOL active;
@property (nonatomic) BOOL passed;
@property (nonatomic) BOOL hit;
@property (nonatomic) CGFloat age;
@end

@interface CSSessionEvent : NSObject
@property (nonatomic) CSGameEventType type;
@property (nonatomic) CGPoint screenPosition;
@property (nonatomic) NSInteger points;
@property (nonatomic) NSInteger subkind;
@property (nonatomic, copy) NSString *message;
@end

@interface CSGameSession : NSObject

@property (nonatomic, readonly) CSLevel *level;
@property (nonatomic, readonly) CSCar *car;
@property (nonatomic, readonly) CSDifficultySettings *difficulty;
@property (nonatomic, readonly) CSRoadPath *roadPath;
@property (nonatomic, readonly) NSInteger laneCount;

@property (nonatomic, readonly) CGFloat playerDistance;
@property (nonatomic, readonly) CGFloat playerX;
@property (nonatomic, readonly) CGFloat speed;
@property (nonatomic, readonly) CGFloat maxSpeed;
@property (nonatomic, readonly) CGFloat lateralVelocity;
@property (nonatomic, readonly) CGFloat speedRatio;
@property (nonatomic, readonly) NSInteger steeringFrame;

@property (nonatomic, readonly) NSInteger lives;
@property (nonatomic, readonly) NSInteger score;
@property (nonatomic, readonly) NSInteger coins;
@property (nonatomic, readonly) NSInteger combo;
@property (nonatomic, readonly) NSInteger multiplier;
@property (nonatomic, readonly) NSInteger bestCombo;
@property (nonatomic, readonly) CGFloat boostMeter;
@property (nonatomic, readonly) BOOL boosting;
@property (nonatomic, readonly) BOOL shieldActive;
@property (nonatomic, readonly) BOOL magnetActive;
@property (nonatomic, readonly) BOOL invulnerable;
@property (nonatomic, readonly) BOOL tookDamage;
@property (nonatomic, readonly) BOOL isFinished;
@property (nonatomic, readonly) BOOL isCompleted;
@property (nonatomic, readonly) BOOL isFailed;
@property (nonatomic, readonly) CGFloat cameraShake;
@property (nonatomic, readonly) NSTimeInterval elapsed;
@property (nonatomic, readonly) CGFloat progress;

- (instancetype)initWithLevel:(CSLevel *)level
                          car:(CSCar *)car
                   difficulty:(CSDifficultySettings *)difficulty
                      runSeed:(uint64_t)runSeed NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)stepWithInput:(CSInputState)input dt:(NSTimeInterval)dt;
- (NSArray<CSSessionEvent *> *)drainEvents;
- (NSArray<CSGameEntity *> *)activeEntities;
- (CSRunResult *)makeResult;

@end

NS_ASSUME_NONNULL_END
