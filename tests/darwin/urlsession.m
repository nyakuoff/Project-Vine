// Regression test (runs inside Darling): NSURLSession GET of a Roblox endpoint (no credentials).
#include "../../shims/vine.h"
int printf(const char *, ...);
typedef struct dispatch_semaphore_s *dispatch_semaphore_t;
dispatch_semaphore_t dispatch_semaphore_create(long);
long dispatch_semaphore_signal(dispatch_semaphore_t);
long dispatch_semaphore_wait(dispatch_semaphore_t, uint64_t);
uint64_t dispatch_time(uint64_t, int64_t);
@interface NSString : NSObject + (id)stringWithUTF8String:(const char *)s; - (const char *)UTF8String; @end
@interface NSURL : NSObject + (id)URLWithString:(NSString *)s; @end
@interface NSError : NSObject - (long)code; - (NSString *)domain; - (NSString *)localizedDescription; @end
@interface NSHTTPURLResponse : NSObject - (long)statusCode; @end
@interface NSData : NSObject - (unsigned long)length; @end
@interface NSURLSessionTask : NSObject - (void)resume; @end
@interface NSURLSessionConfiguration : NSObject + (id)defaultSessionConfiguration; @end
@interface NSURLSession : NSObject
+ (NSURLSession *)sharedSession;
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)c;
- (NSURLSessionTask *)dataTaskWithURL:(NSURL *)u completionHandler:(void (^)(NSData *, NSHTTPURLResponse *, NSError *))h;
@end
static int get(NSURLSession *session, const char *url) {
    __block int rc = 1;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [[session dataTaskWithURL:[NSURL URLWithString:[NSString stringWithUTF8String:url]]
        completionHandler:^(NSData *d, NSHTTPURLResponse *r, NSError *e) {
            if (e) printf("FAIL %s: error %s %ld %s\n", url, [[e domain] UTF8String], [e code], [[e localizedDescription] UTF8String]);
            else { printf("%s %s: HTTP %ld, %lu bytes\n", [r statusCode] == 200 ? "PASS" : "FAIL", url, [r statusCode], [d length]); rc = [r statusCode] != 200; }
            dispatch_semaphore_signal(done);
        }] resume];
    if (dispatch_semaphore_wait(done, dispatch_time(0, 30LL * 1000000000))) { printf("FAIL %s: timeout\n", url); return 2; }
    return rc;
}
int main(int argc, char **argv) {
    const char *url = argc > 1 ? argv[1] : "https://clientsettingscdn.roblox.com/v2/client-version/MacPlayer";
    printf("-- sharedSession\n");
    int bad = get([NSURLSession sharedSession], url);
    printf("-- sessionWithConfiguration:defaultSessionConfiguration\n");
    return bad + get([NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]], url);
}
