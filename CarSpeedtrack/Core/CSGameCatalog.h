#import <Foundation/Foundation.h>
#import "CSModels.h"

NS_ASSUME_NONNULL_BEGIN

/// Loads the generated campaign data and exposes lookups. Immutable after init.
@interface CSGameCatalog : NSObject

@property (nonatomic, readonly, copy) NSArray<CSWorld *> *worlds;
@property (nonatomic, readonly, copy) NSArray<CSLevel *> *levels;
@property (nonatomic, readonly, copy) NSArray<CSCar *> *cars;

+ (nullable instancetype)bundledCatalogWithError:(NSError **)error;
- (nullable instancetype)initWithLevelsURL:(NSURL *)levelsURL
                                   carsURL:(NSURL *)carsURL
                                     error:(NSError **)error NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable CSLevel *)levelForID:(NSInteger)levelID;
- (nullable CSWorld *)worldForID:(NSInteger)worldID;
- (nullable CSCar *)carForID:(NSString *)carID;
- (NSArray<CSLevel *> *)levelsInWorld:(NSInteger)worldID;
- (NSArray<CSCar *> *)carsUnlockedAtStars:(NSInteger)stars;
- (BOOL)isCarUnlocked:(CSCar *)car atStars:(NSInteger)stars;
- (nullable CSLevel *)levelAfter:(CSLevel *)level;
@property (nonatomic, readonly) NSInteger totalStarsAvailable;

@end

NS_ASSUME_NONNULL_END
