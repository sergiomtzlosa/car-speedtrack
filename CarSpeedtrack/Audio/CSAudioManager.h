#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CSSaveManager;

/// Music crossfades, pooled SFX and a pitch-mapped engine loop. Volumes are
/// read from the save profile and can be changed live from Settings.
@interface CSAudioManager : NSObject

- (instancetype)initWithSaveManager:(CSSaveManager *)saveManager NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)reloadSettings;
- (void)playMusic:(NSString *)name loop:(BOOL)loop;
- (void)stopMusic;
- (void)playSFX:(NSString *)name;
- (void)setDucked:(BOOL)ducked;

- (void)startEngine;
- (void)stopEngine;
- (void)updateEngineWithSpeedRatio:(CGFloat)ratio offRoad:(CGFloat)offRoad paused:(BOOL)paused;

- (BOOL)isMuted;
- (void)toggleMuted;
- (void)refreshVolumes;

@end

NS_ASSUME_NONNULL_END
