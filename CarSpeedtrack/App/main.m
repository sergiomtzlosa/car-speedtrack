#import <Cocoa/Cocoa.h>
#import "CSAppDelegate.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        CSAppDelegate *delegate = [[CSAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
        (void)delegate;
    }
    return 0;
}
