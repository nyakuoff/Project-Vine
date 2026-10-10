// Darwin test (runs in Darling): AudioUnit calls on units that are missing or already disposed must
// fail with an error, not crash (Roblox's voice code stops a voice-processing unit Darling lacks).
// Usage: audiounit_misuse <case>   cases: null | vpio | disposed
#include "../../shims/vine.h"
int printf(const char *, ...);
typedef struct { uint32_t type, subtype, manufacturer, flags, mask; } ACD;
void *AudioComponentFindNext(void *after, const ACD *d);
OSStatus AudioComponentInstanceNew(void *c, void **out);
OSStatus AudioComponentInstanceDispose(void *u);
OSStatus AudioOutputUnitStop(void *u);
OSStatus AudioUnitUninitialize(void *u);
#define FCC(s) ((uint32_t)(s)[0] << 24 | (uint32_t)(s)[1] << 16 | (uint32_t)(s)[2] << 8 | (uint32_t)(s)[3])
int main(int argc, char **argv) {
    const char *c = argc > 1 ? argv[1] : "null";
    void *unit = 0;
    if (!strcmp(c, "vpio") || !strcmp(c, "disposed")) {
        ACD d = {FCC("auou"), FCC(!strcmp(c, "vpio") ? "vpio" : "ahal"), FCC("appl"), 0, 0};
        void *comp = AudioComponentFindNext(0, &d);
        OSStatus st = AudioComponentInstanceNew(comp, &unit);
        printf("component %p, instance new: %d unit %p\n", comp, (int)st, unit);
        if (!strcmp(c, "disposed")) printf("dispose: %d\n", (int)AudioComponentInstanceDispose(unit));
    }
    OSStatus a = AudioOutputUnitStop(unit), b = AudioUnitUninitialize(unit);
    printf("%s %s: stop %d, uninitialize %d\n", a && b ? "PASS" : "FAIL", c, (int)a, (int)b);
    return !(a && b);
}
