#import "CSAudioManager.h"
#import "CSSaveManager.h"

@interface CSAudioManager () <AVAudioPlayerDelegate>
@end

@implementation CSAudioManager {
    CSSaveManager *_save;
    AVAudioPlayer *_musicActive;
    AVAudioPlayer *_musicFading;
    AVAudioPlayer *_incomingMusic;
    NSString *_activeMusicName;
    NSString *_pendingMusicName;
    NSMutableDictionary<NSString *, AVAudioPlayer *> *_sfxPlayers;
    AVAudioPlayer *_enginePlayer;
    AVAudioPlayer *_tyrePlayer;
    NSTimer *_fadeTimer;
    NSTimeInterval _fadeElapsed;
    NSTimeInterval _fadeDuration;
    BOOL _ducked;
    BOOL _engineRunning;
}

- (instancetype)initWithSaveManager:(CSSaveManager *)saveManager {
    self = [super init];
    if (self) {
        _save = saveManager;
        _sfxPlayers = [NSMutableDictionary dictionary];
        _fadeDuration = 0.6;
    }
    return self;
}

- (void)dealloc {
    [_fadeTimer invalidate];
}

- (BOOL)isMuted {
    return [_save isMuted];
}

- (void)toggleMuted {
    [_save setMuted:![_save isMuted]];
    [self refreshVolumes];
}

- (void)reloadSettings {
    [self refreshVolumes];
}

- (CGFloat)masterVolume {
    return [self isMuted] ? 0.0 : [_save volumeForKey:@"master"];
}

- (CGFloat)musicTargetVolume {
    CGFloat volume = [self masterVolume] * [_save volumeForKey:@"music"];
    if (_ducked) volume *= 0.35;
    return MIN(1.0, volume);
}

- (nullable NSURL *)urlForMusic:(NSString *)name {
    NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:@"wav" subdirectory:@"Audio/Music"];
    if (!url) url = [[NSBundle mainBundle] URLForResource:name withExtension:@"wav"];
    return url;
}

- (nullable NSURL *)urlForSFX:(NSString *)name {
    NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:@"wav" subdirectory:@"Audio/SFX"];
    if (!url) url = [[NSBundle mainBundle] URLForResource:name withExtension:@"wav"];
    return url;
}

- (void)playMusic:(NSString *)name loop:(BOOL)loop {
    if (name.length == 0) return;
    if ([_activeMusicName isEqualToString:name] && _musicActive.isPlaying) {
        [self refreshVolumes];
        return;
    }
    NSURL *url = [self urlForMusic:name];
    if (!url) {
        NSLog(@"CarSpeedtrack: missing music %@", name);
        return;
    }
    NSError *error = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (!player) {
        NSLog(@"CarSpeedtrack: cannot play %@: %@", name, error);
        return;
    }
    player.numberOfLoops = loop ? -1 : 0;
    player.volume = 0.0;
    player.delegate = self;
    [player prepareToPlay];
    [player play];

    [_fadeTimer invalidate];
    if (_musicActive) {
        [_musicFading stop];
        _musicFading = _musicActive;
    }
    _musicActive = player;
    _activeMusicName = [name copy];
    _fadeElapsed = 0.0;
    _fadeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
                                                  target:self
                                                selector:@selector(fadeTick:)
                                                userInfo:nil
                                                 repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_fadeTimer forMode:NSRunLoopCommonModes];
}

- (void)fadeTick:(NSTimer *)timer {
    _fadeElapsed += 1.0 / 30.0;
    CGFloat progress = MIN(1.0, _fadeElapsed / _fadeDuration);
    CGFloat target = [self musicTargetVolume];
    _musicActive.volume = target * progress;
    _musicFading.volume = target * (1.0 - progress);
    if (progress >= 1.0) {
        [timer invalidate];
        _fadeTimer = nil;
        [_musicFading stop];
        _musicFading = nil;
    }
}

- (void)stopMusic {
    [_fadeTimer invalidate];
    _fadeTimer = nil;
    [_musicActive stop];
    [_musicFading stop];
    _musicActive = nil;
    _musicFading = nil;
    _activeMusicName = nil;
}

- (void)refreshVolumes {
    if (_fadeTimer) {
        // The fade tick will settle volumes.
        return;
    }
    _musicActive.volume = [self musicTargetVolume];
    _musicFading.volume = 0.0;
    for (AVAudioPlayer *player in _sfxPlayers.allValues) {
        player.volume = MIN(1.0, [self masterVolume] * [_save volumeForKey:@"sfx"]);
    }
    CGFloat engine = [self masterVolume] * [_save volumeForKey:@"engine"];
    _enginePlayer.volume = _engineRunning ? engine * 0.7 : 0.0;
    _tyrePlayer.volume = _engineRunning ? engine * 0.18 : 0.0;
}

- (void)playSFX:(NSString *)name {
    if ([self isMuted] || name.length == 0) return;
    NSURL *url = [self urlForSFX:name];
    if (!url) {
        NSLog(@"CarSpeedtrack: missing sfx %@", name);
        return;
    }
    AVAudioPlayer *player = _sfxPlayers[name];
    if (!player) {
        NSError *error = nil;
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
        if (!player) {
            NSLog(@"CarSpeedtrack: cannot play %@: %@", name, error);
            return;
        }
        player.enableRate = YES;
        [player prepareToPlay];
        _sfxPlayers[name] = player;
    }
    player.volume = MIN(1.0, [self masterVolume] * [_save volumeForKey:@"sfx"]);
    player.currentTime = 0.0;
    [player play];
}

- (void)setDucked:(BOOL)ducked {
    _ducked = ducked;
    [self refreshVolumes];
}

- (void)startEngine {
    if (_engineRunning) return;
    NSURL *engineURL = [self urlForSFX:@"engine_loop"];
    NSURL *tyreURL = [self urlForSFX:@"tyre_loop"];
    if (!engineURL || !tyreURL) return;
    NSError *error = nil;
    _enginePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:engineURL error:&error];
    _tyrePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:tyreURL error:&error];
    for (AVAudioPlayer *player in @[_enginePlayer, _tyrePlayer]) {
        if (!player) continue;
        player.numberOfLoops = -1;
        player.enableRate = YES;
        player.volume = 0.0;
        [player prepareToPlay];
        [player play];
    }
    _engineRunning = YES;
    [self updateEngineWithSpeedRatio:0.3 offRoad:0 paused:NO];
}

- (void)stopEngine {
    _engineRunning = NO;
    [_enginePlayer stop];
    [_tyrePlayer stop];
    _enginePlayer = nil;
    _tyrePlayer = nil;
}

- (void)updateEngineWithSpeedRatio:(CGFloat)ratio offRoad:(CGFloat)offRoad paused:(BOOL)paused {
    if (!_engineRunning) return;
    CGFloat engineVolume = [self masterVolume] * [_save volumeForKey:@"engine"];
    if (paused || [self isMuted]) {
        _enginePlayer.volume = 0.0;
        _tyrePlayer.volume = 0.0;
        return;
    }
    CGFloat clamped = MIN(1.2, MAX(0.0, ratio));
    _enginePlayer.volume = engineVolume * (0.22 + 0.55 * clamped);
    _enginePlayer.rate = 0.72 + clamped * 0.58;
    _tyrePlayer.volume = engineVolume * (0.10 + offRoad * 0.55);
    _tyrePlayer.rate = 0.8 + clamped * 0.4;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (player == _musicActive) {
        _musicActive = nil;
        _activeMusicName = nil;
    } else if (player == _musicFading) {
        _musicFading = nil;
    }
}

@end
