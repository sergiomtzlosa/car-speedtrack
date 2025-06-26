#import "CSGameView.h"

@interface CSGameView ()
@property (nonatomic, strong, nullable) id windowObserver;
@end

@implementation CSGameView {
    NSTrackingArea *_trackingArea;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = NSColor.blackColor.CGColor;
        self.preferredFramesPerSecond = 60;
        self.ignoresSiblingOrder = YES;
        self.shouldCullNonVisibleNodes = YES;
        self.allowsTransparency = NO;
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    self.window.acceptsMouseMovedEvents = YES;
    [[NSNotificationCenter defaultCenter] removeObserver:self.windowObserver];
    self.windowObserver = nil;
    if (self.window) {
        __weak typeof(self) weakSelf = self;
        self.windowObserver = [[NSNotificationCenter defaultCenter]
            addObserverForName:NSWindowDidResignKeyNotification
                        object:self.window
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *note) {
                        [weakSelf.inputTarget gameViewFocusLost];
                    }];
    }
    [self.window makeFirstResponder:self];
    [self updateTrackingAreas];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.windowObserver];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (_trackingArea) [self removeTrackingArea:_trackingArea];
    _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                 options:NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited |
                                                         NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
                                                   owner:self
                                                userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (CGPoint)scenePointForEvent:(NSEvent *)event {
    NSPoint local = [self convertPoint:event.locationInWindow fromView:nil];
    SKScene *scene = self.scene;
    return scene ? [scene convertPointFromView:local] : CGPointMake(local.x, local.y);
}

- (void)keyDown:(NSEvent *)event {
    id<CSGameViewInput> target = self.inputTarget;
    if ([target respondsToSelector:@selector(gameViewKeyDown:)]) {
        [target gameViewKeyDown:event];
    }
}

- (void)keyUp:(NSEvent *)event {
    id<CSGameViewInput> target = self.inputTarget;
    if ([target respondsToSelector:@selector(gameViewKeyUp:)]) {
        [target gameViewKeyUp:event];
    }
}

- (void)flagsChanged:(NSEvent *)event {
    [super flagsChanged:event];
}

- (void)mouseMoved:(NSEvent *)event {
    id<CSGameViewInput> target = self.inputTarget;
    if ([target respondsToSelector:@selector(gameViewMouseMovedToPoint:)]) {
        [target gameViewMouseMovedToPoint:[self scenePointForEvent:event]];
    }
}

- (void)mouseEntered:(NSEvent *)event {
    [self mouseMoved:event];
}

- (void)mouseDown:(NSEvent *)event {
    [self.window makeFirstResponder:self];
    id<CSGameViewInput> target = self.inputTarget;
    if ([target respondsToSelector:@selector(gameViewMouseDownAtPoint:button:)]) {
        [target gameViewMouseDownAtPoint:[self scenePointForEvent:event] button:0];
    }
}

- (void)rightMouseDown:(NSEvent *)event {
    [self.window makeFirstResponder:self];
    id<CSGameViewInput> target = self.inputTarget;
    if ([target respondsToSelector:@selector(gameViewMouseDownAtPoint:button:)]) {
        [target gameViewMouseDownAtPoint:[self scenePointForEvent:event] button:1];
    }
}

- (void)mouseDragged:(NSEvent *)event {
    id<CSGameViewInput> target = self.inputTarget;
    if ([target respondsToSelector:@selector(gameViewMouseDraggedToPoint:button:)]) {
        [target gameViewMouseDraggedToPoint:[self scenePointForEvent:event] button:0];
    }
}

- (void)rightMouseDragged:(NSEvent *)event {
    id<CSGameViewInput> target = self.inputTarget;
    if ([target respondsToSelector:@selector(gameViewMouseDraggedToPoint:button:)]) {
        [target gameViewMouseDraggedToPoint:[self scenePointForEvent:event] button:1];
    }
}

- (void)mouseUp:(NSEvent *)event {
    id<CSGameViewInput> target = self.inputTarget;
    if ([target respondsToSelector:@selector(gameViewMouseUpAtPoint:button:)]) {
        [target gameViewMouseUpAtPoint:[self scenePointForEvent:event] button:0];
    }
}

- (void)rightMouseUp:(NSEvent *)event {
    id<CSGameViewInput> target = self.inputTarget;
    if ([target respondsToSelector:@selector(gameViewMouseUpAtPoint:button:)]) {
        [target gameViewMouseUpAtPoint:[self scenePointForEvent:event] button:1];
    }
}

- (void)scrollWheel:(NSEvent *)event {
    id<CSGameViewInput> target = self.inputTarget;
    if ([target respondsToSelector:@selector(gameViewScrollWheel:)]) {
        [target gameViewScrollWheel:event.scrollingDeltaY];
    }
}

- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:self.bounds cursor:NSCursor.arrowCursor];
}

@end
