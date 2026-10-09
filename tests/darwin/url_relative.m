// Regression test (runs inside Darling): file URLs relative to a base URL must have a path.
// Roblox: [[[NSURL fileURLWithPath:@"InstallerInfo.log" relativeToURL:dir] path] UTF8String]
#include "../../shims/vine.h"
int printf(const char *, ...);
@interface NSString : NSObject - (const char *)UTF8String; @end
@interface NSURL : NSObject
+ (id)fileURLWithPath:(NSString *)p isDirectory:(BOOL)d;
+ (id)fileURLWithPath:(NSString *)p relativeToURL:(NSURL *)base;
+ (id)URLWithString:(NSString *)s relativeToURL:(NSURL *)base;
- (NSString *)path; - (NSString *)absoluteString; - (NSString *)relativePath;
@end
static int check(const char *what, NSURL *u, const char *want) {
    const char *p = [[u path] UTF8String];
    int ok = p && !__builtin_strcmp(p, want);
    printf("%s %s: path=%s abs=%s\n", ok ? "PASS" : "FAIL", what, p ? p : "(null)",
           [[u absoluteString] UTF8String] ?: "(null)");
    return !ok;
}
int main(void) {
    NSURL *dir = [NSURL fileURLWithPath:@"/tmp/logs" isDirectory:1];
    int bad = check("absolute dir", dir, "/tmp/logs");
    bad += check("file relativeToURL", [NSURL fileURLWithPath:@"InstallerInfo.log" relativeToURL:dir], "/tmp/logs/InstallerInfo.log");
    bad += check("string relativeToURL", [NSURL URLWithString:@"a.txt" relativeToURL:dir], "/tmp/logs/a.txt");
    return bad;
}
