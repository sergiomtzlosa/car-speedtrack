#import "CSScreenScene.h"
#import "CSAssetCatalog.h"
#import "CSAppContext.h"
#import "CSAudioManager.h"
#import "CSGameViewController.h"

@implementation CSScreenScene {
    BOOL _didBuildBackdrop;
    CSPixelLabelNode *_toastLabel;
    SKAction *_toastSequence;
}

- (instancetype)initWithSize:(CGSize)size {
    self = [super initWithSize:size];
    if (self) {
        self.anchorPoint = CGPointZero;
        self.backgroundColor = [NSColor colorWithSRGBRed:0.13 green:0.09 blue:0.16 alpha:1.0];
        self.scaleMode = SKSceneScaleModeAspectFit;
        _buttons = [NSMutableArray array];
        _screenMusicName = @"music_menu";
        _musicLoops = YES;
        _contentRoot = [SKNode node];
        _contentRoot.zPosition = 0;
        [self addChild:_contentRoot];
        _focusedIndex = -1;
    }
    return self;
}

- (void)buildBackdropIfNeeded {
    if (_didBuildBackdrop) return;
    _didBuildBackdrop = YES;
    SKSpriteNode *background = [SKSpriteNode spriteNodeWithTexture:
        [[CSAssetCatalog shared] textureNamed:@"bg_screen" fallback:@"bg_menu"]];
    background.position = CGPointMake(320, 180);
    background.zPosition = -100;
    background.size = CGSizeMake(640, 360);
    [self addChild:background];
}

- (void)didMoveToView:(SKView *)view {
    [super didMoveToView:view];
    [self buildBackdropIfNeeded];
    ((CSGameView *)view).inputTarget = self;
    if (self.view.window) [self.view.window makeFirstResponder:self.view];
    if (self.screenMusicName.length) {
        [CSAppContext.shared.audio playMusic:self.screenMusicName loop:self.musicLoops];
    }
    if (self.buttons.count > 0 && self.focusedIndex < 0) {
        [self focusButtonAtIndex:0];
    }
}

- (void)willMoveFromView:(SKView *)view {
    [super willMoveFromView:view];
    CSGameView *gameView = (CSGameView *)view;
    if (gameView.inputTarget == self) gameView.inputTarget = nil;
}

#pragma mark - Helpers

- (void)addButton:(CSPixelButtonNode *)button {
    button.zPosition = 20;
    [self.buttons addObject:button];
    [self addChild:button];
    if (self.focusedIndex < 0) {
        [self focusButtonAtIndex:self.buttons.count - 1];
    }
}

- (void)focusButtonAtIndex:(NSInteger)index {
    if (self.buttons.count == 0) {
        self.focusedIndex = -1;
        return;
    }
    NSInteger clamped = ((index % (NSInteger)self.buttons.count) + (NSInteger)self.buttons.count) %
                        (NSInteger)self.buttons.count;
    for (NSUInteger i = 0; i < self.buttons.count; i++) {
        self.buttons[i].focused = ((NSInteger)i == clamped);
    }
    self.focusedIndex = clamped;
}

- (void)refreshFocus {
    NSInteger current = self.focusedIndex;
    self.focusedIndex = -1;
    [self focusButtonAtIndex:current];
}

- (void)moveFocus:(NSInteger)delta {
    NSInteger count = (NSInteger)self.buttons.count;
    if (count == 0) return;
    NSInteger current = self.focusedIndex < 0 ? 0 : self.focusedIndex;
    NSInteger step = delta >= 0 ? 1 : -1;
    NSInteger index = current;
    for (NSInteger tries = 0; tries < count; tries++) {
        index = ((index + step) % count + count) % count;
        CSPixelButtonNode *candidate = self.buttons[index];
        if (!candidate.hidden && candidate.alpha > 0.01) {
            [self focusButtonAtIndex:index];
            [CSAppContext.shared.audio playSFX:@"sfx_hover"];
            return;
        }
    }
}

- (void)activateFocusedButton {
    if (self.focusedIndex < 0 || self.focusedIndex >= (NSInteger)self.buttons.count) return;
    CSPixelButtonNode *button = self.buttons[self.focusedIndex];
    [button activate];
}

- (void)goBack {
    [CSAppContext.shared.viewController presentMenu];
}

