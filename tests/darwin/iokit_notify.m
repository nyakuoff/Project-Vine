// Regression test (runs inside Darling): IOKit notification ports and service matching.
// Roblox registers IOServiceAddMatchingNotification(IONotificationPortCreate(...), ...) at startup.
#include "../../shims/vine.h"
int printf(const char *, ...);
typedef unsigned int mach_port_t, io_object_t, io_iterator_t, kern_return_t;
typedef struct IONotificationPort *IONotificationPortRef;
typedef const struct __CFDictionary *CFDictionaryRef;
extern const mach_port_t kIOMasterPortDefault;
IONotificationPortRef IONotificationPortCreate(mach_port_t);
CFDictionaryRef IOServiceMatching(const char *);
kern_return_t IOServiceAddMatchingNotification(IONotificationPortRef, const char *, CFDictionaryRef, void *, void *, io_iterator_t *);
io_object_t IOServiceGetMatchingService(mach_port_t, CFDictionaryRef);
static void cb(void *r, io_iterator_t it) {}
int main(void) {
    IONotificationPortRef port = IONotificationPortCreate(kIOMasterPortDefault);
    printf("%s IONotificationPortCreate -> %p\n", port ? "PASS" : "FAIL", port);
    io_object_t pe = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
    printf("%s IOPlatformExpertDevice -> 0x%x\n", pe ? "PASS" : "FAIL", pe);
    io_iterator_t it = 0;
    kern_return_t kr = port ? IOServiceAddMatchingNotification(port, "IOServiceFirstMatch", IOServiceMatching("IOHIDDevice"), cb, 0, &it) : -1;
    printf("%s IOServiceAddMatchingNotification -> 0x%x\n", kr == 0 ? "PASS" : "FAIL", kr);
    return !port + !pe + (kr != 0);
}
