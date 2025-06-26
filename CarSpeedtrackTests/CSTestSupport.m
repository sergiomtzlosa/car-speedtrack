#import "CSTestSupport.h"
#import "CSGameCatalog.h"

@implementation CSTestSupport
@end

static NSBundle *CSTestBundle(void) {
    return [NSBundle bundleForClass:[CSTestSupport class]];
}

CSGameCatalog *CSLoadTestCatalog(NSError **error) {
    NSBundle *bundle = CSTestBundle();
    NSURL *levels = [bundle URLForResource:@"levels" withExtension:@"json"];
    NSURL *cars = [bundle URLForResource:@"cars" withExtension:@"json"];
    if (!levels || !cars) {
        if (error) {
            *error = [NSError errorWithDomain:@"CarSpeedtrackTests"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"levels.json or cars.json missing from test bundle"}];
        }
        return nil;
    }
    return [[CSGameCatalog alloc] initWithLevelsURL:levels carsURL:cars error:error];
}

NSDictionary<NSString *, id> *CSLoadTestJSON(NSString *name, NSError **error) {
    NSURL *url = [CSTestBundle() URLForResource:name withExtension:@"json"];
    if (!url) {
        if (error) {
            *error = [NSError errorWithDomain:@"CarSpeedtrackTests"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"%@.json missing from test bundle", name]}];
        }
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!data) return nil;
    id payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    return [payload isKindOfClass:[NSDictionary class]] ? payload : nil;
}

NSURL *CSCreateTestDirectory(void) {
    NSURL *url = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
        URLByAppendingPathComponent:[NSString stringWithFormat:@"CarSpeedtrackTests-%@", NSUUID.UUID.UUIDString]
                        isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:NULL];
    return url;
}

void CSRemoveTestDirectory(NSURL *directory) {
    if (directory) {
        [[NSFileManager defaultManager] removeItemAtURL:directory error:NULL];
    }
}
