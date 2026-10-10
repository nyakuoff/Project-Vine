// Darwin test (runs in Darling): cookies with an expiry survive a restart; session cookies don't.
// Usage: cookie_persist set   then (new process)   cookie_persist check
#include "../../shims/vine.h"
int printf(const char *, ...);
@interface NSObject (T)
+ (id)sharedHTTPCookieStorage; + (id)cookieWithProperties:(id)p; + (id)dateWithTimeIntervalSinceNow:(double)s;
+ (id)dictionaryWithObjects:(const id *)o forKeys:(const id *)k count:(unsigned long)n;
- (id)cookies; - (void)setCookie:(id)c; - (id)name; - (unsigned long)count; - (id)objectAtIndex:(unsigned long)i;
- (BOOL)isEqualToString:(id)s;
@end
extern const void *kCFBooleanFalse;
static id cookie(id name, BOOL persistent) {
    id k[] = {@"Name", @"Value", @"Domain", @"Path", @"Secure", @"HTTPOnly", @"Expires"};
    id v[] = {name, @"1", @"vine.test", @"/", (id)kCFBooleanFalse, (id)kCFBooleanFalse,
              [objc_getClass("NSDate") dateWithTimeIntervalSinceNow:86400]};
    return [objc_getClass("NSHTTPCookie") cookieWithProperties:[objc_getClass("NSDictionary") dictionaryWithObjects:v forKeys:k count:persistent ? 7 : 6]];
}
int main(int argc, char **argv) {
    id store = [objc_getClass("NSHTTPCookieStorage") sharedHTTPCookieStorage];
    if (argc > 1 && !strcmp(argv[1], "set")) {
        [store setCookie:cookie(@"VinePersistent", 1)];
        [store setCookie:cookie(@"VineSession", 0)];
        printf("set 2 cookies\n");
        return 0;
    }
    int persistent = 0, session = 0;
    id all = [store cookies];
    for (unsigned long i = 0; i < [all count]; i++) {
        id n = [[all objectAtIndex:i] name];
        if ([n isEqualToString:@"VinePersistent"]) persistent = 1;
        if ([n isEqualToString:@"VineSession"]) session = 1;
    }
    printf("%s persistent cookie restored\n%s session cookie not restored\n", persistent ? "PASS" : "FAIL", session ? "FAIL" : "PASS");
    return !persistent + session;
}
