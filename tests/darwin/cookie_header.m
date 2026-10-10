// Darwin test (runs in Darling): a cookie from a Set-Cookie header with Expires / Max-Age is
// persistent (has an expiry) — the path Roblox's login cookie takes. Test domain only.
#include "../../shims/vine.h"
int printf(const char *, ...);
@interface NSObject (T)
+ (id)cookiesWithResponseHeaderFields:(id)h forURL:(id)u; + (id)URLWithString:(id)s;
+ (id)dictionaryWithObjects:(const id *)o forKeys:(const id *)k count:(unsigned long)n;
- (unsigned long)count; - (id)objectAtIndex:(unsigned long)i; - (id)name; - (id)expiresDate; - (BOOL)isSessionOnly;
- (id)properties; - (id)description; - (const char *)UTF8String;
+ (id)sharedHTTPCookieStorage; - (void)setCookies:(id)c forURL:(id)u mainDocumentURL:(id)m; - (id)cookiesForURL:(id)u;
- (void)deleteCookie:(id)c;
@end
int main(void) {
    const char *hdr[] = {"A=1; domain=.vine.test; path=/; expires=Thu, 09 Oct 2056 22:00:00 GMT; secure; HttpOnly",
                         "B=2; Max-Age=3600; path=/", "C=3; path=/"};
    int fails = 0;
    for (int i = 0; i < 3; i++) {
        id k[] = {@"Set-Cookie"}, v[] = {[objc_getClass("NSString") stringWithUTF8String:hdr[i]]};
        id h = [objc_getClass("NSDictionary") dictionaryWithObjects:v forKeys:k count:1];
        id cs = [objc_getClass("NSHTTPCookie") cookiesWithResponseHeaderFields:h forURL:[objc_getClass("NSURL") URLWithString:@"https://www.vine.test/"]];
        id c = [cs count] ? [cs objectAtIndex:0] : 0;
        int want = i < 2, got = c && [c expiresDate] && ![c isSessionOnly];
        printf("%s %s: expires=%s session=%d\n", got == want ? "PASS" : "FAIL", hdr[i],
               c && [c expiresDate] ? [[[c expiresDate] description] UTF8String] : "(none)", c ? (int)[c isSessionOnly] : -1);
        fails += got != want;
    }
    // -setCookies:forURL:mainDocumentURL: (how Roblox stores its sign-in cookie) must store them.
    id url = [objc_getClass("NSURL") URLWithString:@"https://www.vine.test/"];
    id k[] = {@"Set-Cookie"}, v[] = {[objc_getClass("NSString") stringWithUTF8String:hdr[0]]};
    id cs = [objc_getClass("NSHTTPCookie") cookiesWithResponseHeaderFields:[objc_getClass("NSDictionary") dictionaryWithObjects:v forKeys:k count:1] forURL:url];
    id store = [objc_getClass("NSHTTPCookieStorage") sharedHTTPCookieStorage];
    [store setCookies:cs forURL:url mainDocumentURL:url];
    // a cookie of another site must not come back for this URL (Darling returned every cookie)
    id ok[] = {@"Set-Cookie"}, ov[] = {@"O=1; domain=.other.test; path=/; Max-Age=600"};
    id ourl = [objc_getClass("NSURL") URLWithString:@"https://www.other.test/"];
    [store setCookies:[objc_getClass("NSHTTPCookie") cookiesWithResponseHeaderFields:[objc_getClass("NSDictionary") dictionaryWithObjects:ov forKeys:ok count:1] forURL:ourl] forURL:ourl mainDocumentURL:ourl];
    id got = [store cookiesForURL:url];
    printf("%s setCookies:forURL:mainDocumentURL: stored, %lu cookie(s) for this site (want 1)\n", [got count] == 1 ? "PASS" : "FAIL", [got count]);
    fails += [got count] != 1;
    id other = [store cookiesForURL:ourl];
    for (unsigned long i = 0; i < [other count]; i++) [store deleteCookie:[other objectAtIndex:i]];
    for (unsigned long i = 0; i < [got count]; i++) [store deleteCookie:[got objectAtIndex:i]];   // leave no test cookie
    return fails;
}
