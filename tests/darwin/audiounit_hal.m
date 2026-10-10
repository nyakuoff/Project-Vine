// Darwin test (runs in Darling): HAL output AudioUnit set-up as a CoreAudio game audio engine does it.
// Usage: audiounit_hal [seconds=0.5]   (a longer run is a soak: each callback does ~1 ms of "mixing")
#include "../../shims/vine.h"
int printf(const char *, ...);
unsigned int usleep(unsigned int);
typedef struct { uint32_t type, subType, manufacturer, flags, mask; } ACDesc;
typedef void *AudioComponent, *AudioUnit;
typedef struct { double rate; uint32_t fmt, flags, bytesPerPacket, framesPerPacket, bytesPerFrame, channels, bits, reserved; } ASBD;
typedef struct { void *proc; void *ref; } RenderCB;
AudioComponent AudioComponentFindNext(AudioComponent, const ACDesc *);
OSStatus AudioComponentInstanceNew(AudioComponent, AudioUnit *);
OSStatus AudioUnitSetProperty(AudioUnit, uint32_t, uint32_t, uint32_t, const void *, uint32_t);
OSStatus AudioUnitGetProperty(AudioUnit, uint32_t, uint32_t, uint32_t, void *, uint32_t *);
OSStatus AudioUnitInitialize(AudioUnit);
OSStatus AudioOutputUnitStart(AudioUnit);
OSStatus AudioOutputUnitStop(AudioUnit);
#define FOURCC(a,b,c,d) ((uint32_t)(a)<<24|(uint32_t)(b)<<16|(uint32_t)(c)<<8|(uint32_t)(d))
static int calls;
static int busy;
uint64_t mach_absolute_time(void);
static OSStatus render(void *ref, uint32_t *flags, const void *ts, uint32_t bus, uint32_t frames, void *bufs) {
    calls++;
    if (busy) { uint64_t t = mach_absolute_time(); while (mach_absolute_time() - t < 1000000) ; }
    return 0;
}
double atof(const char *);
#define STEP(name, expr) do { OSStatus s_ = (expr); printf("%s %-36s status=%d\n", s_ ? "FAIL" : "PASS", name, (int)s_); if (s_) bad++; } while (0)
int main(int argc, char **argv) {
    int bad = 0;
    double secs = argc > 1 ? atof(argv[1]) : 0.5;
    busy = argc > 2;
    ACDesc d = {FOURCC('a','u','o','u'), FOURCC('a','h','a','l'), FOURCC('a','p','p','l'), 0, 0};
    AudioComponent c = AudioComponentFindNext(0, &d);
    printf("%s AudioComponentFindNext(HALOutput)      %p\n", c ? "PASS" : "FAIL", c);
    if (!c) { d.subType = FOURCC('d','e','f',' '); c = AudioComponentFindNext(0, &d); printf("     DefaultOutput fallback %p\n", c); }
    if (!c) return 1;
    AudioUnit u = 0;
    STEP("AudioComponentInstanceNew", AudioComponentInstanceNew(c, &u));
    uint32_t one = 1, zero = 0, dev = 0, sz = 4;
    STEP("EnableIO output (bus 0)", AudioUnitSetProperty(u, 2003, 2 /* output scope */, 0, &one, 4));
    STEP("EnableIO input off (bus 1)", AudioUnitSetProperty(u, 2003, 1 /* input scope */, 1, &zero, 4));
    STEP("CurrentDevice get", AudioUnitGetProperty(u, 2000, 0, 0, &dev, &sz));
    ASBD f = {48000, FOURCC('l','p','c','m'), 1 /*float*/ | 8 /*packed*/, 8, 1, 8, 2, 32, 0};
    STEP("StreamFormat (input scope, bus 0)", AudioUnitSetProperty(u, 8, 1, 0, &f, sizeof f));
    uint32_t maxf = 1024;
    STEP("MaximumFramesPerSlice", AudioUnitSetProperty(u, 14, 0, 0, &maxf, 4));
    RenderCB cb = {render, 0};
    STEP("SetRenderCallback", AudioUnitSetProperty(u, 23, 1, 0, &cb, sizeof cb));
    STEP("AudioUnitInitialize", AudioUnitInitialize(u));
    STEP("AudioOutputUnitStart", AudioOutputUnitStart(u));
    usleep((unsigned)(secs * 1e6));
    printf("%s render callbacks in %.1f s: %d\n", calls ? "PASS" : "FAIL", secs, calls);
    AudioOutputUnitStop(u);
    return bad + !calls;
}
