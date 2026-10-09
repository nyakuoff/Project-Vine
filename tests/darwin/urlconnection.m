// Regression test (runs inside Darling): NSURLConnection synchronous HTTPS GET (no credentials).
#include "../../shims/vine.h"
int printf(const char *, ...);
@interface NSString : NSObject + (id)stringWithUTF8String:(const char *)s; - (const char *)UTF8String; @end
@interface NSURL : NSObject + (id)URLWithString:(NSString *)s; @end
@interface NSURLRequest : NSObject + (id)requestWithURL:(NSURL *)u; @end
@interface NSError : NSObject - (long)code; - (NSString *)domain; - (NSString *)localizedDescription; @end
@interface NSHTTPURLResponse : NSObject - (long)statusCode; @end
@interface NSData : NSObject - (unsigned long)length; - (const void *)bytes; @end
@interface NSURLConnection : NSObject
+ (NSData *)sendSynchronousRequest:(NSURLRequest *)r returningResponse:(NSHTTPURLResponse **)resp error:(NSError **)e;
@end
int main(int argc, char **argv) {
    const char *url = argc > 1 ? argv[1] : "https://clientsettingscdn.roblox.com/v2/client-version/MacPlayer";
    NSHTTPURLResponse *r = 0; NSError *e = 0;
    NSData *d = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithUTF8String:url]]]
                                      returningResponse:&r error:&e];
    if (e || !r) { printf("FAIL %s: error %s %ld %s\n", url, e ? [[e domain] UTF8String] : "-", e ? [e code] : 0, e ? [[e localizedDescription] UTF8String] : "no response"); return 1; }
    printf("%s %s: HTTP %ld, %lu bytes: %.120s\n", [r statusCode] == 200 ? "PASS" : "FAIL", url, [r statusCode], [d length], d ? (const char *)[d bytes] : "");
    return [r statusCode] != 200;
}
