#import "CSSettingsScene.h"
#import "CSAppContext.h"
#import "CSGameCatalog.h"
#import "CSSaveManager.h"
#import "CSAssetCatalog.h"
#import "CSAudioManager.h"
#import "CSGameViewController.h"
#import "CSSliderNode.h"

@implementation CSSettingsScene {
    CSDifficultySettings *_settings;
    NSMutableArray<CSSliderNode *> *_sliders;
    NSMutableDictionary<NSString *, CSPixelLabelNode *> *_volumeLabels;
    NSHashTable<SKNode *> *_customNodes;
    NSMutableArray<CSPixelButtonNode *> *_customButtons;
    NSMutableArray<CSPixelButtonNode *> *_presetButtons;
    SKSpriteNode *_presetMarker;
    CSPixelLabelNode *_difficultySummary;
    CSPixelLabelNode *_assistLabel;
    CSPixelLabelNode *_motionLabel;
    CSPixelLabelNode *_muteLabel;
    CSSliderNode *_activeSlider;
    CSPixelButtonNode *_resetButton;
    BOOL _resetArmed;
}

- (instancetype)init {
    self = [super initWithSize:CGSizeMake(640, 360)];
    if (self) {
        self.screenMusicName = @"music_menu";
        _settings = [[CSAppContext.shared.save difficultySettings] copy];
        _sliders = [NSMutableArray array];
        _volumeLabels = [NSMutableDictionary dictionary];
        _customNodes = [NSHashTable weakObjectsHashTable];
        _customButtons = [NSMutableArray array];
        _presetButtons = [NSMutableArray array];
        [self buildScreen];
        [self updateAllControls];
    }
    return self;
}

