#import "CSAppDelegate.h"
#import "CSAppContext.h"
#import "CSGameViewController.h"
#import "CSGameScene.h"
#import "CSSaveManager.h"
#import "CSAudioManager.h"
#import <SpriteKit/SpriteKit.h>

@interface CSAppDelegate ()
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) CSGameViewController *viewController;
@end

@implementation CSAppDelegate

#pragma mark - Lifecycle

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [CSAppContext bootstrap];
    [self buildMainMenu];

    CSGameViewController *viewController = [[CSGameViewController alloc] init];
    self.viewController = viewController;
    CSAppContext.shared.viewController = viewController;

    NSRect contentRect = NSMakeRect(0, 0, 1280, 720);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:contentRect
                                                  styleMask:style
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    window.title = @"Car Speedtrack";
    window.backgroundColor = [NSColor blackColor];
    window.contentViewController = viewController;
    window.contentMinSize = NSMakeSize(960, 540);
    window.contentAspectRatio = NSMakeSize(16.0, 9.0);
    window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    window.releasedWhenClosed = NO;
    window.delegate = self;

    [window center];
    [window makeKeyAndOrderFront:nil];
    [window makeFirstResponder:viewController.view];
    [NSApp activateIgnoringOtherApps:YES];

    self.window = window;

    if (CSAppContext.shared.snapshotPath.length > 0) {
        NSTimeInterval delay = CSAppContext.shared.snapshotDelay;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self writeSnapshot];
        });
    }
}