- (void)playClick {
    [CSAppContext.shared.audio playSFX:@"sfx_click"];
}

- (CSPixelLabelNode *)addLabel:(NSString *)text atPoint:(CGPoint)point scale:(CGFloat)scale
                          color:(NSColor *)color alignment:(CSPixelTextAlignment)alignment
                      zPosition:(CGFloat)z {
    CSPixelLabelNode *label = [[CSPixelLabelNode alloc] initWithText:text fontScale:scale color:color];
    label.alignment = alignment;
    label.position = point;
    label.zPosition = z;
    label.shadowEnabled = YES;
    [self.contentRoot addChild:label];
    return label;
}

- (CSPixelPanelNode *)addPanelWithTexture:(NSString *)texture size:(CGSize)size
                                 position:(CGPoint)position zPosition:(CGFloat)z {
    CSPixelPanelNode *panel = [[CSPixelPanelNode alloc] initWithTextureName:texture size:size];
    panel.position = position;
    panel.zPosition = z;
    [self.contentRoot addChild:panel];
    return panel;
}

- (void)showToast:(NSString *)message {
    if (!_toastLabel) {
        _toastLabel = [[CSPixelLabelNode alloc] initWithText:message fontScale:1.2
                                                       color:[NSColor colorWithSRGBRed:1 green:0.97 blue:0.86 alpha:1]];
        _toastLabel.position = CGPointMake(320, 320);
        _toastLabel.zPosition = 600;
        _toastLabel.shadowEnabled = YES;
        [self addChild:_toastLabel];
    }
    [_toastLabel removeAllActions];
    _toastLabel.text = message;
    _toastLabel.alpha = 1.0;
    _toastLabel.position = CGPointMake(320, 320);
    [_toastLabel runAction:[SKAction sequence:@[
        [SKAction waitForDuration:1.0],
        [SKAction fadeOutWithDuration:0.45],
    ]]];
}

#pragma mark - Input

- (void)gameViewKeyDown:(NSEvent *)event {
    if (event.modifierFlags & NSEventModifierFlagCommand) return;
    unichar key = event.keyCode;
    if (key == 123 || key == 126) {           // left / up
        [self moveFocus:-1];
    } else if (key == 124 || key == 125) {    // right / down
        [self moveFocus:1];
    } else if (key == 48) {                   // tab
        [self moveFocus:(event.modifierFlags & NSEventModifierFlagShift) ? -1 : 1];
    } else if (key == 36 || key == 76 || key == 49) { // return / enter / space
        [self activateFocusedButton];
    } else if (key == 53) {                   // escape
        [self goBack];
    } else {
        NSString *characters = event.charactersIgnoringModifiers.lowercaseString;
        if ([characters isEqualToString:@"m"]) {
            [CSAppContext.shared.audio toggleMuted];
        }
    }
}

- (void)gameViewKeyUp:(NSEvent *)event {
}

- (void)gameViewMouseMovedToPoint:(CGPoint)point {
    for (NSUInteger i = 0; i < self.buttons.count; i++) {
        CSPixelButtonNode *button = self.buttons[i];
        if ([button containsScenePoint:point]) {
            if (self.focusedIndex != (NSInteger)i) {
                [self focusButtonAtIndex:(NSInteger)i];
                [CSAppContext.shared.audio playSFX:@"sfx_hover"];
            }
            return;
        }
    }
}

- (void)gameViewMouseDownAtPoint:(CGPoint)point button:(NSInteger)button {
    if (button != 0) return;
    for (NSUInteger i = 0; i < self.buttons.count; i++) {
        CSPixelButtonNode *candidate = self.buttons[i];
        if ([candidate containsScenePoint:point]) {
            [self focusButtonAtIndex:(NSInteger)i];
            [self playClick];
            [candidate activate];
            return;
        }
    }
}

- (void)gameViewMouseDraggedToPoint:(CGPoint)point button:(NSInteger)button {
}

- (void)gameViewMouseUpAtPoint:(CGPoint)point button:(NSInteger)button {
}

- (void)gameViewScrollWheel:(CGFloat)delta {
    if (fabs(delta) < 0.1) return;
    [self moveFocus:delta > 0 ? -1 : 1];
}

- (void)gameViewFocusLost {
    // Subclasses that own live gameplay pause; static screens keep their state.
}

@end
