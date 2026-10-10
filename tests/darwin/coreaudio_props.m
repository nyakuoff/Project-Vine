// Darwin test (runs in Darling): the HAL queries FMOD's CoreAudio output makes before it opens the
// default output (Roblox: FMOD_ERR_OUTPUT_INIT at System::getNumDrivers when a game starts).
// Property list from MacOBlox's audio notes (audio_hal.c), checked here against Darling.
// Prints one line per query; exit status = number of failures.
#include "../../shims/vine.h"
int printf(const char *, ...);
typedef uint32_t AudioObjectID;
typedef struct { uint32_t mSelector, mScope, mElement; } AudioObjectPropertyAddress;
typedef OSStatus (*Listener)(AudioObjectID, uint32_t, const AudioObjectPropertyAddress *, void *);
OSStatus AudioObjectGetPropertyDataSize(AudioObjectID, const AudioObjectPropertyAddress *, uint32_t, const void *, uint32_t *);
OSStatus AudioObjectGetPropertyData(AudioObjectID, const AudioObjectPropertyAddress *, uint32_t, const void *, uint32_t *, void *);
OSStatus AudioObjectAddPropertyListener(AudioObjectID, const AudioObjectPropertyAddress *, Listener, void *);
uint64_t AudioGetCurrentHostTime(void);
uint64_t mach_absolute_time(void);
#define FOURCC(a,b,c,d) ((uint32_t)(a)<<24|(uint32_t)(b)<<16|(uint32_t)(c)<<8|(uint32_t)(d))
#define GLOB FOURCC('g','l','o','b')
#define OUTP FOURCC('o','u','t','p')

static int fails;
static uint32_t q(AudioObjectID obj, const char *sel, uint32_t scope, void *out, uint32_t cap) {
    AudioObjectPropertyAddress a = {FOURCC(sel[0], sel[1], sel[2], sel[3]), scope, 0};
    uint32_t size = 0;
    OSStatus st = AudioObjectGetPropertyDataSize(obj, &a, 0, 0, &size);
    if (!st && size) { if (size > cap) size = cap; st = AudioObjectGetPropertyData(obj, &a, 0, 0, &size, out); }
    printf("%s obj %u '%s': status=%d size=%u\n", st || !size ? "FAIL" : "ok  ", obj, sel, (int)st, size);
    if (st || !size) fails++;
    return st ? 0 : size;
}
static OSStatus nop(AudioObjectID o, uint32_t n, const AudioObjectPropertyAddress *a, void *c) { return 0; }

int main(void) {
    uint32_t buf[64] = {0};
    AudioObjectID dev = 0;
    q(1, "dev#", GLOB, buf, sizeof buf);
    q(1, "dOut", GLOB, &dev, 4);
    if (!dev) return 99;
    const char *dsel[] = {"lnam", "uid ", "nsrt", "stm#", "slay", "fsiz", "fsz#", "ltnc", "saft", "tran", "clck"};
    for (unsigned i = 0; i < sizeof dsel / sizeof *dsel; i++) q(dev, dsel[i], OUTP, buf, sizeof buf);
    AudioObjectID stream = 0;
    if (q(dev, "stm#", OUTP, &stream, 4) && stream) {
        const char *ssel[] = {"sfmt", "pft ", "sfma", "pfta", "sdir", "schn", "sact", "term", "ltnc"};
        for (unsigned i = 0; i < sizeof ssel / sizeof *ssel; i++) q(stream, ssel[i], GLOB, buf, sizeof buf);
    }
    AudioObjectPropertyAddress lis = {FOURCC('d','O','u','t'), GLOB, 0};
    OSStatus st = AudioObjectAddPropertyListener(1, &lis, nop, 0);
    printf("%s AudioObjectAddPropertyListener: %d\n", st ? "FAIL" : "ok  ", (int)st); fails += !!st;
    uint64_t h = AudioGetCurrentHostTime(), m = mach_absolute_time();
    int near = h && (h > m ? h - m : m - h) < 1000000000ull;
    printf("%s AudioGetCurrentHostTime: %llu (mach %llu)\n", near ? "ok  " : "FAIL", h, m); fails += !near;
    printf("%d failure(s)\n", fails);
    return fails;
}