- (void)writeSnapshot {
    NSString *path = CSAppContext.shared.snapshotPath;
    SKView *view = (SKView *)self.viewController.view;
    SKScene *scene = view.scene;
    if (![view isKindOfClass:[SKView class]] || !scene) {
        NSLog(@"CarSpeedtrack: snapshot failed - no scene");
        [NSApp terminate:nil];
        return;
    }

    SKTexture *texture = [view textureFromNode:scene];
    CGImageRef image = texture.CGImage;
    if (!image) {
        NSLog(@"CarSpeedtrack: snapshot failed - no texture image");
        [NSApp terminate:nil];
        return;
    }
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSError *error = nil;
    if (![png writeToFile:path options:NSDataWritingAtomic error:&error]) {
        NSLog(@"CarSpeedtrack: snapshot write failed: %@", error);
    } else {
        NSLog(@"CarSpeedtrack: wrote snapshot %@ (%.0fx%.0f)", path, rep.size.width, rep.size.height);
    }
    [NSApp terminate:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [CSAppContext.shared.save saveNow];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#pragma mark - Menu

- (void)buildMainMenu {
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: @"Car Speedtrack";
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];

    NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:appName action:nil keyEquivalent:@""];
    [mainMenu addItem:appItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:appName];
    NSMenuItem *aboutItem = [appMenu addItemWithTitle:[NSString stringWithFormat:@"About %@", appName]
                                               action:@selector(showAboutPanel:)
                                        keyEquivalent:@""];
    aboutItem.target = self;
    [appMenu addItem:[NSMenuItem separatorItem]];
    [self addMenuItemToMenu:appMenu title:@"Settings..." action:@selector(showSettings:) key:@"," modifiers:NSEventModifierFlagCommand];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"Hide %@", appName] action:@selector(hide:) keyEquivalent:@"h"];
    NSMenuItem *hideOthers = [appMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    hideOthers.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    [appMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"Quit %@", appName] action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;

    NSMenuItem *raceItem = [[NSMenuItem alloc] initWithTitle:@"Race" action:nil keyEquivalent:@""];
    [mainMenu addItem:raceItem];
    NSMenu *raceMenu = [[NSMenu alloc] initWithTitle:@"Race"];
    [self addMenuItemToMenu:raceMenu title:@"New Race" action:@selector(newRace:) key:@"n" modifiers:NSEventModifierFlagCommand];
    [self addMenuItemToMenu:raceMenu title:@"Pause / Resume" action:@selector(togglePause:) key:@"p" modifiers:NSEventModifierFlagCommand];
    [self addMenuItemToMenu:raceMenu title:@"Retry Level" action:@selector(retryRace:) key:@"r" modifiers:NSEventModifierFlagCommand];
    [raceMenu addItem:[NSMenuItem separatorItem]];
    [self addMenuItemToMenu:raceMenu title:@"Level Select" action:@selector(showLevelSelect:) key:@"l" modifiers:NSEventModifierFlagCommand];
    [self addMenuItemToMenu:raceMenu title:@"Garage" action:@selector(showGarage:) key:@"g" modifiers:NSEventModifierFlagCommand];
    [self addMenuItemToMenu:raceMenu title:@"High Scores" action:@selector(showScores:) key:@"k" modifiers:NSEventModifierFlagCommand];
    [self addMenuItemToMenu:raceMenu title:@"Main Menu" action:@selector(showMainMenu:) key:@"m"
                  modifiers:NSEventModifierFlagCommand | NSEventModifierFlagShift];
    [raceMenu addItem:[NSMenuItem separatorItem]];
    [self addMenuItemToMenu:raceMenu title:@"Mute Audio" action:@selector(toggleMute:) key:@"u"
                  modifiers:NSEventModifierFlagCommand | NSEventModifierFlagShift];
    raceItem.submenu = raceMenu;

    NSMenuItem *windowItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
    [mainMenu addItem:windowItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *fullScreen = [windowMenu addItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
    fullScreen.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagControl;
    windowItem.submenu = windowMenu;
    NSApp.windowsMenu = windowMenu;

    NSApp.mainMenu = mainMenu;
}

- (void)addMenuItemToMenu:(NSMenu *)menu title:(NSString *)title action:(SEL)action
                      key:(NSString *)key modifiers:(NSEventModifierFlags)modifiers {
    NSMenuItem *item = [menu addItemWithTitle:title action:action keyEquivalent:key];
    item.keyEquivalentModifierMask = modifiers;
    item.target = self;
}

#pragma mark - Actions

- (void)showAboutPanel:(id)sender {
    NSString *name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: @"Car Speedtrack";
    NSAttributedString *credits = [[NSAttributedString alloc]
        initWithString:@"A sunny top-down road trip built with SpriteKit and Objective-C.\n"
                         @"Every track, sprite, and note is generated for the game."
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:11],
                NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
            }];
    [NSApp orderFrontStandardAboutPanelWithOptions:@{
        NSAboutPanelOptionApplicationName: name,
        NSAboutPanelOptionApplicationVersion: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0",
        NSAboutPanelOptionVersion: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"1",
        NSAboutPanelOptionCredits: credits,
    }];
}

- (void)newRace:(id)sender {
    NSInteger levelID = [CSAppContext.shared.save nextLevelToPlay];
    [self.viewController presentBriefingForLevelID:levelID];
}

- (void)togglePause:(id)sender {
    [self.viewController menuTogglePause];
}

- (void)retryRace:(id)sender {
    [self.viewController menuRetry];
}

- (void)showLevelSelect:(id)sender {
    [self.viewController presentLevelSelect];
}

- (void)showGarage:(id)sender {
    [self.viewController presentGarage];
}

- (void)showScores:(id)sender {
    [self.viewController presentScores];
}

- (void)showSettings:(id)sender {
    [self.viewController presentSettings];
}

- (void)showMainMenu:(id)sender {
    [self.viewController presentMenu];
}

- (void)toggleMute:(id)sender {
    [CSAppContext.shared.audio toggleMuted];
}

#pragma mark - Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = menuItem.action;
    if (action == @selector(togglePause:) || action == @selector(retryRace:)) {
        return [self.viewController.currentScene isKindOfClass:[CSGameScene class]];
    }
    if (action == @selector(toggleMute:)) {
        menuItem.state = CSAppContext.shared.audio.isMuted ? NSControlStateValueOn : NSControlStateValueOff;
    }
    return YES;
}

@end
