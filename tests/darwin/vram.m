// Darwin test (runs in Darling): Roblox's video memory query — IOFBMemorySize of the main display's
// IOKit entry — answers the host GPU's VRAM (Darling had no entry; Roblox assumed 64 MB).
#include "../../shims/vine.h"
int printf(const char *, ...);
unsigned int CGMainDisplayID(void); unsigned int CGDisplayIOServicePort(unsigned int);
CFTypeRef IORegistryEntryCreateCFProperty(unsigned int, CFStringRef, const void *, unsigned int);
unsigned char CFNumberGetValue(CFTypeRef, long, void *); int IOObjectRelease(unsigned int);
int main(void) {
    unsigned int svc = CGDisplayIOServicePort(CGMainDisplayID());
    CFTypeRef n = IORegistryEntryCreateCFProperty(svc, (CFStringRef)@"IOFBMemorySize", 0, 0);
    long long bytes = 0;
    if (n) CFNumberGetValue(n, 4, &bytes);
    IOObjectRelease(svc);
    int ok = bytes >= (256LL << 20);
    printf("%s IOFBMemorySize %lld MB (service 0x%x)\n", ok ? "PASS" : "FAIL", bytes >> 20, svc);
    return !ok;
}
