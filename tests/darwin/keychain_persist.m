// Darwin test (runs in Darling): a Keychain generic password survives a restart, as Roblox's
// login item must. Uses its own service/account; never touches Roblox's item.
// Usage: keychain_persist set   then (new process)   keychain_persist check   (check also deletes it)
#include "../../shims/vine.h"
int printf(const char *, ...);
@interface NSObject (T)
+ (id)dictionaryWithObjects:(const id *)o forKeys:(const id *)k count:(unsigned long)n;
+ (id)dataWithBytes:(const void *)b length:(unsigned long)n;
- (BOOL)isEqual:(id)o;
@end
extern CFStringRef kSecClass, kSecClassGenericPassword, kSecAttrService, kSecAttrAccount, kSecValueData, kSecReturnData;
extern const void *kCFBooleanTrue;
int SecItemAdd(id attrs, id *result);
int SecItemCopyMatching(id query, id *result);
int SecItemDelete(id query);

static id query(int n, id extra_key, id extra_value) {
    id k[] = {(id)kSecClass, (id)kSecAttrService, (id)kSecAttrAccount, extra_key};
    id v[] = {(id)kSecClassGenericPassword, @"vine.test", @"VineTest", extra_value};
    return [objc_getClass("NSDictionary") dictionaryWithObjects:v forKeys:k count:n];
}
int main(int argc, char **argv) {
    id secret = [objc_getClass("NSData") dataWithBytes:"secret" length:6];
    if (argc > 1 && !strcmp(argv[1], "set")) {
        SecItemDelete(query(3, 0, 0));
        int st = SecItemAdd(query(4, (id)kSecValueData, secret), 0);
        int dup = SecItemAdd(query(4, (id)kSecValueData, secret), 0);
        printf("%s add: %d, duplicate add: %d (want -25299)\n", st == 0 && dup == -25299 ? "PASS" : "FAIL", st, dup);
        return st != 0 || dup != -25299;
    }
    id data = 0;
    int st = SecItemCopyMatching(query(4, (id)kSecReturnData, (id)kCFBooleanTrue), &data);
    int ok = st == 0 && data && [data isEqual:secret];
    printf("%s item restored after restart: status %d\n", ok ? "PASS" : "FAIL", st);
    int del = SecItemDelete(query(3, 0, 0)), gone = SecItemCopyMatching(query(4, (id)kSecReturnData, (id)kCFBooleanTrue), &data);
    printf("%s delete: %d, then lookup: %d (want -25300)\n", del == 0 && gone == -25300 ? "PASS" : "FAIL", del, gone);
    return !ok + (del != 0 || gone != -25300);
}
