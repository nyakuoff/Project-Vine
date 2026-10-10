// Darwin test (runs in Darling): speed and correctness of memcpy/memmove/memset/memcmp/strlen
// (Darling's libsystem_platform is built without optimization; MacOBlox measured a third of
// Roblox's main thread in _platform_memmove). Prints GB/s; exit 1 on a wrong result.
#include "../../shims/vine.h"
int printf(const char *, ...);
void *memmove(void *, const void *, size_t); void *memset(void *, int, size_t); int memcmp(const void *, const void *, size_t);
void *memset_pattern16(void *, const void *, size_t);
uint64_t mach_absolute_time(void);
static unsigned char a[1 << 20], b[1 << 20];
static double gbs(uint64_t t0, double bytes) { return bytes / ((mach_absolute_time() - t0) / 1e9) / 1e9; }
int main(void) {
    int bad = 0;
    for (int i = 0; i < (1 << 20); i++) a[i] = (unsigned char)(i * 7 + 3);
    uint64_t t0 = mach_absolute_time();
    for (int r = 0; r < 200; r++) memcpy(b, a, 1 << 20);
    double big = gbs(t0, 200.0 * (1 << 20));
    t0 = mach_absolute_time();
    for (int r = 0; r < 2000000; r++) memcpy(b + (r & 255), a + (r & 127), 100);
    double small = gbs(t0, 2000000.0 * 100);
    t0 = mach_absolute_time();
    for (int r = 0; r < 200; r++) memset(b, r, 1 << 20);
    double set = gbs(t0, 200.0 * (1 << 20));
    t0 = mach_absolute_time();
    size_t len = 0; static char s[4096]; memset(s, 'x', 4095); s[4095] = 0;
    for (int r = 0; r < 100000; r++) len += strlen(s + (r & 7));
    double sl = gbs(t0, 100000.0 * 4090);
    // correctness: overlapping moves both ways, odd sizes and alignments
    for (int n = 0; n < 300; n++) for (int o = 0; o < 9; o++) {
        memcpy(b, a, 1024); memmove(b + o, b, n); bad += memcmp(b + o, a, n) != 0;
        memcpy(b, a, 1024); memmove(b, b + o, n); bad += memcmp(b, a + o, n) != 0;
        memset(b + o, 0x5a, n); for (int i = 0; i < n; i++) bad += b[o + i] != 0x5a;
    }
    bad += memcmp("abc", "abd", 3) >= 0 || memcmp("abd", "abc", 3) <= 0 || strlen("") != 0 || strlen("hello") != 5;
    unsigned char pat[16] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
    memset_pattern16(b, pat, 1000); for (int i = 0; i < 1000; i++) bad += b[i] != pat[i % 16];
    printf("%s memcpy 1MB %.1f GB/s, memcpy 100B %.2f GB/s, memset %.1f GB/s, strlen %.2f GB/s (%d wrong)\n",
           bad ? "FAIL" : "PASS", big, small, set, sl, bad);
    return !!bad;
}