- (void)buildScreen {
    CSAssetCatalog *assets = [CSAssetCatalog shared];
    SKSpriteNode *header = [SKSpriteNode spriteNodeWithColor:[NSColor colorWithSRGBRed:0.22 green:0.14 blue:0.27 alpha:0.9]
                                                        size:CGSizeMake(640, 52)];
    header.anchorPoint = CGPointZero;
    header.position = CGPointMake(0, 308);
    header.zPosition = 1;
    [self.contentRoot addChild:header];
    [self addLabel:@"SETTINGS" atPoint:CGPointMake(320, 338) scale:1.7
             color:[NSColor colorWithSRGBRed:1 green:0.97 blue:0.87 alpha:1]
         alignment:CSPixelTextAlignmentCenter zPosition:3];

    __weak typeof(self) weakSelf = self;
    CSPixelButtonNode *back = [[CSPixelButtonNode alloc] initWithText:@"BACK"
                                                           textureName:@"ui_button_lavender"
                                                                  size:CGSizeMake(70, 24)
                                                             fontScale:0.75];
    back.position = CGPointMake(45, 338);
    back.actionBlock = ^{ [CSAppContext.shared.viewController presentMenu]; (void)weakSelf; };
    [self addButton:back];

    SKSpriteNode *gear = [SKSpriteNode spriteNodeWithTexture:[assets textureNamed:@"icon_gear"]];
    gear.size = CGSizeMake(24, 24);
    gear.position = CGPointMake(594, 338);
    gear.zPosition = 3;
    [self.contentRoot addChild:gear];

    [self addPanelWithTexture:@"ui_panel" size:CGSizeMake(276, 240) position:CGPointMake(165, 155) zPosition:2];
    [self addPanelWithTexture:@"ui_panel" size:CGSizeMake(300, 240) position:CGPointMake(458, 155) zPosition:2];

    [self addLabel:@"AUDIO" atPoint:CGPointMake(42, 258) scale:0.78
             color:[NSColor colorWithSRGBRed:0.35 green:0.23 blue:0.41 alpha:1]
         alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;

    NSArray<NSDictionary *> *volumes = @[
        @{@"key": @"master", @"title": @"MASTER", @"y": @232},
        @{@"key": @"music", @"title": @"MUSIC", @"y": @190},
        @{@"key": @"sfx", @"title": @"SFX", @"y": @148},
        @{@"key": @"engine", @"title": @"ENGINE", @"y": @106},
    ];
    for (NSDictionary *entry in volumes) {
        NSString *key = entry[@"key"];
        CGFloat y = [entry[@"y"] doubleValue];
        [self addLabel:entry[@"title"] atPoint:CGPointMake(42, y) scale:0.64
                 color:[NSColor colorWithSRGBRed:0.30 green:0.19 blue:0.36 alpha:1]
             alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;
        CGFloat volume = [CSAppContext.shared.save volumeForKey:key];
        CSPixelLabelNode *value = [self addLabel:[NSString stringWithFormat:@"%ld%%", (long)round(volume * 100)]
                                         atPoint:CGPointMake(292, y) scale:0.62
                                           color:[NSColor colorWithSRGBRed:0.40 green:0.28 blue:0.44 alpha:1]
                                       alignment:CSPixelTextAlignmentRight zPosition:4];
        value.shadowEnabled = NO;
        _volumeLabels[key] = value;

        CSSliderNode *slider = [[CSSliderNode alloc] initWithWidth:170 value:volume];
        slider.position = CGPointMake(120, y - 16);
        slider.zPosition = 3;
        __weak typeof(self) weakSliderSelf = self;
        slider.valueChanged = ^(CGFloat newValue) {
            [CSAppContext.shared.save setVolume:newValue forKey:key];
            [CSAppContext.shared.audio reloadSettings];
            [weakSliderSelf updateVolumeLabels];
        };
        [self.contentRoot addChild:slider];
        [_sliders addObject:slider];
    }
    [self addLabel:@"VOLUME CHANGES SAVE INSTANTLY" atPoint:CGPointMake(165, 57) scale:0.56
             color:[NSColor colorWithSRGBRed:0.39 green:0.27 blue:0.44 alpha:0.7]
         alignment:CSPixelTextAlignmentCenter zPosition:4].shadowEnabled = NO;

    [self addLabel:@"DIFFICULTY" atPoint:CGPointMake(324, 258) scale:0.78
             color:[NSColor colorWithSRGBRed:0.35 green:0.23 blue:0.41 alpha:1]
         alignment:CSPixelTextAlignmentLeft zPosition:4].shadowEnabled = NO;

    NSArray<NSString *> *presetKeys = @[@"chill", @"classic", @"spicy", @"insane", @"custom"];
    NSArray<NSString *> *presetTitles = @[@"CHILL", @"CLASSIC", @"SPICY", @"INSANE", @"CUSTOM"];
    NSArray<NSString *> *presetTextures = @[@"ui_button_sky", @"ui_button_mint", @"ui_button_yellow",
                                            @"ui_button_rose", @"ui_button_lavender"];
    for (NSInteger i = 0; i < presetKeys.count; i++) {
        CSPixelButtonNode *button = [[CSPixelButtonNode alloc] initWithText:presetTitles[i]
                                                                textureName:presetTextures[i]
                                                                       size:CGSizeMake(52, 22)
                                                                  fontScale:0.62];
        button.position = CGPointMake(351 + i * 55, 231);
        NSString *key = presetKeys[i];
        button.actionBlock = ^{ [weakSelf selectPreset:key]; };
        [_presetButtons addObject:button];
        [self addButton:button];
    }
    _presetMarker = [SKSpriteNode spriteNodeWithColor:[NSColor colorWithSRGBRed:0.93 green:0.44 blue:0.62 alpha:1]
                                                 size:CGSizeMake(50, 3)];
    _presetMarker.position = CGPointMake(351, 217);
    _presetMarker.zPosition = 5;
    [self.contentRoot addChild:_presetMarker];

    _difficultySummary = [self addLabel:@"" atPoint:CGPointMake(324, 202) scale:0.58
                                  color:[NSColor colorWithSRGBRed:0.40 green:0.28 blue:0.44 alpha:0.9]
                              alignment:CSPixelTextAlignmentLeft zPosition:4];
    _difficultySummary.shadowEnabled = NO;

    NSArray<NSDictionary *> *customRows = @[
        @{@"key": @"traffic", @"title": @"TRAFFIC", @"y": @179, @"step": @0.1},
        @{@"key": @"hazards", @"title": @"HAZARDS", @"y": @161, @"step": @0.1},
        @{@"key": @"pickups", @"title": @"PICKUPS", @"y": @143, @"step": @0.1},
        @{@"key": @"lives", @"title": @"LIVES", @"y": @125, @"step": @1},
        @{@"key": @"trafficSpeed", @"title": @"TRAFFIC SPEED", @"y": @107, @"step": @0.1},
    ];
    for (NSDictionary *row in customRows) {
        CGFloat y = [row[@"y"] doubleValue];
        CSPixelLabelNode *label = [self addLabel:row[@"title"] atPoint:CGPointMake(324, y) scale:0.58
                                           color:[NSColor colorWithSRGBRed:0.34 green:0.22 blue:0.40 alpha:1]
                                       alignment:CSPixelTextAlignmentLeft zPosition:4];
        label.shadowEnabled = NO;
        [_customNodes addObject:label];

        CSPixelLabelNode *value = [self addLabel:@"" atPoint:CGPointMake(492, y) scale:0.60
                                          color:[NSColor colorWithSRGBRed:0.29 green:0.18 blue:0.35 alpha:1]
                                      alignment:CSPixelTextAlignmentCenter zPosition:4];
        value.shadowEnabled = NO;
        value.name = [NSString stringWithFormat:@"custom_%@", row[@"key"]];
        [_customNodes addObject:value];

        CSPixelButtonNode *minus = [[CSPixelButtonNode alloc] initWithIcon:@"icon_arrow_left"
                                                                textureName:@"ui_button_lavender"
                                                                       size:CGSizeMake(19, 19)];
        minus.position = CGPointMake(523, y);
        NSString *key = row[@"key"];
        minus.actionBlock = ^{ [weakSelf adjustCustom:key delta:-1]; };
        [_customButtons addObject:minus];
        [self addButton:minus];
        [_customNodes addObject:minus];

        CSPixelButtonNode *plus = [[CSPixelButtonNode alloc] initWithIcon:@"icon_arrow_right"
                                                               textureName:@"ui_button_lavender"
                                                                      size:CGSizeMake(19, 19)];
        plus.position = CGPointMake(564, y);
        plus.actionBlock = ^{ [weakSelf adjustCustom:key delta:1]; };
        [_customButtons addObject:plus];
        [self addButton:plus];
        [_customNodes addObject:plus];
    }

    CSPixelButtonNode *assist = [[CSPixelButtonNode alloc] initWithText:@"ASSIST"
                                                             textureName:@"ui_button_sky"
                                                                    size:CGSizeMake(90, 18)
                                                               fontScale:0.68];
    assist.position = CGPointMake(372, 82);
    assist.actionBlock = ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf->_settings.assist = !strongSelf->_settings.assist;
        [CSAppContext.shared.save setDifficultySettings:strongSelf->_settings];
        [strongSelf updateAllControls];
        [CSAppContext.shared.audio playSFX:@"sfx_click"];
    };
    [self addButton:assist];
    _assistLabel = assist.label;

    CSPixelButtonNode *motion = [[CSPixelButtonNode alloc] initWithText:@"MOTION"
                                                             textureName:@"ui_button_sky"
                                                                    size:CGSizeMake(90, 18)
                                                               fontScale:0.68];
    motion.position = CGPointMake(468, 82);
    motion.actionBlock = ^{
        BOOL value = !CSAppContext.shared.save.reducedMotion;
        [CSAppContext.shared.save setReducedMotion:value];
        [weakSelf updateAllControls];
        [CSAppContext.shared.audio playSFX:@"sfx_click"];
    };
    [self addButton:motion];
    _motionLabel = motion.label;

    CSPixelButtonNode *mute = [[CSPixelButtonNode alloc] initWithText:@"MUTE"
                                                           textureName:@"ui_button_sky"
                                                                  size:CGSizeMake(74, 18)
                                                             fontScale:0.68];
    mute.position = CGPointMake(561, 82);
    mute.actionBlock = ^{
        [CSAppContext.shared.audio toggleMuted];
        [weakSelf updateAllControls];
        [CSAppContext.shared.audio playSFX:@"sfx_click"];
    };
    [self addButton:mute];
    _muteLabel = mute.label;

    _resetButton = [[CSPixelButtonNode alloc] initWithText:@"RESET PROGRESS"
                                                textureName:@"ui_button_disabled"
                                                       size:CGSizeMake(180, 18)
                                                  fontScale:0.62];
    _resetButton.position = CGPointMake(466, 56);
    _resetButton.actionBlock = ^{ [weakSelf resetProgress]; };
    [self addButton:_resetButton];
}

- (void)updateVolumeLabels {
    for (NSString *key in _volumeLabels) {
        CGFloat volume = [CSAppContext.shared.save volumeForKey:key];
        _volumeLabels[key].text = [NSString stringWithFormat:@"%ld%%", (long)round(volume * 100)];
    }
}

- (void)updateAllControls {
    [self updateVolumeLabels];
    NSInteger presetIndex = 1;
    switch (_settings.preset) {
        case CSDifficultyPresetChill: presetIndex = 0; break;
        case CSDifficultyPresetClassic: presetIndex = 1; break;
        case CSDifficultyPresetSpicy: presetIndex = 2; break;
        case CSDifficultyPresetInsane: presetIndex = 3; break;
        case CSDifficultyPresetCustom: presetIndex = 4; break;
    }
    _presetMarker.position = CGPointMake(351 + presetIndex * 55, 217);

    if (_settings.preset == CSDifficultyPresetCustom) {
        _difficultySummary.text = @"CUSTOM - TUNE EACH KNOB BELOW";
    } else {
        _difficultySummary.text = [NSString stringWithFormat:@"%@ - TRAFFIC %.1fx - HAZARDS %.1fx",
                                   [_settings displayName].uppercaseString,
                                   _settings.trafficFactor, _settings.hazardFactor];
    }

    BOOL custom = _settings.preset == CSDifficultyPresetCustom;
    for (SKNode *node in _customNodes) {
        if ([node isKindOfClass:[CSPixelButtonNode class]]) {
            node.hidden = !custom;
            ((CSPixelButtonNode *)node).enabled = custom;
        } else {
            // Keep the tuned values visible for presets so the panel always
            // explains what the current difficulty actually does.
            node.hidden = NO;
        }
    }

    NSArray<NSDictionary *> *customRows = @[
        @{@"key": @"traffic", @"value": @(_settings.trafficFactor), @"format": @"%.1fx"},
        @{@"key": @"hazards", @"value": @(_settings.hazardFactor), @"format": @"%.1fx"},
        @{@"key": @"pickups", @"value": @(_settings.pickupFactor), @"format": @"%.1fx"},
        @{@"key": @"lives", @"value": @(_settings.lives), @"format": @"%ld"},
        @{@"key": @"trafficSpeed", @"value": @(_settings.trafficSpeedFactor), @"format": @"%.1fx"},
    ];
    for (NSDictionary *row in customRows) {
        CSPixelLabelNode *label = (CSPixelLabelNode *)[self childNodeWithName:
            [NSString stringWithFormat:@"//custom_%@", row[@"key"]]];
        if (!label) continue;
        if ([row[@"key"] isEqualToString:@"lives"]) {
            label.text = [NSString stringWithFormat:@"%ld", (long)_settings.lives];
        } else {
            label.text = [NSString stringWithFormat:row[@"format"], [row[@"value"] doubleValue]];
        }
    }

    _assistLabel.text = _settings.assist ? @"ASSIST ON" : @"ASSIST OFF";
    _motionLabel.text = CSAppContext.shared.save.reducedMotion ? @"MOTION OFF" : @"MOTION ON";
    _muteLabel.text = [CSAppContext.shared.audio isMuted] ? @"MUTED" : @"MUTE";
}

- (void)selectPreset:(NSString *)key {
    CSDifficultyPreset preset = CSDifficultyPresetFromString(key);
    _settings = [CSDifficultySettings settingsForPreset:preset];
    [CSAppContext.shared.save setDifficultySettings:_settings];
    [self updateAllControls];
    [CSAppContext.shared.audio playSFX:@"sfx_click"];
}

- (void)adjustCustom:(NSString *)key delta:(NSInteger)delta {
    if (_settings.preset != CSDifficultyPresetCustom) return;
    if ([key isEqualToString:@"traffic"]) {
        _settings.trafficFactor = MIN(1.8, MAX(0.5, round((_settings.trafficFactor + delta * 0.1) * 10) / 10.0));
    } else if ([key isEqualToString:@"hazards"]) {
        _settings.hazardFactor = MIN(1.8, MAX(0.5, round((_settings.hazardFactor + delta * 0.1) * 10) / 10.0));
    } else if ([key isEqualToString:@"pickups"]) {
        _settings.pickupFactor = MIN(1.5, MAX(0.5, round((_settings.pickupFactor + delta * 0.1) * 10) / 10.0));
    } else if ([key isEqualToString:@"lives"]) {
        _settings.lives = MIN(5, MAX(1, _settings.lives + delta));
    } else if ([key isEqualToString:@"trafficSpeed"]) {
        _settings.trafficSpeedFactor = MIN(1.5, MAX(0.7, round((_settings.trafficSpeedFactor + delta * 0.1) * 10) / 10.0));
    }
    [CSAppContext.shared.save setDifficultySettings:_settings];
    [self updateAllControls];
    [CSAppContext.shared.audio playSFX:@"sfx_click"];
}

- (void)resetProgress {
    CSAppContext *context = CSAppContext.shared;
    if (!_resetArmed) {
        _resetArmed = YES;
        _resetButton.text = @"CLICK AGAIN TO CONFIRM";
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf->_resetArmed = NO;
            strongSelf->_resetButton.text = @"RESET PROGRESS";
        });
        return;
    }
    _resetArmed = NO;
    _resetButton.text = @"RESET PROGRESS";
    [context.save resetProgress];
    [self updateAllControls];
    [context.audio playSFX:@"sfx_unlock"];
    [self showToast:@"PROGRESS HAS BEEN RESET"];
}

#pragma mark - Slider tracking

- (void)gameViewMouseDownAtPoint:(CGPoint)point button:(NSInteger)button {
    if (button == 0) {
        for (CSSliderNode *slider in _sliders) {
            if ([slider containsScenePoint:point]) {
                _activeSlider = slider;
                [slider beginTrackingAtPoint:point];
                return;
            }
        }
    }
    [super gameViewMouseDownAtPoint:point button:button];
}

- (void)gameViewMouseDraggedToPoint:(CGPoint)point button:(NSInteger)button {
    if (button == 0 && _activeSlider) {
        [_activeSlider updateTrackingAtPoint:point];
        return;
    }
    [super gameViewMouseDraggedToPoint:point button:button];
}

- (void)gameViewMouseUpAtPoint:(CGPoint)point button:(NSInteger)button {
    _activeSlider = nil;
    [super gameViewMouseUpAtPoint:point button:button];
}

- (void)goBack {
    [CSAppContext.shared.viewController presentMenu];
}

@end
