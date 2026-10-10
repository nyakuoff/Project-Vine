// Darwin test (runs in Darling): CoreAudio HAL device enumeration as FMOD's CoreAudio output does it.
#include "../../shims/vine.h"
int printf(const char *, ...);
typedef uint32_t AudioObjectID;
typedef struct { uint32_t mSelector, mScope, mElement; } AudioObjectPropertyAddress;
OSStatus AudioObjectGetPropertyDataSize(AudioObjectID, const AudioObjectPropertyAddress *, uint32_t, const void *, uint32_t *);
OSStatus AudioObjectGetPropertyData(AudioObjectID, const AudioObjectPropertyAddress *, uint32_t, const void *, uint32_t *, void *);
#define FOURCC(a,b,c,d) ((uint32_t)(a)<<24|(uint32_t)(b)<<16|(uint32_t)(c)<<8|(uint32_t)(d))
int main(void) {
    AudioObjectPropertyAddress devs = {FOURCC('d','e','v','#'), FOURCC('g','l','o','b'), 0};
    uint32_t size = 0;
    OSStatus st = AudioObjectGetPropertyDataSize(1 /* system object */, &devs, 0, 0, &size);
    printf("%s devices: status=%d size=%u -> %u device(s)\n", st == 0 && size ? "PASS" : "FAIL", (int)st, size, size / 4);
    AudioObjectPropertyAddress def = {FOURCC('d','O','u','t'), FOURCC('g','l','o','b'), 0};
    AudioObjectID out = 0; uint32_t sz = 4;
    st = AudioObjectGetPropertyData(1, &def, 0, 0, &sz, &out);
    printf("%s default output: status=%d id=%u\n", st == 0 && out ? "PASS" : "FAIL", (int)st, out);
    return !(size && out);
}
