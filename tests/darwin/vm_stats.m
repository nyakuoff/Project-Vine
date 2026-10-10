// Darwin test (runs in Darling): host_statistics64(HOST_VM_INFO64) reports real free/inactive memory.
// Darling reported every count as 0, so Roblox saw 0 MB available, raised "Low memory warning" at
// every game join and unloaded its menu (black screen, slow return to the menu).
#include "../../shims/vine.h"
int printf(const char *, ...);
typedef unsigned int natural_t, mach_port_t;
mach_port_t mach_host_self(void);
int host_statistics64(mach_port_t, int, natural_t *, natural_t *);
int host_statistics(mach_port_t, int, natural_t *, natural_t *);
int main(void) {
    natural_t s64[38 * 2] = {0}, n64 = 38, s32[15] = {0}, n32 = 15;
    int r64 = host_statistics64(mach_host_self(), 4 /* HOST_VM_INFO64 */, s64, &n64);
    int r32 = host_statistics(mach_host_self(), 2 /* HOST_VM_INFO */, s32, &n32);
    double free_mb = s64[0] * 4096.0 / 1048576, avail_mb = (s64[0] + s64[2]) * 4096.0 / 1048576;
    int ok = r64 == 0 && r32 == 0 && free_mb > 64 && s32[0] > 0;
    printf("%s free %.0f MB, free+inactive %.0f MB (64: %d, 32: %d free pages %u)\n", ok ? "PASS" : "FAIL", free_mb, avail_mb, r64, r32, s32[0]);
    return !ok;
}
