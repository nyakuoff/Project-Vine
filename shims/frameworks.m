// Missing symbols for Roblox 0.742 on Darling 0.1.20260608, grouped by framework.
// build.sh compiles this once per framework with -DFW_<Name>; see tests/macho-symcheck.py.
#include "vine.h"

#ifdef FW_CoreML
VINE_CLASS(MLFeatureValue) VINE_CLASS(MLModel) VINE_CLASS(MLModelConfiguration)
VINE_CLASS(MLMultiArray) VINE_CLASS(MLPredictionOptions)
#endif

#ifdef FW_AudioToolbox
VINE_FUNC(OSStatus, AudioConverterNewSpecific, -4 /* kAudio_UnimplementedError */)
#endif

#ifdef FW_Carbon
VINE_FUNC(uint8_t, LMGetKbdLast, 0)
#endif

#ifdef FW_CoreAudio
uint64_t AudioConvertHostTimeToNanos(uint64_t t) { return t; }  // ponytail: assumes 1:1 mach timebase, as on Darling/x86
// Darling's AudioGetCurrentHostTime is a stub returning 0; FMOD times its mixer with it.
uint64_t mach_absolute_time(void);
uint64_t AudioGetCurrentHostTime(void) { return mach_absolute_time(); }

// HAL properties FMOD's CoreAudio output needs before it opens a device (finding credited to
// MacOBlox's audio notes). Darling's PulseAudio devices answer 'who?' for the device's stream list,
// buffer frame size, latency, transport and clock, and have no stream objects at all, so FMOD
// failed with FMOD_ERR_OUTPUT_INIT (Roblox: no sound). Each device that has channels in a scope
// gets one stream object (id VINE_STREAM|scope bit|device) describing the device's real format;
// Darling's own answers always win. Listener registration fails in Darling and FMOD treats that
// as a failed init: Darling's devices never change, so listeners are accepted and never called.
typedef uint32_t AudioObjectID;
typedef struct { uint32_t mSelector, mScope, mElement; } VineAOPA;
typedef struct { double rate; uint32_t formatID, flags, bytesPerPacket, framesPerPacket, bytesPerFrame, channels, bits, reserved; } VineFmt;
#define FCC(s) ((uint32_t)(s)[0] << 24 | (uint32_t)(s)[1] << 16 | (uint32_t)(s)[2] << 8 | (uint32_t)(s)[3])
#define VINE_WHO 0x77686f3f   /* 'who?' kAudioHardwareUnknownPropertyError */
#define VINE_STREAM 0x56000000u
#define VINE_STREAM_INPUT 0x10000u
#define CA_IMG "/System/Library/Frameworks/CoreAudio.framework/Versions/A/CoreAudio.darling"
#define CA_ORIG(type, name, ...) static type (*o)(__VA_ARGS__); if (!o) o = (type (*)(__VA_ARGS__))vine_orig(CA_IMG, name)
void *vine_orig(const char *image, const char *sym);
static uint32_t vine_frames[8];   // buffer frame size per device id (Darling: 8192-byte buffer)

static OSStatus ca_get(AudioObjectID obj, const VineAOPA *a, uint32_t qs, const void *q, uint32_t *size, void *out) {
    CA_ORIG(OSStatus, "AudioObjectGetPropertyData", AudioObjectID, const VineAOPA *, uint32_t, const void *, uint32_t *, void *);
    return o ? o(obj, a, qs, q, size, out) : VINE_WHO;
}
static uint32_t channels(AudioObjectID dev, uint32_t scope) {   // from 'slay' (an AudioBufferList)
    uint32_t abl[16] = {0}, size = sizeof abl, n = 0;
    VineAOPA a = {FCC("slay"), scope, 0};
    if (ca_get(dev, &a, 0, 0, &size, abl) || size < 4) return 0;
    for (uint32_t i = 0; i < abl[0] && 2 + 4 * i < 16; i++) n += abl[2 + 4 * i];   // {count, pad, {channels, bytes, data}...}
    return n;
}
static VineFmt device_format(AudioObjectID dev, uint32_t ch) {
    VineFmt f = {0};
    uint32_t size = sizeof f;
    VineAOPA a = {FCC("sfmt"), FCC("glob"), 0};
    ca_get(dev, &a, 0, 0, &size, &f);
    if (!f.rate) f.rate = 44100;
    f.formatID = FCC("lpcm"); f.flags = 1 | 8;   // float, packed (interleaved): what Darling's stream plays
    f.bits = 32; f.channels = ch; f.framesPerPacket = 1;
    f.bytesPerFrame = f.bytesPerPacket = ch * 4;   // Darling reports bytes per second here
    return f;
}
static int put(void *out, uint32_t *size, const void *v, uint32_t n) {
    if (out && *size < n) return 0x2173697a;   // '!siz' kAudioHardwareBadPropertySizeError
    if (out) memcpy(out, v, n);
    *size = n;
    return 0;
}
// Answer a query Darling could not; returns VINE_WHO when there is nothing to add.
static OSStatus vine_ca_answer(AudioObjectID obj, const VineAOPA *a, uint32_t *size, void *out) {
    uint32_t sel = a->mSelector, u = 0;
    if ((obj & 0xff000000u) == VINE_STREAM) {   // our stream objects
        AudioObjectID dev = obj & 0xff;
        int input = !!(obj & VINE_STREAM_INPUT);
        VineFmt f = device_format(dev, channels(dev, input ? FCC("inpt") : FCC("outp")));
        if (sel == FCC("sfmt") || sel == FCC("pft ")) return put(out, size, &f, sizeof f);
        if (sel == FCC("sfma") || sel == FCC("pfta")) {   // AudioStreamRangedDescription
            struct { VineFmt f; double lo, hi; } r = {f, f.rate, f.rate};
            return put(out, size, &r, sizeof r);
        }
        if (sel == FCC("sdir")) u = input;
        else if (sel == FCC("schn") || sel == FCC("sact")) u = 1;
        else if (sel == FCC("term")) u = input ? FCC("micr") : FCC("spkr");
        else if (sel != FCC("ltnc")) return VINE_WHO;
        return put(out, size, &u, 4);
    }
    if (obj < 2 || obj >= 8) return VINE_WHO;   // devices only (Darling: 2 output, 3 input, 4 system output)
    if (sel == FCC("stm#")) {
        AudioObjectID ids[2]; uint32_t n = 0;
        if (a->mScope != FCC("inpt") && channels(obj, FCC("outp"))) ids[n++] = VINE_STREAM | obj;
        if (a->mScope != FCC("outp") && channels(obj, FCC("inpt"))) ids[n++] = VINE_STREAM | VINE_STREAM_INPUT | obj;
        return put(out, size, ids, n * 4);
    }
    if (sel == FCC("fsiz")) { u = vine_frames[obj] ? vine_frames[obj] : 8192 / 8; return put(out, size, &u, 4); }
    if (sel == FCC("fsz#")) { double r[2] = {64, 8192}; return put(out, size, r, sizeof r); }
    if (sel == FCC("tran")) { u = FCC("bltn"); return put(out, size, &u, 4); }
    if (sel == FCC("ltnc") || sel == FCC("saft") || sel == FCC("clck")) return put(out, size, &u, 4);
    return VINE_WHO;
}

OSStatus AudioObjectGetPropertyData(AudioObjectID obj, const VineAOPA *a, uint32_t qs, const void *q, uint32_t *size, void *out) {
    OSStatus st = (obj & 0xff000000u) == VINE_STREAM ? VINE_WHO : ca_get(obj, a, qs, q, size, out);
    return st == VINE_WHO && a && size ? vine_ca_answer(obj, a, size, out) : st;
}
OSStatus AudioObjectGetPropertyDataSize(AudioObjectID obj, const VineAOPA *a, uint32_t qs, const void *q, uint32_t *size) {
    CA_ORIG(OSStatus, "AudioObjectGetPropertyDataSize", AudioObjectID, const VineAOPA *, uint32_t, const void *, uint32_t *);
    OSStatus st = (obj & 0xff000000u) == VINE_STREAM || !o ? VINE_WHO : o(obj, a, qs, q, size);
    return st == VINE_WHO && a && size ? vine_ca_answer(obj, a, size, 0) : st;
}
unsigned char AudioObjectHasProperty(AudioObjectID obj, const VineAOPA *a) {
    uint32_t size = 0;
    return AudioObjectGetPropertyDataSize(obj, a, 0, 0, &size) == 0;
}
OSStatus AudioObjectSetPropertyData(AudioObjectID obj, const VineAOPA *a, uint32_t qs, const void *q, uint32_t n, const void *v) {
    CA_ORIG(OSStatus, "AudioObjectSetPropertyData", AudioObjectID, const VineAOPA *, uint32_t, const void *, uint32_t, const void *);
    if (a && v && n == 4 && a->mSelector == FCC("fsiz") && obj >= 2 && obj < 8) {   // frames -> Darling's byte size
        uint32_t bytes = *(const uint32_t *)v * 8;
        VineAOPA b = {FCC("bsiz"), a->mScope, 0};
        OSStatus st = o ? o(obj, &b, 0, 0, 4, &bytes) : VINE_WHO;
        if (!st) vine_frames[obj] = *(const uint32_t *)v;
        return st;
    }
    return (obj & 0xff000000u) == VINE_STREAM ? 0x6e6f7065 /* 'nope' */ : o ? o(obj, a, qs, q, n, v) : VINE_WHO;
}
typedef OSStatus (*VineListener)(AudioObjectID, uint32_t, const VineAOPA *, void *);
OSStatus AudioObjectAddPropertyListener(AudioObjectID obj, const VineAOPA *a, VineListener l, void *c) { return 0; }
// PulseAudio I/O watches. Darling's PADispatchMainLoop gives each PulseAudio descriptor a read and a
// write dispatch source. io_free cancels them (asynchronously) and PulseAudio then closes the
// descriptor at once: until libdispatch unregisters, its watch belongs to a closed and soon reused
// number, and events reach freed sources (SIGILL/SIGSEGV in _dispatch_kevent_merge once game audio
// runs; reproduced by tests/darwin/audiounit_hal.m 30 busy). It also freed its bookkeeping in the
// write source's cancel handler while the read source could still fire. Replacement: the sources
// watch a dup() of the descriptor, closed only after both cancel handlers have run, and the
// bookkeeping lives until then; nothing is delivered to PulseAudio after io_free.
typedef struct dispatch_source_s *vine_source_t;
typedef struct dispatch_queue_s *vine_queue_t;
extern const struct dispatch_source_type_s _dispatch_source_type_read, _dispatch_source_type_write;
vine_source_t dispatch_source_create(const void *type, uintptr_t handle, unsigned long mask, vine_queue_t q);
void dispatch_source_set_event_handler(vine_source_t, void (^)(void));
void dispatch_source_set_cancel_handler(vine_source_t, void (^)(void));
void dispatch_source_cancel(vine_source_t); void dispatch_resume(void *); void dispatch_suspend(void *); void dispatch_release(void *);
int fcntl(int, int, ...); int close(int);
void *calloc(size_t, size_t);
typedef void (*VinePaIoCb)(void *api, void *ev, int fd, int events, void *ud);
typedef void (*VinePaIoDestroy)(void *api, void *ev, void *ud);
enum { PA_IN = 1, PA_OUT = 2, PA_HUP = 4, PA_ERR = 8 };
typedef struct { void *api; int fd, dupfd, freed, live, rd_on, wr_on; VinePaIoCb cb; VinePaIoDestroy destroy; void *ud; vine_source_t rd, wr; } VinePaIo;
static void vine_pa_io_done(VinePaIo *e) {   // a cancel handler ran (on the loop's queue)
    if (--e->live) return;
    if (e->destroy) e->destroy(e->api, e, e->ud);
    close(e->dupfd);
    free(e);
}
static void vine_pa_io_enable(VinePaIo *e, int events) {
    int r = !!(events & (PA_IN | PA_HUP | PA_ERR)), w = !!(events & PA_OUT);
    if (r != e->rd_on) { r ? dispatch_resume(e->rd) : dispatch_suspend(e->rd); e->rd_on = r; }
    if (w != e->wr_on) { w ? dispatch_resume(e->wr) : dispatch_suspend(e->wr); e->wr_on = w; }
}
static void *vine_pa_io_new(void *api, int fd, int events, VinePaIoCb cb, void *ud) {
    vine_queue_t q = **(vine_queue_t **)api;   // api->userdata = PADispatchMainLoop, whose first field is m_queue
    VinePaIo *e = calloc(1, sizeof *e);
    int d = fcntl(fd, 67 /* F_DUPFD_CLOEXEC */, 0);
    if (!e || d < 0) { if (e) free(e); return 0; }
    e->api = api; e->fd = fd; e->dupfd = d; e->cb = cb; e->ud = ud; e->live = 2;
    e->rd = dispatch_source_create(&_dispatch_source_type_read, d, 0, q);
    e->wr = dispatch_source_create(&_dispatch_source_type_write, d, 0, q);
    dispatch_source_set_event_handler(e->rd, ^{ if (!e->freed) e->cb(e->api, e, e->fd, PA_IN, e->ud); });
    dispatch_source_set_event_handler(e->wr, ^{ if (!e->freed) e->cb(e->api, e, e->fd, PA_OUT, e->ud); });
    dispatch_source_set_cancel_handler(e->rd, ^{ vine_pa_io_done(e); });
    dispatch_source_set_cancel_handler(e->wr, ^{ vine_pa_io_done(e); });
    vine_pa_io_enable(e, events);
    return e;
}
static void vine_pa_io_set_destroy(VinePaIo *e, VinePaIoDestroy cb) { e->destroy = cb; }
static void vine_pa_io_free(VinePaIo *e) {
    e->freed = 1;
    vine_pa_io_enable(e, PA_IN | PA_OUT);   // a suspended source must be resumed to be cancelled
    dispatch_source_cancel(e->rd); dispatch_source_cancel(e->wr);
    dispatch_release(e->rd); dispatch_release(e->wr);
}
int vine_detour(const char *image, const char *sym, void *repl);
__attribute__((constructor)) static void vine_pa_io_fix(void) {
    if (getenv("VINE_DARLING_PA_IO")) return;
    static const struct { const char *sym; void *fn; } t[] = {
        {"_ZN18PADispatchMainLoop6io_newEP15pa_mainloop_apii17pa_io_event_flagsPFvS1_P11pa_io_eventiS2_PvES5_", (void *)vine_pa_io_new},
        {"_ZN18PADispatchMainLoop9io_enableEP11pa_io_event17pa_io_event_flags", (void *)vine_pa_io_enable},
        {"_ZN18PADispatchMainLoop7io_freeEP11pa_io_event", (void *)vine_pa_io_free},
        {"_ZN18PADispatchMainLoop14io_set_destroyEP11pa_io_eventPFvP15pa_mainloop_apiS1_PvE", (void *)vine_pa_io_set_destroy},
    };
    for (int i = 0; i < 4; i++) vine_detour(CA_IMG, t[i].sym, t[i].fn);   // all four, or the layouts would mix
}
OSStatus AudioObjectRemovePropertyListener(AudioObjectID obj, const VineAOPA *a, VineListener l, void *c) { return 0; }
#endif

#ifdef FW_CoreGraphics
VINE_FUNC(CFTypeID, CGColorGetTypeID, 0)
VINE_FUNC(bool, CGEventSourceKeyState, 0)
#endif

#ifdef FW_CoreServices
VINE_FUNC(bool, FSEventStreamFlushSync, 0)
#endif

#ifdef FW_CoreVideo
#define kCVReturnUnsupported -6668
CFTypeRef CVBufferRetain(CFTypeRef b) { return b; }
VINE_VOID(CVPixelBufferRelease)
VINE_FUNC(int32_t, CVPixelBufferCreate, kCVReturnUnsupported)
VINE_FUNC(int32_t, CVPixelBufferPoolCreatePixelBuffer, kCVReturnUnsupported)
VINE_FUNC(int32_t, CVMetalTextureCacheCreate, kCVReturnUnsupported)
VINE_FUNC(int32_t, CVMetalTextureCacheCreateTextureFromImage, kCVReturnUnsupported)
VINE_FUNC(id, CVMetalTextureGetTexture, 0)
VINE_FUNC(size_t, CVPixelBufferGetBytesPerRow, 0)
VINE_FUNC(size_t, CVPixelBufferGetHeightOfPlane, 0)
VINE_FUNC(size_t, CVPixelBufferGetWidthOfPlane, 0)
VINE_FUNC(uint32_t, CVPixelBufferGetPixelFormatType, 0)
struct CGSize { double w, h; };
struct CGSize CVImageBufferGetEncodedSize() { VINE_LOG_ONCE("CVImageBufferGetEncodedSize"); return (struct CGSize){0, 0}; }
VINE_STR(kCVPixelBufferCGBitmapContextCompatibilityKey)
VINE_STR(kCVPixelBufferCGImageCompatibilityKey)
#endif

#ifdef FW_Foundation
VINE_STR(NSProcessInfoPowerStateDidChangeNotification)
VINE_STR(NSProcessInfoThermalStateDidChangeNotification)
VINE_CLASS(NSBackgroundActivityScheduler)

// Thread stacks no smaller than Linux's 8 MiB default (finding credited to MacOBlox). Under Darling
// every system call runs host RPC code built for Linux-sized stacks; FMOD's audio threads ask for
// small stacks that are enough on macOS and overflowed in that code seconds after game sound started.
// Only reserves address space. Darling's libpthread setter (pthread.c), with the floor applied.
int vine_detour(const char *image, const char *sym, void *repl);
struct vine_pthread_attr { long sig; size_t guardsize; void *stackaddr; size_t stacksize; };
static int vine_attr_setstacksize(struct vine_pthread_attr *attr, size_t size) {
    if (attr->sig != 0x54484441 /* 'THDA' */ || (size & 4095) || size < 16384) return 22;   // EINVAL
    attr->stacksize = size < (8u << 20) ? (8u << 20) : size;
    return 0;
}
__attribute__((constructor)) static void vine_thread_stacks(void) {
    vine_detour("/usr/lib/system/libsystem_pthread.dylib", "pthread_attr_setstacksize", (void *)vine_attr_setstacksize);
}
#endif

#ifdef FW_GameController
VINE_CLASS(GCColor) VINE_CLASS(GCDualSenseGamepad) VINE_CLASS(GCDualShockGamepad) VINE_CLASS(GCXboxGamepad)
VINE_STR(GCControllerDidConnectNotification) VINE_STR(GCControllerDidDisconnectNotification)
const float GCHapticDurationInfinite = __builtin_inff();
VINE_STR(GCHapticsLocalityHandles) VINE_STR(GCHapticsLocalityLeftHandle) VINE_STR(GCHapticsLocalityLeftTrigger)
VINE_STR(GCHapticsLocalityRightHandle) VINE_STR(GCHapticsLocalityRightTrigger) VINE_STR(GCHapticsLocalityTriggers)
VINE_STR(GCInputButtonA) VINE_STR(GCInputButtonB) VINE_STR(GCInputButtonX) VINE_STR(GCInputButtonY)
VINE_STR(GCInputButtonMenu) VINE_STR(GCInputButtonOptions) VINE_STR(GCInputDirectionPad)
VINE_STR(GCInputDualShockTouchpadButton) VINE_STR(GCInputDualShockTouchpadOne) VINE_STR(GCInputDualShockTouchpadTwo)
VINE_STR(GCInputLeftShoulder) VINE_STR(GCInputLeftThumbstick) VINE_STR(GCInputLeftThumbstickButton) VINE_STR(GCInputLeftTrigger)
VINE_STR(GCInputRightShoulder) VINE_STR(GCInputRightThumbstick) VINE_STR(GCInputRightThumbstickButton) VINE_STR(GCInputRightTrigger)
VINE_STR(GCInputXboxPaddleOne) VINE_STR(GCInputXboxPaddleTwo) VINE_STR(GCInputXboxPaddleThree) VINE_STR(GCInputXboxPaddleFour)
#endif

#ifdef FW_Metal
VINE_CLASS(MTLCaptureDescriptor)
#endif

#ifdef FW_QuartzCore
struct CAFrameRateRange { float minimum, maximum, preferred; };
struct CAFrameRateRange CAFrameRateRangeMake(float a, float b, float c) { return (struct CAFrameRateRange){a, b, c}; }
#endif

#ifdef FW_ServiceManagement
VINE_CLASS(SMAppService)
#endif

#ifdef FW_SystemConfiguration
VINE_FUNC(CFStringRef, SCNetworkInterfaceGetInterfaceType, 0)
VINE_FUNC(CFTypeRef, SCNetworkServiceCopy, 0)
VINE_FUNC(CFTypeRef, SCNetworkServiceGetInterface, 0)
VINE_STR(kSCNetworkInterfaceTypeEthernet) VINE_STR(kSCNetworkInterfaceTypeIEEE80211)
#endif

#ifdef FW_VideoToolbox
VINE_VOID(VTRegisterSupplementalVideoDecoderIfAvailable)
VINE_STR(kVTDecompressionPropertyKey_RealTime)
VINE_STR(kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder)
VINE_STR(kVTVideoEncoderList_CodecType) VINE_STR(kVTVideoEncoderList_EncoderName)
VINE_STR(kVTVideoEncoderList_IsHardwareAccelerated)
#endif

#ifdef FW_AppKit
// Darling renders at 1x: backing-store conversions are identities, scale factor is 1.
typedef double CGFloat;
typedef struct { CGFloat x, y; } NSPoint;
typedef struct { CGFloat width, height; } NSSize;
typedef struct { NSPoint origin; NSSize size; } NSRect;
@interface NSView : NSObject @end
@interface NSWindow : NSObject - (NSRect)frame; @end
@interface NSScreen : NSObject @end
@implementation NSView (Vine)
- (NSSize)convertSizeToBacking:(NSSize)s { return s; }
- (NSSize)convertSizeFromBacking:(NSSize)s { return s; }
- (NSRect)convertRectToBacking:(NSRect)r { return r; }
- (NSRect)convertRectFromBacking:(NSRect)r { return r; }
- (NSPoint)convertPointToBacking:(NSPoint)p { return p; }
- (NSPoint)convertPointFromBacking:(NSPoint)p { return p; }
@end
@implementation NSWindow (Vine)
- (CGFloat)backingScaleFactor { return 1.0; }
- (NSRect)convertRectToScreen:(NSRect)r { NSRect f = [self frame]; r.origin.x += f.origin.x; r.origin.y += f.origin.y; return r; }
- (NSRect)convertRectFromScreen:(NSRect)r { NSRect f = [self frame]; r.origin.x -= f.origin.x; r.origin.y -= f.origin.y; return r; }
- (NSPoint)convertPointToScreen:(NSPoint)p { NSRect f = [self frame]; p.x += f.origin.x; p.y += f.origin.y; return p; }
- (NSPoint)convertPointFromScreen:(NSPoint)p { NSRect f = [self frame]; p.x -= f.origin.x; p.y -= f.origin.y; return p; }
@end
@implementation NSScreen (Vine)
- (CGFloat)backingScaleFactor { return 1.0; }
@end
#endif

#ifdef FW_QuartzCore
@interface CALayer : NSObject @end
@implementation CALayer (Vine)   // 1x only (see AppKit)
- (double)contentsScale { return 1.0; }
- (void)setContentsScale:(double)s {}
@end
#endif

#ifdef FW_CFNetwork
// CFHTTPCookieCreateWithResponseHeaderFields replacement. Darling's version drops the Domain,
// Secure and HTTPOnly attributes, then CFHTTPCookieGetDomain does CFStringCreateCopy(NULL) for
// host-only cookies and CFHTTPCookieIsSecure/IsHTTPOnly do CFBooleanGetValue(NULL): crashes.
// Here every cookie gets Name, Value, Domain (URL host if absent), Path, OriginURL, Secure, HTTPOnly.
// ponytail: Expires/Max-Age ignored (session cookies); default Path is "/" not the URL's directory.
typedef const struct __CFArray *CFArrayRef;
typedef struct __CFArray *CFMutableArrayRef;
typedef const struct __CFDictionary *CFDictionaryRef;
typedef const struct __CFURL *CFURLRef;
typedef const void *CFBooleanRef, *CFAllocatorRef, *CFHTTPCookieRef;
#define CFSTR(s) ((CFStringRef)__builtin___CFStringMakeConstantString(s))
#define UTF8 0x08000100
extern const CFBooleanRef kCFBooleanTrue, kCFBooleanFalse;
extern const char kCFTypeArrayCallBacks[], kCFTypeDictionaryKeyCallBacks[], kCFTypeDictionaryValueCallBacks[];
const void *CFDictionaryGetValue(CFDictionaryRef, const void *);
CFDictionaryRef CFDictionaryCreate(CFAllocatorRef, const void **, const void **, CFIndex, const void *, const void *);
CFMutableArrayRef CFArrayCreateMutable(CFAllocatorRef, CFIndex, const void *);
void CFArrayAppendValue(CFMutableArrayRef, const void *);
void CFRelease(CFTypeRef);
BOOL CFStringGetCString(CFStringRef, char *, CFIndex, uint32_t);
CFStringRef CFStringCreateWithBytes(CFAllocatorRef, const char *, CFIndex, uint32_t, BOOL);
CFStringRef CFURLCopyHostName(CFURLRef);
CFHTTPCookieRef CFHTTPCookieCreateWithProperties(CFDictionaryRef);

static int vine_ieq(const char *a, size_t n, const char *lit) {   // case-insensitive a[0..n) == lit
    size_t i = 0;
    for (; i < n && lit[i]; i++) if ((a[i] | 32) != (lit[i] | 32)) return 0;
    return i == n && !lit[i];
}
static void vine_trim(const char **s, const char **e) {
    while (*s < *e && (**s == ' ' || **s == '\t')) (*s)++;
    while (*e > *s && ((*e)[-1] == ' ' || (*e)[-1] == '\t')) (*e)--;
}
static CFStringRef vine_str(const char *s, const char *e) { return CFStringCreateWithBytes(0, s, e - s, UTF8, 0); }
typedef const struct __CFDate *CFDateRef;
CFDateRef CFDateCreate(CFAllocatorRef, double);
double CFAbsoluteTimeGetCurrent(void);
#include "httpdate.h"

// One cookie "name=value; Domain=x; Path=/; Secure; HttpOnly" -> appended cookie object.
static void vine_cookie(const char *s, const char *e, CFURLRef url, CFMutableArrayRef out) {
    CFStringRef name = 0, value = 0, domain = 0, path = 0;
    BOOL secure = 0, httponly = 0;
    double expires = 0, max_age = -1;   // CFAbsoluteTime; 0 = none
    for (const char *t = s; t < e; ) {
        const char *te = t; while (te < e && *te != ';') te++;
        const char *eq = t; while (eq < te && *eq != '=') eq++;
        const char *ks = t, *ke = eq, *vs = eq < te ? eq + 1 : te, *ve = te;
        vine_trim(&ks, &ke); vine_trim(&vs, &ve);
        if (!name) { if (eq < te && ke > ks) { name = vine_str(ks, ke); value = vine_str(vs, ve); } else break; }
        else if (vine_ieq(ks, ke - ks, "domain") && ve > vs) { if (domain) CFRelease(domain); domain = vine_str(vs, ve); }
        else if (vine_ieq(ks, ke - ks, "path") && ve > vs) { if (path) CFRelease(path); path = vine_str(vs, ve); }
        else if (vine_ieq(ks, ke - ks, "expires") && ve > vs) expires = vine_http_date(vs, ve);
        else if (vine_ieq(ks, ke - ks, "max-age") && ve > vs) { max_age = 0; for (const char *q = vs; q < ve && *q >= '0' && *q <= '9'; q++) max_age = max_age * 10 + (*q - '0'); }
        else if (vine_ieq(ks, ke - ks, "secure")) secure = 1;
        else if (vine_ieq(ks, ke - ks, "httponly")) httponly = 1;
        t = te < e ? te + 1 : e;
    }
    if (!domain && url) domain = CFURLCopyHostName(url);
    if (name && domain) {
        const void *k[] = {CFSTR("Name"), CFSTR("Value"), CFSTR("Domain"), CFSTR("Path"), CFSTR("Secure"), CFSTR("HTTPOnly"), CFSTR("OriginURL")};
        const void *v[] = {name, value, domain, path ? path : CFSTR("/"), secure ? kCFBooleanTrue : kCFBooleanFalse,
                           httponly ? kCFBooleanTrue : kCFBooleanFalse, url};
        if (max_age >= 0) expires = CFAbsoluteTimeGetCurrent() + max_age;   // Max-Age wins over Expires
        CFDateRef exp = expires ? CFDateCreate(0, expires) : 0;
        const void *k2[9], *v2[9]; int nk = 0;
        for (int i = 0; i < (url ? 7 : 6); i++) { k2[nk] = k[i]; v2[nk++] = v[i]; }
        if (exp) { k2[nk] = CFSTR("Expires"); v2[nk++] = exp; }
        CFDictionaryRef props = CFDictionaryCreate(0, k2, v2, nk, kCFTypeDictionaryKeyCallBacks, kCFTypeDictionaryValueCallBacks);
        if (exp) CFRelease(exp);
        CFHTTPCookieRef c = CFHTTPCookieCreateWithProperties(props);
        if (c) { CFArrayAppendValue(out, c); CFRelease(c); }
        CFRelease(props);
    }
    if (name) CFRelease(name);
    if (value) CFRelease(value);
    if (domain) CFRelease(domain);
    if (path) CFRelease(path);
}

CFArrayRef CFHTTPCookieCreateWithResponseHeaderFields(CFDictionaryRef headers, CFURLRef url) {
    CFMutableArrayRef out = CFArrayCreateMutable(0, 0, kCFTypeArrayCallBacks);
    CFStringRef h = headers ? CFDictionaryGetValue(headers, CFSTR("Set-Cookie")) : 0;
    static char buf[65536];   // ponytail: one header up to 64 KiB, not reentrant across threads
    static int busy;
    if (!h || __atomic_exchange_n(&busy, 1, __ATOMIC_ACQUIRE)) return out;
    if (CFStringGetCString(h, buf, sizeof buf, UTF8)) {
        // Several cookies may be folded into one header with ","; an Expires date has one "," too.
        const char *s = buf, *p = buf, *attr = buf;
        int in_expires = 0;
        for (;; p++) {
            if (*p == ';') { attr = p + 1; in_expires = 0; }
            else if (*p == '=') { const char *a = attr, *b = p; vine_trim(&a, &b); in_expires = vine_ieq(a, b - a, "expires"); }
            else if (*p == ',' && in_expires == 1) { in_expires = 2; continue; }
            if (*p == 0 || (*p == ',' && in_expires != 1)) {
                vine_cookie(s, p, url, out);
                if (!*p) break;
                s = attr = p + 1; in_expires = 0;
            }
        }
    }
    __atomic_store_n(&busy, 0, __ATOMIC_RELEASE);
    return out;
}
#endif

#ifdef FW_CFNetwork
int vine_detour(const char *image, const char *sym, void *repl);
__attribute__((constructor)) static void vine_cfnetwork_init(void) {
    vine_detour("/System/Library/Frameworks/CFNetwork.framework/Versions/A/CFNetwork.darling",
                "CFHTTPCookieCreateWithResponseHeaderFields", (void *)CFHTTPCookieCreateWithResponseHeaderFields);
}
#endif

#ifdef FW_AppKit
// One window-server connection per process, as on macOS. Darling's Cocotron AppKit keeps an
// NSDisplay per *thread*; Roblox's render thread then builds a second X11 display, finds no
// backend and raises NSWindowServerCommunicationException. All threads now share the main
// thread's display; Xlib is made thread-safe first (the X11 backend never calls XInitThreads).
void *dlopen(const char *, int);
void *dlsym(void *, const char *);
id NSThreadSharedInstance(NSString *);
@interface NSThread : NSObject + (BOOL)isMainThread; @end
@interface NSDisplay : NSObject @end
static id vine_main_display;
static void vine_quiet_warp(void);
@implementation NSDisplay (VineSharedDisplay)
+ (id)currentDisplay {
    if ([NSThread isMainThread]) { vine_main_display = NSThreadSharedInstance(@"NSDisplay"); vine_quiet_warp(); return vine_main_display; }
    return vine_main_display ? vine_main_display : NSThreadSharedInstance(@"NSDisplay");
}
@end
// -[X11Display warpMouse:] logs "Warp to: ..." on every call; with the pointer grabbed (mouse lock)
// it runs once per mouse motion event, i.e. hundreds of log writes per second. Same warp, no log.
// Installed once the X11 backend bundle (which defines X11Display) is loaded.
typedef void *Ivar;
Ivar class_getInstanceVariable(Class, const char *);
long ivar_getOffset(Ivar);
static int (*x_warp)(void *, unsigned long, unsigned long, int, int, unsigned, unsigned, int, int);
static int (*x_sync)(void *, int);
static unsigned long (*x_root)(void *);
static ptrdiff_t x_display_ivar;
// X request serials order our warps against incoming events (finding credited to MacOBlox,
// pointer_motion.h): an event with a serial below the warp's request was generated before it.
static unsigned long (*x_next_request)(void *);
static volatile unsigned long vine_cur_serial, vine_warp_serial;
static volatile int vine_warp_pending;
// Where the pointer really is after a warp, relative to the warp target (root pixels). Xwayland
// ignores XWarpPointer unless the cursor is hidden (it then emulates the warp with a pointer lock),
// so a recentring could silently not happen; the camera then jumped by the distance it assumed.
static int (*x_query_pointer)(void *, unsigned long, unsigned long *, unsigned long *, int *, int *, int *, int *, unsigned *);
static volatile double vine_warp_off_x, vine_warp_off_y;
static void vine_warp_mouse(id self, SEL _cmd, struct { double x, y; } p) {
    void *dpy = *(void **)((char *)self + x_display_ivar);
    if (x_next_request) { vine_warp_serial = x_next_request(dpy); vine_warp_pending = 1; }
    x_warp(dpy, 0, x_root(dpy), 0, 0, 0, 0, (int)p.x, (int)p.y);
    x_sync(dpy, 0);
    unsigned long r, c; int rx, ry, wx, wy; unsigned m;
    if (x_query_pointer && x_query_pointer(dpy, x_root(dpy), &r, &c, &rx, &ry, &wx, &wy, &m)) {
        vine_warp_off_x = rx - (int)p.x; vine_warp_off_y = ry - (int)p.y;
    } else vine_warp_off_x = vine_warp_off_y = 0;
}
// Hidden cursor while locked: XFixes (host libXfixes through Darling's ELF loader; Darling bridges
// no libXfixes). Finding credited to MacOBlox (xfixes_raw.c).
void *elfcalls_get_pointer(void);
static void (*x_fixes_cursor[2])(void *, unsigned long);   // hide, show
static void vine_cursor_hidden(id display, int hide) {
    static int tried;
    if (!tried++) {
        struct { void *(*dlopen)(const char *); int (*dlclose)(void *); void *(*dlsym)(void *, const char *); } *ec = elfcalls_get_pointer();
        void *xf = ec ? ec->dlopen("libXfixes.so.3") : 0;
        if (xf) { x_fixes_cursor[0] = ec->dlsym(xf, "XFixesHideCursor"); x_fixes_cursor[1] = ec->dlsym(xf, "XFixesShowCursor"); }
        if (!x_fixes_cursor[0] || !x_fixes_cursor[1]) dprintf(2, "vine: XFixes unavailable, mouse lock recentring may not work under Xwayland\n");
    }
    void *dpy = *(void **)((char *)display + x_display_ivar);
    if (x_fixes_cursor[hide ? 0 : 1]) { x_fixes_cursor[hide ? 0 : 1](dpy, x_root(dpy)); x_sync(dpy, 0); }
}
static void (*orig_postXEvent)(id, SEL, void *);
static void vine_postXEvent(id self, SEL _cmd, void *ev) {
    vine_cur_serial = ((unsigned long *)ev)[1];   // XAnyEvent: int type; unsigned long serial
    orig_postXEvent(self, _cmd, ev);
}
// Mouse lock (camera) without a warp per motion event. Darling's grab pins the pointer: every X
// motion event is answered with XWarpPointer + XSync back to the window centre and its delta is
// measured from that pin. With a 1000 Hz mouse that is ~1000 round trips/s on the main thread
// (expensive warps under Xwayland): moving the camera froze the game. Here the grab stays (pointer
// captured) but Darling's per-event pinning is turned off; deltas are taken from the previous
// event, and the pointer is recentred only when it strays more than a quarter of the window from
// the centre. The recentring warp's own event (at the centre) gets a zero delta.
double atof(const char *);
static struct { int on; NSPoint center, prev; double radius; } vine_lock;
static long vine_grabbed_ivar = -1;
static void (*orig_grabMouse)(id, SEL, BOOL);
@interface NSObject (VineLockWindow) + (id)sharedApplication; - (id)keyWindow; - (NSPoint)mouseLocationOutsideOfEventStream; - (NSRect)frame; @end
@interface NSObject (VineLockWarp) - (id)platformWindow; - (NSRect)transformFrame:(NSRect)f; - (void)warpMouse:(NSPoint)p; @end
static void vine_lock_center(id display) {
    id w = [[objc_getClass("NSApplication") sharedApplication] keyWindow];
    if (!vine_lock.on || !w) {   // first lock: Darling's grab (XGrabPointer + warp to the centre)
        orig_grabMouse(display, sel_registerName("grabMouse:"), 1);
        if (vine_grabbed_ivar >= 0) *(BOOL *)((char *)display + vine_grabbed_ivar) = 0;
    } else {                     // recentring: the grab stays, only warp (as grabMouse: computes it)
        NSRect g = [[w platformWindow] transformFrame:[w frame]];
        [display warpMouse:(NSPoint){g.origin.x + g.size.width / 2, g.origin.y + g.size.height / 2}];
    }
    NSRect f = w ? [w frame] : (NSRect){{0, 0}, {800, 600}};
    vine_lock.center = (NSPoint){f.size.width / 2, f.size.height / 2};   // where grabMouse: warps (window coords)
    if (!vine_lock.on) vine_lock.prev = vine_lock.center;   // recentring: queued events still count from the last one
    vine_lock.radius = (f.size.width < f.size.height ? f.size.width : f.size.height) / 4;
}
static void vine_grabMouse(id self, SEL _cmd, BOOL grab) {
    if (grab) { vine_cursor_hidden(self, 1); vine_lock_center(self); vine_lock.on = 1; }
    else { vine_lock.on = 0; orig_grabMouse(self, _cmd, 0); vine_cursor_hidden(self, 0); }
}
static void vine_quiet_warp(void) {
    static int done;
    Class c = done ? 0 : objc_getClass("X11Display");
    if (!c) return;
    done = 1;
    void *x11 = dlopen("/usr/lib/native/libX11.dylib", 1);
    Ivar iv = class_getInstanceVariable(c, "_display");
    Method m = class_getInstanceMethod(c, sel_registerName("warpMouse:"));
    x_warp = x11 ? dlsym(x11, "XWarpPointer") : 0; x_sync = x11 ? dlsym(x11, "XSync") : 0; x_root = x11 ? dlsym(x11, "XDefaultRootWindow") : 0;
    x_next_request = x11 ? dlsym(x11, "XNextRequest") : 0;
    x_query_pointer = x11 ? dlsym(x11, "XQueryPointer") : 0;
    Method px = class_getInstanceMethod(c, sel_registerName("postXEvent:"));
    if (px && x_next_request) orig_postXEvent = (void (*)(id, SEL, void *))method_setImplementation(px, (IMP)vine_postXEvent);
    else x_next_request = 0;   // without serials the lock falls back to recentring-by-position
    if (!iv || !m || !x_warp || !x_sync || !x_root) return;
    x_display_ivar = ivar_getOffset(iv);
    method_setImplementation(m, (IMP)vine_warp_mouse);
    Ivar g = class_getInstanceVariable(c, "_cursorGrabbed");
    Method gm = class_getInstanceMethod(c, sel_registerName("grabMouse:"));
    if (g && gm && !getenv("VINE_DARLING_GRAB")) {
        vine_grabbed_ivar = ivar_getOffset(g);
        orig_grabMouse = (void (*)(id, SEL, BOOL))method_setImplementation(gm, (IMP)vine_grabMouse);
    }
}


__attribute__((constructor)) static void vine_appkit_init(void) {
    void *x11 = dlopen("/usr/lib/native/libX11.dylib", 1);
    int (*init_threads)(void) = x11 ? (int (*)(void))dlsym(x11, "XInitThreads") : 0;
    if (!init_threads || !init_threads()) dprintf(2, "vine: XInitThreads unavailable\n");
}
#endif

#ifdef FW_Foundation
// 10.11 relative file-URL API missing from Darling's NSURL. Resolved eagerly to an absolute file
// URL (macOS keeps a relative URL + baseURL; -path/-absoluteString/-fileSystemRepresentation agree).
@interface NSString : NSObject
- (BOOL)isAbsolutePath; - (NSString *)stringByAppendingPathComponent:(NSString *)c; - (NSUInteger)length;
@end
@interface NSURL : NSObject
+ (id)fileURLWithPath:(NSString *)p; + (id)fileURLWithPath:(NSString *)p isDirectory:(BOOL)d;
- (id)initFileURLWithPath:(NSString *)p; - (id)initFileURLWithPath:(NSString *)p isDirectory:(BOOL)d;
- (NSString *)path; - (BOOL)isFileURL;
@end
static NSString *vine_resolve_path(NSString *p, NSURL *base) {
    if (!p || [p isAbsolutePath] || !base || ![base isFileURL]) return p;
    return [[base path] stringByAppendingPathComponent:p];
}
@implementation NSURL (VineRelativeFileURL)
+ (id)fileURLWithPath:(NSString *)p relativeToURL:(NSURL *)b { return [self fileURLWithPath:vine_resolve_path(p, b)]; }
+ (id)fileURLWithPath:(NSString *)p isDirectory:(BOOL)d relativeToURL:(NSURL *)b { return [self fileURLWithPath:vine_resolve_path(p, b) isDirectory:d]; }
- (id)initFileURLWithPath:(NSString *)p relativeToURL:(NSURL *)b { return [self initFileURLWithPath:vine_resolve_path(p, b)]; }
- (id)initFileURLWithPath:(NSString *)p isDirectory:(BOOL)d relativeToURL:(NSURL *)b { return [self initFileURLWithPath:vine_resolve_path(p, b) isDirectory:d]; }
@end
#endif

#ifdef FW_IOKit
// IOFBMemorySize for the placeholder display entry (CoreGraphics wrapper): the host GPU's video
// memory from the launcher (VINE_VRAM_BYTES), 2 GiB if unknown.
#define VINE_DISPLAY_SERVICE 0x56524d31u
void *vine_orig(const char *image, const char *sym);
long long atoll(const char *);
CFTypeRef CFNumberCreate(const void *, long, const void *);
unsigned char CFStringGetCString(CFStringRef, char *, long, unsigned int);
#define IOKIT_IMG "/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit.darling"
CFTypeRef IORegistryEntryCreateCFProperty(unsigned int entry, CFStringRef key, const void *alloc, unsigned int opts) {
    static CFTypeRef (*o)(unsigned int, CFStringRef, const void *, unsigned int);
    if (!o) o = (CFTypeRef (*)(unsigned int, CFStringRef, const void *, unsigned int))vine_orig(IOKIT_IMG, "IORegistryEntryCreateCFProperty");
    CFTypeRef r = entry != VINE_DISPLAY_SERVICE && o ? o(entry, key, alloc, opts) : 0;
    char k[64];
    if (!r && key && CFStringGetCString(key, k, sizeof k, 0x08000100 /* UTF-8 */) && !strcmp(k, "IOFBMemorySize")) {
        const char *v = getenv("VINE_VRAM_BYTES");
        long long bytes = v ? atoll(v) : 0;
        if (bytes < (256LL << 20)) bytes = 2LL << 30;
        r = CFNumberCreate(0, 4 /* kCFNumberSInt64Type */, &bytes);
    }
    return r;
}
// Roblox reads the whole property dictionary (IORegistryEntryCreateCFProperties) and looks up
// IOFBMemorySize in it.
void *CFDictionaryCreateMutable(const void *, long, const void *, const void *);
void CFDictionarySetValue(void *, const void *, const void *);
void CFRelease(CFTypeRef);
extern const char kCFTypeDictionaryKeyCallBacks[], kCFTypeDictionaryValueCallBacks[];
int IORegistryEntryCreateCFProperties(unsigned int entry, void **props, const void *alloc, unsigned int opts) {
    static int (*o)(unsigned int, void **, const void *, unsigned int);
    if (entry != VINE_DISPLAY_SERVICE) {
        if (!o) o = (int (*)(unsigned int, void **, const void *, unsigned int))vine_orig(IOKIT_IMG, "IORegistryEntryCreateCFProperties");
        return o ? o(entry, props, alloc, opts) : 0xe00002bc /* kIOReturnError */;
    }
    if (!props) return 0xe00002c2;   // kIOReturnBadArgument
    void *d = CFDictionaryCreateMutable(alloc, 0, kCFTypeDictionaryKeyCallBacks, kCFTypeDictionaryValueCallBacks);
    CFTypeRef v = IORegistryEntryCreateCFProperty(entry, (CFStringRef)@"IOFBMemorySize", alloc, 0);
    if (d && v) CFDictionarySetValue(d, @"IOFBMemorySize", v);
    if (v) CFRelease(v);
    *props = d;
    return d ? 0 : 0xe00002bd;   // kIOReturnNoMemory
}
int IOObjectRelease(unsigned int obj) {
    static int (*o)(unsigned int);
    if (obj == VINE_DISPLAY_SERVICE) return 0;
    if (!o) o = (int (*)(unsigned int))vine_orig(IOKIT_IMG, "IOObjectRelease");
    return o ? o(obj) : 0;
}
#endif

#ifdef FW_IOKit
// Darling's iokitd serves only display/IOSurface/power objects; matching notifications for anything
// else fail, and a NULL notification port is dereferenced. Report "nothing matched" instead.
void *vine_orig(const char *image, const char *sym);
typedef unsigned int io_iterator_t;
typedef int kern_return_t;
#define kIOReturnBadArgument ((kern_return_t)0xe00002c2)
kern_return_t IOServiceAddMatchingNotification(void *port, const char *type, CFTypeRef matching,
                                               void *callback, void *refcon, io_iterator_t *it) {
    static kern_return_t (*orig)(void *, const char *, CFTypeRef, void *, void *, io_iterator_t *);
    if (!orig) orig = vine_orig("/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit.darling",
                                "IOServiceAddMatchingNotification");
    if (it) *it = 0;
    if (!port || !orig) {
        VINE_LOG_ONCE("IOServiceAddMatchingNotification(NULL port)");
        void CFRelease(CFTypeRef);
        if (matching) CFRelease(matching);   // the call consumes one reference to matching
        return kIOReturnBadArgument;
    }
    return orig(port, type, matching, callback, refcon, it);
}
#endif

#ifdef FW_CFNetwork
// +[NSURLSession sharedSession] asks the private __NSCFURLSessionConfiguration (an NSObject
// subclass in Darling, not exported) for +defaultSessionConfiguration; only the public
// NSURLSessionConfiguration has it. Added at runtime since the class can't be linked against.
@interface NSURLSessionConfiguration : NSObject + (id)defaultSessionConfiguration; @end
Class objc_getClass(const char *);
static id vine_default_config(id self, SEL _cmd) { return [NSURLSessionConfiguration defaultSessionConfiguration]; }
__attribute__((constructor)) static void vine_cfnetwork_config(void) {
    Class c = objc_getClass("__NSCFURLSessionConfiguration");
    if (c) class_addMethod(object_getClass((id)c), @selector(defaultSessionConfiguration), (IMP)vine_default_config, "@@:");
}
#endif

#ifdef FW_IOKit
// Roblox's device-watch cleanup can pass NULL after a failed registration (iokitd has no HID
// notifications); Darling dereferences it.
void IONotificationPortDestroy(void *port) {
    static void (*orig)(void *);
    if (!port) { VINE_LOG_ONCE("IONotificationPortDestroy(NULL)"); return; }
    if (!orig) orig = vine_orig("/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit.darling", "IONotificationPortDestroy");
    if (orig) orig(port);
}
#endif

#ifdef FW_AppKit
// -[NSOpenGLContext setView:] (Darling/Cocotron) destroys the old EGL window surface and creates a
// new one, but the CGL context keeps drawing to the destroyed surface until the app calls
// -makeCurrentContext again. macOS re-attaches on setView:, so Roblox doesn't: every eglSwapBuffers
// then fails with EGL_BAD_SURFACE (60 invisible frames/s). Re-attach at flush when stale.
typedef void *Ivar;
Ivar class_getInstanceVariable(Class, const char *);
long ivar_getOffset(Ivar);
void *CGLGetCurrentContext(void);
int CGLContextMakeCurrentAndAttachToWindow(void *ctx, void *window);
int CGLFlushDrawable(void *ctx);
@interface NSOpenGLContext : NSObject @end
@interface NSObject (VineNative) - (void *)nativeWindow; @end
char *getenv(const char *);
static void *vine_ivar(id o, const char *name) {
    Ivar iv = class_getInstanceVariable(object_getClass(o), name);
    return iv ? *(void **)((char *)o + ivar_getOffset(iv)) : 0;
}
static void vine_event_trace_install(void);
@implementation NSOpenGLContext (VineReattach)
- (void)flushBuffer {
    vine_event_trace_install();
    static void *(*get_surface)(int);
    static int looked;
    if (!looked) {
        void *egl = dlopen("/usr/lib/native/libEGL.dylib", 1);
        get_surface = egl ? (void *(*)(int))dlsym(egl, "eglGetCurrentSurface") : 0;
        looked = 1;
    }
    void *ctx = vine_ivar(self, "_glContext"), *win = vine_ivar(self, "_cglWindow");
    static int logged;
    if (logged < 3 && getenv("VINE_GL_DEBUG")) {
        logged++;
        id sub = (id)vine_ivar(self, "_subwindow");
        dprintf(2, "vine-gl: flush ctx=%p cgl-current=%p win(surface)=%p egl-draw=%p view=%p subwindow=%p xwin=0x%lx\n", ctx, CGLGetCurrentContext(),
                win, get_surface ? get_surface(0x3059) : (void *)-1, vine_ivar(self, "_view"), sub,
                sub ? (unsigned long)[sub nativeWindow] : 0UL);
        void *egl = dlopen("/usr/lib/native/libEGL.dylib", 1);
        unsigned (*query)(void *, void *, int, int *) = egl ? dlsym(egl, "eglQuerySurface") : 0;
        void *(*getdpy)(void) = egl ? dlsym(egl, "eglGetCurrentDisplay") : 0;
        int w = -1, h = -1, fb = -1, err = -1;
        unsigned char px[4] = {0};
        if (query && getdpy) { query(getdpy(), win, 0x3057 /*EGL_WIDTH*/, &w); query(getdpy(), win, 0x3056 /*EGL_HEIGHT*/, &h); }
        void glGetIntegerv(unsigned, int *); unsigned glGetError(void); void glReadBuffer(unsigned);
        void glReadPixels(int, int, int, int, unsigned, unsigned, void *);
        glGetIntegerv(0x8CA6 /*GL_DRAW_FRAMEBUFFER_BINDING*/, &fb);
        int cx = w > 0 ? w / 2 : 0, cy = h > 0 ? h / 2 : 0, prevread = 0;
        glGetIntegerv(0x8CAA /*GL_READ_FRAMEBUFFER_BINDING*/, &prevread);
        void glBindFramebuffer(unsigned, unsigned);
        glBindFramebuffer(0x8CA8 /*GL_READ_FRAMEBUFFER*/, 0); glReadBuffer(0x0405 /*GL_BACK*/);
        glReadPixels(cx, cy, 1, 1, 0x1908 /*GL_RGBA*/, 0x1401 /*UNSIGNED_BYTE*/, px);
        glBindFramebuffer(0x8CA8, prevread);
        err = glGetError();
        dprintf(2, "vine-gl: surface %dx%d drawfb=%d back(center)=%u,%u,%u,%u glerr=0x%x\n", w, h, fb, px[0], px[1], px[2], px[3], err);
    }
    if (!getenv("VINE_NO_GLREATTACH") && win && get_surface && CGLGetCurrentContext() == ctx && get_surface(0x3059 /* EGL_DRAW */) != win) {
        VINE_LOG_ONCE("NSOpenGLContext re-attached to its view's current surface");
        CGLContextMakeCurrentAndAttachToWindow(ctx, win);
    }
    CGLFlushDrawable(ctx);
    // Flush the shared X connection so presented frames reach the server even when the app runs
    // its own loop instead of AppKit's (which flushes while polling for events).
    static int (*xflush)(void *);
    static int xlooked;
    if (!xlooked) { void *x11 = dlopen("/usr/lib/native/libX11.dylib", 1); xflush = x11 ? (int (*)(void *))dlsym(x11, "XFlush") : 0; xlooked = 1; }
    void *xdpy = vine_main_display ? vine_ivar(vine_main_display, "_display") : 0;
    if (xflush && xdpy && !getenv("VINE_NO_XFLUSH")) xflush(xdpy);
}
@end
#endif

#ifdef FW_AppKit
// VINE_GL_DEBUG=1: trace NSOpenGLContext / NSOpenGLView lifecycle (method swizzling, logs only).
SEL sel_registerName(const char *);
typedef void *Method;
Method class_getInstanceMethod(Class, SEL);
IMP method_setImplementation(Method, IMP);
Class objc_getClass(const char *);
void *pthread_self(void);
#define VINE_TRACE(cls, sel, ret, params, args, fmt, ...) \
    static ret (*orig_##sel)(id, SEL params); \
    static ret trace_##sel(id self, SEL _cmd params) { \
        dprintf(2, "vine-gl: thread=%p -[%s %s] self=%p " fmt "\n", pthread_self(), class_getName(object_getClass(self)), sel_getName(_cmd), self, ##__VA_ARGS__); \
        return orig_##sel(self, _cmd args); }
#define COMMA ,
VINE_TRACE(NSOpenGLContext, initWithFormat_shareContext_, id, COMMA id f COMMA id share, COMMA f COMMA share, "share=%p", share)
VINE_TRACE(NSOpenGLContext, setView_, void, COMMA id v, COMMA v, "view=%p", v)
VINE_TRACE(NSOpenGLContext, makeCurrentContext, void, , , "ctx=%p", vine_ivar(self, "_glContext"))
VINE_TRACE(NSOpenGLContext, clearDrawable, void, , , "%s", "")
VINE_TRACE(NSOpenGLContext, update, void, , , "%s", "")
VINE_TRACE(NSOpenGLView, setOpenGLContext_, void, COMMA id c, COMMA c, "ctx=%p", c)
static void vine_swz(const char *cls, const char *sel, IMP repl, void **orig) {
    Method m = class_getInstanceMethod(objc_getClass(cls), sel_registerName(sel));
    if (m) *orig = (void *)method_setImplementation(m, repl);
}
__attribute__((constructor)) static void vine_gl_trace(void) {
    if (!getenv("VINE_GL_DEBUG")) return;
    vine_swz("NSOpenGLContext", "initWithFormat:shareContext:", (IMP)trace_initWithFormat_shareContext_, (void **)&orig_initWithFormat_shareContext_);
    vine_swz("NSOpenGLContext", "setView:", (IMP)trace_setView_, (void **)&orig_setView_);
    vine_swz("NSOpenGLContext", "makeCurrentContext", (IMP)trace_makeCurrentContext, (void **)&orig_makeCurrentContext);
    vine_swz("NSOpenGLContext", "clearDrawable", (IMP)trace_clearDrawable, (void **)&orig_clearDrawable);
    vine_swz("NSOpenGLContext", "update", (IMP)trace_update, (void **)&orig_update);
    vine_swz("NSOpenGLView", "setOpenGLContext:", (IMP)trace_setOpenGLContext_, (void **)&orig_setOpenGLContext_);
}
#endif

#ifdef FW_QuartzCore
// Darling's layer compositor (-[CALayerContext renderLayer:], timer-driven on the main thread for
// layer-backed views) makes its own GL context current and never restores the caller's. Roblox's
// view is layer-backed and renders on the main thread with the context it made current once, so
// after the first compositor tick all its drawing went to the compositor's surfaceless context and
// every eglSwapBuffers failed (EGL_BAD_SURFACE). AppKit/CA must not change the app's GL context.
typedef void *Method;
Method class_getInstanceMethod(Class, SEL);
IMP method_setImplementation(Method, IMP);
Class objc_getClass(const char *);
SEL sel_registerName(const char *);
void *CGLGetCurrentContext(void);
int CGLSetCurrentContext(void *);
char *getenv(const char *);
static void (*orig_renderLayer)(id, SEL, id);
static void vine_renderLayer(id self, SEL _cmd, id layer) {
    static int skip = -1;
    if (skip < 0) skip = getenv("VINE_SKIP_LAYER_RENDER") != 0;   // diagnostic
    if (skip) return;
    void *prev = CGLGetCurrentContext();
    orig_renderLayer(self, _cmd, layer);
    CGLSetCurrentContext(prev);
}
__attribute__((constructor)) static void vine_quartzcore_init(void) {
    Method m = class_getInstanceMethod(objc_getClass("CALayerContext"), sel_registerName("renderLayer:"));
    if (getenv("VINE_NO_LAYERFIX")) return;
    if (m) orig_renderLayer = (void (*)(id, SEL, id))method_setImplementation(m, (IMP)vine_renderLayer);
    else dprintf(2, "vine: CALayerContext renderLayer: not found\n");
}
#endif

#ifdef FW_AppKit
// VINE_TRACE_EVENTS=1: log NSEvent dispatch (type, window location) through NSApplication, NSWindow
// and Roblox's view, to see where input stops. Diagnostic only.
@interface NSEvent : NSObject - (unsigned long)type; - (NSPoint)locationInWindow; - (id)window; + (NSPoint)mouseLocation;
- (long)buttonNumber; - (long)clickCount; - (double)timestamp; - (long)windowNumber;
- (unsigned short)keyCode; - (id)characters; - (unsigned long)modifierFlags; @end
@interface NSObject (VineUTF8) - (const char *)UTF8String; @end
// Scroll wheel: Darling's NSEvent has deltaX/deltaY (one line per wheel notch) but not the 10.7
// accessors Roblox reads, so every scroll read as 0 (game list and menus did not scroll). A wheel
// is a line-based, non-precise device without gesture phases, which is what these report.
@interface NSEvent (VineDeltas) - (double)deltaX; - (double)deltaY; @end
@implementation NSEvent (VineScrolling)
- (double)scrollingDeltaX { return [self deltaX]; }
- (double)scrollingDeltaY { return [self deltaY]; }
- (BOOL)hasPreciseScrollingDeltas { return 0; }
- (BOOL)isDirectionInvertedFromDevice { return 0; }
- (unsigned long)phase { return 0; }          // NSEventPhaseNone
- (unsigned long)momentumPhase { return 0; }
@end
@interface NSProcessInfo : NSObject + (id)processInfo; - (double)systemUptime; @end
@interface NSObject (VineFrame) - (NSRect)frame; @end
@interface NSObject (VineFocus) - (BOOL)isKeyWindow; - (BOOL)isActive; @end
extern id NSApp;
#define VINE_EV_TRACE(slot) \
    static void (*orig_ev_##slot)(id, SEL, id); \
    static void trace_ev_##slot(id self, SEL _cmd, id e) { \
        unsigned long t = [e type]; \
        static int moves; \
        if ((t == 5 || t == 6) && moves++ > 20) ; else if (t != 27 && t != 22) {   /* first 20 moves, no periodic/scroll */ \
            NSPoint p = [e locationInWindow]; \
            dprintf(2, "vine-ev: -[%s %s] type=%lu at %.0f,%.0f key=%d active=%d\n", class_getName(object_getClass(self)), sel_getName(_cmd), t, p.x, p.y, \
                    (int)(BOOL)(long)[[e window] isKeyWindow], (int)(BOOL)(long)[NSApp isActive]); \
            if (t == 10 || t == 11) dprintf(2, "vine-ev:   keyCode=%u chars='%s' modifiers=0x%lx\n", [e keyCode], [[e characters] UTF8String] ?: "", [e modifierFlags]); \
            if (t == 1 || t == 2) { NSPoint m = [NSEvent mouseLocation]; NSRect f = [[e window] frame]; \
                dprintf(2, "vine-ev:   mouseLocation=%.0f,%.0f window.frame=%.0f,%.0f %.0fx%.0f buttonNumber=%ld clickCount=%ld timestamp=%.3f uptime=%.3f windowNumber=%ld\n", \
                        m.x, m.y, f.origin.x, f.origin.y, f.size.width, f.size.height, [e buttonNumber], [e clickCount], [e timestamp], \
                        [[NSProcessInfo processInfo] systemUptime], [e windowNumber]); } } \
        orig_ev_##slot(self, _cmd, e); }
VINE_EV_TRACE(0) VINE_EV_TRACE(1) VINE_EV_TRACE(2) VINE_EV_TRACE(3) VINE_EV_TRACE(4) VINE_EV_TRACE(5)
extern id NSApp;
// Installed on the first presented frame (from -flushBuffer): by then the app's own classes are
// loaded and NSApp exists, so the real application subclass is hooked.
static void vine_event_trace_install(void) {
    static int done;
    if (done || !getenv("VINE_TRACE_EVENTS")) return;
    done = 1;
    const char *appcls = NSApp ? class_getName(object_getClass(NSApp)) : "NSApplication";
    dprintf(2, "vine-ev: installing (app class %s)\n", appcls);
    struct { const char *cls, *sel; IMP repl; void **orig; } t[] = {
        {appcls, "sendEvent:", (IMP)trace_ev_0, (void **)&orig_ev_0},
        {"NSWindow", "sendEvent:", (IMP)trace_ev_1, (void **)&orig_ev_1},
        {"RobloxOgreView", "mouseDown:", (IMP)trace_ev_2, (void **)&orig_ev_2},
        {"RobloxOgreView", "mouseUp:", (IMP)trace_ev_3, (void **)&orig_ev_3},
        {"NSView", "mouseDown:", (IMP)trace_ev_4, (void **)&orig_ev_4},
        {"RobloxOgreView", "mouseMoved:", (IMP)trace_ev_5, (void **)&orig_ev_5},
    };
    for (unsigned i = 0; i < sizeof t / sizeof *t; i++) {
        Class c = objc_getClass(t[i].cls);
        Method m = c ? class_getInstanceMethod(c, sel_registerName(t[i].sel)) : 0;
        if (m) *t[i].orig = (void *)method_setImplementation(m, t[i].repl);
        else dprintf(2, "vine-ev: %s %s not found\n", t[i].cls, t[i].sel);
    }
}
#endif

#ifdef FW_AppKit
// Darling (Cocotron) only turns X11 pointer motion into NSMouseMoved, and only delivers
// NSTrackingMouseMoved tracking areas, when the window's acceptsMouseMovedEvents is set. On macOS a
// tracking area with NSTrackingMouseMoved receives mouseMoved: regardless; Roblox relies on that, so
// it never saw pointer motion and its UI could not hit-test clicks (buttons ignored).
// ponytail: every window accepts moves; restrict to windows with mouse-moved tracking areas if the
// extra events ever matter.
@implementation NSWindow (VineMouseMoved)
- (BOOL)acceptsMouseMovedEvents { return 1; }
@end
#endif

#ifdef FW_CoreGraphics
// CGAssociateMouseAndMouseCursorPosition(connected): true = normal (mouse moves the cursor),
// false = pointer lock. Darling calls [display grabMouse:connected] -- inverted -- on every call;
// Roblox calls it with true every frame, so the pointer was grabbed and warped to the window centre
// ~150x/s (with XSync + a log line each time): the cursor froze on the desktop, clicks "froze".
// Correct sense, and only act when the state changes.
Class objc_getClass(const char *);
@interface NSObject (VineDisplay) + (id)currentDisplay; - (void)grabMouse:(BOOL)grab; @end
static int vine_mouse_associated = 1;
int CGAssociateMouseAndMouseCursorPosition(unsigned int connected) {
    int state = vine_mouse_associated;
    connected = connected != 0;
    if ((int)connected == state) return 0;
    vine_mouse_associated = connected;
    id display = [objc_getClass("NSDisplay") currentDisplay];
    if (!display) return 1001;   // kCGErrorInvalidConnection
    [display grabMouse:!connected];
    return 0;
}
// While the mouse is locked, Roblox warps the cursor every frame. On macOS that moves only the frozen
// logical cursor; under Darling every warp is a real X pointer move, and the grab turns it into a
// motion event with a huge delta, then warps back to its pin point: a ~4000 warps/s feedback loop
// (285k "Warp to" lines in one session), the game froze at any movement, the camera jumped
// (finding matches MacOBlox's notes). Darling's grab keeps the pointer pinned, so ignore them.
// Display IOKit entry: Darling's CGDisplayIOServicePort finds no IODisplayConnect and returns 0, so
// Roblox could not read IOFBMemorySize (video memory), assumed 64 MB ("gpu_memMB 64" in its perf
// reports) and lowered quality. A placeholder entry answered by the IOKit wrapper (finding credited
// to MacOBlox, gpu_info.c).
#define VINE_DISPLAY_SERVICE 0x56524d31u   /* 'VRM1' */
void *vine_orig(const char *image, const char *sym);
unsigned int CGDisplayIOServicePort(unsigned int display) {
    static unsigned int (*o)(unsigned int);
    if (!o) o = (unsigned int (*)(unsigned int))vine_orig("/System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics.darling", "CGDisplayIOServicePort");
    unsigned int r = o ? o(display) : 0;
    return r ? r : VINE_DISPLAY_SERVICE;
}
typedef struct { double x, y; } VinePoint;
void *vine_orig(const char *image, const char *sym);
int CGWarpMouseCursorPosition(VinePoint p) {
    static int (*orig)(VinePoint);
    if (!vine_mouse_associated) return 0;
    if (!orig) orig = (int (*)(VinePoint))vine_orig("/System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics.darling", "CGWarpMouseCursorPosition");
    return orig ? orig(p) : 1001;
}
#endif

#ifdef FW_AppKit
// NSEvent fixes (Darling/Cocotron vs macOS):
//  - buttonNumber is the X11 button (left=1, middle=2, right=3, back/forward=8/9); macOS uses
//    left=0, right=1, middle=2, then 3, 4...
//  - timestamp is CFAbsoluteTime (seconds since 2001); macOS uses seconds since boot, the same
//    clock as -[NSProcessInfo systemUptime]. Roblox drops events whose times don't line up.
double CFAbsoluteTimeGetCurrent(void);
uint64_t mach_absolute_time(void);
typedef struct { uint32_t numer, denom; } vine_timebase_t;
int mach_timebase_info(vine_timebase_t *);
static double vine_uptime(void) {   // seconds since boot (mach_absolute_time is CLOCK_MONOTONIC on Darling)
    static vine_timebase_t tb;
    if (!tb.denom) mach_timebase_info(&tb);
    return (double)mach_absolute_time() * tb.numer / tb.denom / 1e9;
}
static long vine_mac_button(long b) {
    switch (b) { case 1: return 0; case 3: return 1; case 2: return 2; case 8: return 3; case 9: return 4; default: return b; }
}
// NSEvent and its concrete NSEvent_mouse each implement buttonNumber.
static long (*orig_buttonNumber)(id, SEL), (*orig_mouse_buttonNumber)(id, SEL);
static long vine_buttonNumber(id self, SEL _cmd) { return vine_mac_button(orig_buttonNumber(self, _cmd)); }
static long vine_mouse_buttonNumber(id self, SEL _cmd) { return vine_mac_button(orig_mouse_buttonNumber(self, _cmd)); }
static double (*orig_timestamp)(id, SEL);
static double vine_timestamp(id self, SEL _cmd) {
    double t = orig_timestamp(self, _cmd);
    return t > 1e8 ? t - (CFAbsoluteTimeGetCurrent() - vine_uptime()) : t;   // only re-base absolute times
}
__attribute__((constructor)) static void vine_nsevent_fixes(void) {
    Class c = objc_getClass("NSEvent");
    Method m;
    if ((m = class_getInstanceMethod(c, sel_registerName("buttonNumber"))))
        orig_buttonNumber = (long (*)(id, SEL))method_setImplementation(m, (IMP)vine_buttonNumber);
    Class cm = objc_getClass("NSEvent_mouse");
    if (cm && (m = class_getInstanceMethod(cm, sel_registerName("buttonNumber"))) && m != class_getInstanceMethod(c, sel_registerName("buttonNumber")))
        orig_mouse_buttonNumber = (long (*)(id, SEL))method_setImplementation(m, (IMP)vine_mouse_buttonNumber);
    if ((m = class_getInstanceMethod(c, sel_registerName("timestamp"))))
        orig_timestamp = (double (*)(id, SEL))method_setImplementation(m, (IMP)vine_timestamp);
}
#endif

#ifdef FW_Foundation
// -[NSProcessInfo systemUptime] returns wall-clock time (seconds since 1970) in Darling; macOS returns
// seconds since boot, which event timestamps are measured against.
uint64_t mach_absolute_time(void);
typedef struct { uint32_t numer, denom; } vine_timebase_t;
int mach_timebase_info(vine_timebase_t *);
@interface NSProcessInfo : NSObject @end
@implementation NSProcessInfo (VineUptime)
- (double)systemUptime {
    static vine_timebase_t tb;
    if (!tb.denom) mach_timebase_info(&tb);
    return (double)mach_absolute_time() * tb.numer / tb.denom / 1e9;
}
@end
#endif

#ifdef FW_AppKit
// Darling's X11 backend handles WM_DELETE_WINDOW by scheduling -platformWindowWillClose: as an
// ordered NSRunLoop perform. Roblox's main thread spins CFRunLoop directly, which does not service
// those performs promptly (2.7 s on the user's desktop, never under Xvfb), so closing the window
// lagged. Deliver it through the main dispatch queue, which that CFRunLoop does service.
struct dispatch_queue_s;
extern struct dispatch_queue_s _dispatch_main_q;
void dispatch_async_f(struct dispatch_queue_s *, void *, void (*)(void *));
id objc_retain(id); void objc_release(id);
static void (*orig_perform)(id, SEL, SEL, id, id, unsigned long, id);
struct vine_close { id target, arg; SEL sel; };
static void vine_after_window_closed(void);

static void vine_close_now(void *p) {
    struct vine_close *c = p;
    ((void (*)(id, SEL, id))objc_msgSend)(c->target, c->sel, c->arg);
    vine_after_window_closed();
    objc_release(c->target); objc_release(c->arg); free(c);
}
static void vine_perform(id self, SEL _cmd, SEL sel, id target, id arg, unsigned long order, id modes) {
    if (sel == sel_registerName("platformWindowWillClose:")) {
        static volatile int pending;   // Darling cancels+reschedules on repeated close requests: coalesce
        if (__atomic_exchange_n(&pending, 1, __ATOMIC_ACQ_REL)) return;
        struct vine_close *c = malloc(sizeof *c);
        c->target = objc_retain(target); c->arg = objc_retain(arg); c->sel = sel;
        dispatch_async_f(&_dispatch_main_q, c, vine_close_now);
        __atomic_store_n(&pending, 0, __ATOMIC_RELEASE);
        return;
    }
    orig_perform(self, _cmd, sel, target, arg, order, modes);
}
// macOS semantics for quitting after the last window closes, plus a teardown watchdog.
//  - Cocotron's -_checkForTerminate quits whenever no non-panel window is visible -- including windows
//    only hidden for a moment (place loads, returning to the menu) -- regardless of the delegate.
//    (Finding credited to MacOBlox.) It becomes a no-op; the check runs when a window really closes.
//  - On close: no visible windows left and -applicationShouldTerminateAfterLastWindowClosed: says YES
//    -> -terminate:, as on macOS.
//  - -terminate: arms a watchdog: Roblox's teardown can take >10 s under Darling; after 3 s the
//    process exits (the app has had applicationShouldTerminate:/WillTerminate: by then).
int pthread_create(void **, void *, void *(*)(void *), void *);
unsigned int sleep(unsigned int);
void _exit(int);
static void *vine_quit_watchdog(void *a) { sleep(3); dprintf(2, "vine: teardown exceeded 3 s, exiting\n"); _exit(0); return 0; }
static void (*orig_terminate)(id, SEL, id);
static void vine_terminate(id self, SEL _cmd, id sender) {
    static int armed;
    if (!armed++ && !getenv("VINE_NO_QUIT_WATCHDOG")) { void *t; pthread_create(&t, 0, vine_quit_watchdog, 0); }
    orig_terminate(self, _cmd, sender);
}
static void vine_check_for_terminate(id self, SEL _cmd) {}
static void vine_after_window_closed(void) {
    id app = NSApp, windows = ((id (*)(id, SEL))objc_msgSend)(app, sel_registerName("windows"));
    unsigned long n = ((unsigned long (*)(id, SEL))objc_msgSend)(windows, sel_registerName("count"));
    Class panel = objc_getClass("NSPanel");
    for (unsigned long i = 0; i < n; i++) {
        id w = ((id (*)(id, SEL, unsigned long))objc_msgSend)(windows, sel_registerName("objectAtIndex:"), i);
        if (!((BOOL (*)(id, SEL, Class))objc_msgSend)(w, sel_registerName("isKindOfClass:"), panel) &&
            ((BOOL (*)(id, SEL))objc_msgSend)(w, sel_registerName("isVisible")))
            return;
    }
    id d = ((id (*)(id, SEL))objc_msgSend)(app, sel_registerName("delegate"));
    SEL q = sel_registerName("applicationShouldTerminateAfterLastWindowClosed:");
    if (d && ((BOOL (*)(id, SEL, SEL))objc_msgSend)(d, sel_registerName("respondsToSelector:"), q) &&
        ((BOOL (*)(id, SEL, id))objc_msgSend)(d, q, app))
        ((void (*)(id, SEL, id))objc_msgSend)(app, sel_registerName("terminate:"), app);
}
__attribute__((constructor)) static void vine_close_fix(void) {
    Method t = class_getInstanceMethod(objc_getClass("NSApplication"), sel_registerName("terminate:"));
    if (t) orig_terminate = (void (*)(id, SEL, id))method_setImplementation(t, (IMP)vine_terminate);
    Method k = class_getInstanceMethod(objc_getClass("NSApplication"), sel_registerName("_checkForTerminate"));
    if (k) method_setImplementation(k, (IMP)vine_check_for_terminate);
    Method m = class_getInstanceMethod(objc_getClass("NSRunLoop"), sel_registerName("performSelector:target:argument:order:modes:"));
    if (m) orig_perform = (void (*)(id, SEL, SEL, id, id, unsigned long, id))method_setImplementation(m, (IMP)vine_perform);
    else dprintf(2, "vine: NSRunLoop performSelector:target:argument:order:modes: not found\n");
}
#endif

#ifdef FW_AppKit
// Linux has no global menu bar, so Darling (Cocotron) draws the app's main menu as a strip inside
// every titled window. Cocotron's override point +hasMainMenuForStyleMask: turns that off: no strip,
// the content view gets the whole window. Key equivalents still work (they go through NSApp's main
// menu, not the strip). VINE_MENU_BAR=1 restores it.
@implementation NSWindow (VineNoMenuBar)
+ (BOOL)hasMainMenuForStyleMask:(unsigned long)styleMask {
    static int show = -1;
    if (show < 0) show = getenv("VINE_MENU_BAR") && *getenv("VINE_MENU_BAR") == '1';
    return show && (styleMask & 1 /* NSWindowStyleMaskTitled */);
}
@end
#endif

#ifdef FW_OpenGL
// Roblox's GLSL pack declares "#version 150" but 23 of its 733 shaders (smooth terrain, grass)
// multiply uint by int literals, e.g. CB12[((uint(x) >> 8u) & 255u) * 1 + 0]. Implicit int->uint
// conversion only exists from GLSL 4.00; Apple's compiler accepts it, Mesa rejects it, so terrain
// failed to compile. Sources declaring 150 are submitted as 400 (all 733 compile; checked with
// tests/host/glsl_check.c). Roblox requests a 3.2 core context; Mesa provides 4.x core.
typedef unsigned int GLuint; typedef int GLsizei, GLint; typedef char GLchar;
void *vine_orig(const char *image, const char *sym);
size_t strlen(const char *);
void *memcpy(void *, const void *, size_t);
void glShaderSource(GLuint shader, GLsizei count, const GLchar *const *strings, const GLint *lengths) {
    static void (*orig)(GLuint, GLsizei, const GLchar *const *, const GLint *);
    if (!orig) orig = vine_orig("/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL.darling", "glShaderSource");
    if (!orig) return;
    if (count < 1 || !strings || !strings[0]) { orig(shader, count, strings, lengths); return; }
    size_t n = lengths && lengths[0] >= 0 ? (size_t)lengths[0] : strlen(strings[0]);
    const char *s = strings[0], *v = 0;
    for (size_t i = 0; i + 12 <= n && i < 256; i++)   // the #version line comes first (after comments)
        if (!__builtin_memcmp(s + i, "#version 150", 12)) { v = s + i; break; }
    if (!v) { orig(shader, count, strings, lengths); return; }
    char *copy = malloc(n + 1);
    memcpy(copy, s, n); copy[n] = 0;
    memcpy(copy + (v - s) + 9, "400", 3);
    const GLchar *strs[count]; GLint lens[count];
    for (GLsizei i = 0; i < count; i++) { strs[i] = strings[i]; lens[i] = lengths ? lengths[i] : -1; }
    strs[0] = copy; lens[0] = (GLint)n;
    orig(shader, count, strs, lens);
    free(copy);
}
// OpenGL core profile for contexts that ask for one (finding credited to MacOBlox, gl_profile.c).
// Roblox's pixel format requests kCGLPFAOpenGLProfile 3.2 Core, as macOS requires for modern GL;
// Darling keeps the attribute but CGLCreateContext calls eglCreateContext with no attributes, i.e. a
// Compatibility context. There Roblox detected no multisample textures ("Caps: Texture: ... MSAA 0")
// and never enabled MSAA (graphics settings changed little). The Compatibility context Darling made is
// replaced by a Core one with the same config and sharing; contexts without a profile request
// (Darling's own compositor) are untouched. Darling's layout (OpenGL.c): pixel format attributes at
// +8, context egl_context at +72; display/config are file statics.
#define GL_IMG "/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL.darling"
void *vine_local_symbol(const char *image_suffix, const char *sym);
void *dlopen(const char *, int); void *dlsym(void *, const char *);
// Darling's CGLChoosePixelFormat copies the attribute list only up to the first 0, and attribute
// values can be 0 (e.g. a stencil size), so the profile request was usually lost before CGL saw it.
// The AppKit wrapper reads NSOpenGLPixelFormat's attributes properly and marks the CGL pixel format.
static struct { void *pix; int profile; } vine_core_pix[16];
void vine_gl_mark_profile(void *cglpix, int profile) {
    for (int i = 0; i < 16; i++) if (!vine_core_pix[i].pix || vine_core_pix[i].pix == cglpix) { vine_core_pix[i].pix = cglpix; vine_core_pix[i].profile = profile; return; }
}
int CGLCreateContext(void *pix, void *share, void **out) {
    static int (*orig)(void *, void *, void **);
    static void *(*egl_create)(void *, void *, void *, const int *); static unsigned (*egl_destroy)(void *, void *);
    static void **display, **config; static int ready = -1;
    if (!orig) orig = vine_orig(GL_IMG, "CGLCreateContext");
    int r = orig ? orig(pix, share, out) : 10000;
    if (ready < 0) {
        void *egl = dlopen("/usr/lib/native/libEGL.dylib", 1);
        egl_create = egl ? dlsym(egl, "eglCreateContext") : 0; egl_destroy = egl ? dlsym(egl, "eglDestroyContext") : 0;
        display = vine_local_symbol("OpenGL.framework/Versions/A/OpenGL.darling", "_display");
        config = vine_local_symbol("OpenGL.framework/Versions/A/OpenGL.darling", "_config");
        ready = egl_create && egl_destroy && display && config && !getenv("VINE_GL_COMPAT");
        if (!ready) dprintf(2, "vine-gl: core profile unavailable (egl %d/%d, display %p, config %p)\n", !!egl_create, !!egl_destroy, display, config);
    }
    if (r || !ready || !pix || !out || !*out) return r;
    const int *attrs = *(const int **)((char *)pix + 8);
    int profile = 0;
    for (int i = 0; attrs && attrs[i] && i < 128; i++)
        if (attrs[i] == 99 /* kCGLPFAOpenGLProfile */) { profile = attrs[i + 1]; break; }
    for (int i = 0; !profile && i < 16; i++) if (vine_core_pix[i].pix == pix) profile = vine_core_pix[i].profile;
    if (profile < 0x3200 /* kCGLOGLPVersion_3_2_Core */) return r;
    void **ctx = (void **)((char *)*out + 72);
    void *shared = share ? *(void **)((char *)share + 72) : 0;
    const int core[] = {0x3098 /* MAJOR */, 3, 0x30FB /* MINOR */, 2, 0x30FD /* PROFILE_MASK */, 1 /* CORE */, 0x3038 /* NONE */};
    void *c = egl_create(*display, *config, shared, core);
    if (c) {
        egl_destroy(*display, *ctx); *ctx = c;
        static int said; if (!said++) dprintf(2, "vine-gl: core profile context (requested 0x%x)\n", profile);
    }
    return r;
}

// Shader compile/link time in the log ("vine-gl: ... ms" for calls over 5 ms, with running totals):
// in game, framerate drops to ~20 whenever abilities/particles appear; compiling new programs on
// first use would show up here.
uint64_t mach_absolute_time(void);
static unsigned vine_gl_n; static double vine_gl_ms;
static void vine_gl_time(const char *what, uint64_t t0) {
    double ms = (mach_absolute_time() - t0) / 1e6;
    vine_gl_n++; vine_gl_ms += ms;
    if (ms > 5 || vine_gl_n == 1) dprintf(2, "vine-gl: %s %.1f ms (total %u calls, %.0f ms)\n", what, ms, vine_gl_n, vine_gl_ms);
}
void glCompileShader(GLuint sh) {
    static void (*orig)(GLuint);
    if (!orig) orig = vine_orig("/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL.darling", "glCompileShader");
    uint64_t t0 = mach_absolute_time(); orig(sh); vine_gl_time("glCompileShader", t0);
}
void glLinkProgram(GLuint prog) {
    static void (*orig)(GLuint);
    if (!orig) orig = vine_orig("/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL.darling", "glLinkProgram");
    uint64_t t0 = mach_absolute_time(); orig(prog); vine_gl_time("glLinkProgram", t0);
}
#endif

#ifdef FW_AudioToolbox
// Darling's HAL output unit (CoreAudio.component: AUHAL, DefaultOutputAU, SystemOutputAU) inherits
// AUBase::ValidFormat, which only accepts the canonical non-interleaved float format; Apple's AUHAL
// accepts any linear PCM. Game engines ask for interleaved float (FMOD in Roblox), get
// kAudioUnitErr_FormatNotSupported and give up (FMOD_ERR_OUTPUT_INIT, no sound). AUHAL hands the
// format to the device, which takes interleaved PCM, so accepting LPCM there is correct. The
// component loads lazily: patch it right after the first AudioComponentInstanceNew.
void *vine_orig(const char *image, const char *sym);
void *vine_local_symbol(const char *image_suffix, const char *sym);
int vine_detour_addr(void *fn, void *repl);
typedef struct { double rate; uint32_t formatID, flags, bytesPerPacket, framesPerPacket, bytesPerFrame, channels, bits, reserved; } VineASBD;
static BOOL vine_auhal_valid_format(void *self, uint32_t scope, uint32_t element, const VineASBD *f) {
    return f && f->formatID == 0x6c70636d /* 'lpcm' */ && f->channels > 0 && f->channels <= 32 &&
           (f->bits == 8 || f->bits == 16 || f->bits == 24 || f->bits == 32 || f->bits == 64) && f->rate > 0;
}
// AUHAL::StreamFormatWritable is `!running && IsInitialized()`: the format can only be set after
// AudioUnitInitialize, while the usual order (and Apple's AUHAL) allows it before.
// ponytail: also allows changes while running; Darling exposes no running flag to check from here.
static BOOL vine_auhal_format_writable(void *self, uint32_t scope, uint32_t element) { return 1; }
OSStatus AudioComponentInstanceNew(void *component, void **out) {
    static OSStatus (*orig)(void *, void **);
    static int patched;
    if (!orig) orig = vine_orig("/System/Library/Frameworks/AudioToolbox.framework/Versions/A/AudioToolbox.darling", "AudioComponentInstanceNew");
    OSStatus st = orig ? orig(component, out) : -1;
    if (!patched) {
        void *vf = vine_local_symbol("CoreAudio.component/Contents/MacOS/CoreAudio", "__ZN6AUBase11ValidFormatEjjRK24CAStreamBasicDescription");
        void *wf = vine_local_symbol("CoreAudio.component/Contents/MacOS/CoreAudio", "__ZN5AUHAL20StreamFormatWritableEjj");
        if (vf) { patched = 1; vine_detour_addr(vf, (void *)vine_auhal_valid_format); }
        if (wf) vine_detour_addr(wf, (void *)vine_auhal_format_writable);
    }
    return st;
}

// Failing AudioUnit calls are logged ("vine-audio: ..."): FMOD still reports FMOD_ERR_OUTPUT_INIT at
// System::init in-game, and only a game join exercises its exact sequence.
#define AT_FULL "/System/Library/Frameworks/AudioToolbox.framework/Versions/A/AudioToolbox.darling"
#define AU_TRACE(name, st, prop, scope, elem) \
    if (st) dprintf(2, "vine-audio: %s prop=%u scope=%u elem=%u -> %d\n", name, (unsigned)(prop), (unsigned)(scope), (unsigned)(elem), (int)(st))
// Render on Vine's own thread. Darling plays an output unit from its PulseAudio loop, a GCD queue;
// the unit's render callback (FMOD's whole mixer, in Roblox) ran on that thread, and a callback that
// takes real time breaks the loop: libdispatch traps in _dispatch_kevent_merge on a freed source
// (tests/darwin/audiounit_hal.m with 1 ms of work per callback crashes in seconds; without, 30 s
// pass). Same conclusion as MacOBlox (audio_hal.c), Vine's own implementation: the client's
// callback is replaced by a proxy that only copies from a ring; a thread with an 8 MiB stack calls
// the real callback 512 frames at a time to keep the ring ~1536 frames ahead (~35 ms at 44.1 kHz).
// Interleaved formats only (one buffer); others keep Darling's direct path.
typedef struct { uint32_t channels, bytes; void *data; } VineABuf;
typedef struct { uint32_t count; uint32_t pad; VineABuf b[1]; } VineABL;
typedef OSStatus (*VineRender)(void *, uint32_t *, const void *, uint32_t, uint32_t, VineABL *);
typedef struct { double sample; uint64_t host; double rate; uint64_t word; char smpte[24]; uint32_t flags, reserved; } VineTS;
#define RING (1u << 16)   /* bytes, power of two */
typedef struct {
    void *unit; VineRender cb; void *ref; uint32_t frame_bytes;
    volatile int running; void *thread; int fifo; VineASBD fmt;
    unsigned char ring[RING]; volatile uint32_t head, tail;   // head: written, tail: read (byte counts)
    double sample;
} VineProxy;
static VineProxy vine_proxies[4];
static uint32_t vine_frame_bytes[4]; static void *vine_fmt_unit[4]; static VineASBD vine_fmt[4];   // stream format per unit
uint64_t mach_absolute_time(void);
int pthread_create(void **, void *, void *(*)(void *), void *);
int pthread_join(void *, void **);
int pthread_attr_init(void *); int pthread_attr_setstacksize(void *, size_t);
struct vine_ts { long sec, nsec; };
int nanosleep(const struct vine_ts *, struct vine_ts *);
void *memset(void *, int, size_t);
static VineProxy *vine_proxy_for(void *unit, int create) {
    for (int i = 0; i < 4; i++) if (vine_proxies[i].unit == unit) return &vine_proxies[i];
    if (create) for (int i = 0; i < 4; i++) if (!vine_proxies[i].unit) { vine_proxies[i].unit = unit; return &vine_proxies[i]; }
    return 0;
}
static OSStatus vine_render_proxy(void *ref, uint32_t *flags, const void *ts, uint32_t bus, uint32_t frames, VineABL *io) {
    VineProxy *p = ref;
    static int logged;
    if (!logged++) dprintf(2, "vine-audio: proxy render frames=%u buffers=%u bytes=%u ch=%u frame_bytes=%u\n", frames, io ? io->count : 0, io && io->count ? io->b[0].bytes : 0, io && io->count ? io->b[0].channels : 0, p->frame_bytes);
    if (!io || io->count != 1) return 0;
    unsigned char *out = io->b[0].data;
    uint32_t want = frames * p->frame_bytes, have = __atomic_load_n(&p->head, __ATOMIC_ACQUIRE) - p->tail;
    // Darling's AUHAL passes twice the frame count its buffer holds (measured: 1536 frames, 6144 bytes
    // of stereo float); the buffer size is what real time consumes, so it decides.
    if (want > io->b[0].bytes) want = io->b[0].bytes - io->b[0].bytes % p->frame_bytes;
    uint32_t n = want < have ? want : have;
    for (uint32_t i = 0; i < n; i++) out[i] = p->ring[(p->tail + i) & (RING - 1)];
    __atomic_store_n(&p->tail, p->tail + n, __ATOMIC_RELEASE);
    if (n < want) memset(out + n, 0, want - n);   // underrun: silence
    io->b[0].bytes = want;
    return 0;
}
static void *vine_render_thread(void *arg) {
    VineProxy *p = arg;
    enum { BLOCK = 512, AHEAD = 1536 };
    static unsigned char buf[4][BLOCK * 64];
    unsigned char *tmp = buf[p - vine_proxies];
    while (p->running) {
        uint32_t fill = p->head - __atomic_load_n(&p->tail, __ATOMIC_ACQUIRE);
        if (fill >= AHEAD * p->frame_bytes || RING - fill < BLOCK * p->frame_bytes) {
            struct vine_ts t = {0, 2000000}; nanosleep(&t, 0); continue;
        }
        VineABL l = {1, 0, {{0, BLOCK * p->frame_bytes, tmp}}};
        l.b[0].channels = p->frame_bytes / 4;
        VineTS ts = {p->sample, mach_absolute_time(), 1.0, 0, {0}, 1 | 2 /* sample + host time valid */, 0};
        uint32_t fl = 0;
        if (p->cb(p->ref, &fl, &ts, 0, BLOCK, &l) != 0) memset(tmp, 0, BLOCK * p->frame_bytes);
        p->sample += BLOCK;
        for (uint32_t i = 0; i < BLOCK * p->frame_bytes; i++) p->ring[(p->head + i) & (RING - 1)] = tmp[i];
        __atomic_store_n(&p->head, p->head + BLOCK * p->frame_bytes, __ATOMIC_RELEASE);
    }
    return 0;
}

// Host playback (VINE_AUDIO_FIFO, set by tests/run-roblox-darling.sh). Even with the proxy, Darling's
// PulseAudio stream (a GCD loop) still crashes now and then in libdispatch's kevent code (~1 in 3
// 30 s soaks). As MacOBlox does (audio_hal.c: FIFO + pw-cat), the output unit then never starts
// Darling's stream: this thread renders 512-frame blocks and writes them to a FIFO that the
// launcher plays with pacat on the host. Blocking writes pace it at the sound card's rate. The
// format goes first to "<fifo>.fmt" ("float32le 48000 2"), which the launcher reads before pacat.
int open(const char *, int, ...); long write(int, const void *, size_t); int rename(const char *, const char *); int close(int);
int snprintf(char *, size_t, const char *, ...);
static const char *vine_pcm_format(const VineASBD *f) {   // pacat name, or 0 if unsupported
    if (f->formatID != 0x6c70636d || (f->flags & 32) || !f->channels || f->channels > 8) return 0;
    if ((f->flags & 1) && f->bits == 32) return "float32le";
    if (!(f->flags & 1) && f->bits == 16) return "s16le";
    if (!(f->flags & 1) && f->bits == 32) return "s32le";
    return 0;
}
static void *vine_fifo_thread(void *arg) {
    VineProxy *p = arg;
    const char *fifo = getenv("VINE_AUDIO_FIFO");
    char path[1024], tmp[1024], line[64];
    snprintf(path, sizeof path, "%s.fmt", fifo); snprintf(tmp, sizeof tmp, "%s.fmt.tmp", fifo);
    int n = snprintf(line, sizeof line, "%s %u %u\n", vine_pcm_format(&p->fmt), (unsigned)p->fmt.rate, p->fmt.channels);
    int fd = open(tmp, 0x601 /* O_WRONLY|O_CREAT|O_TRUNC */, 0600);
    if (fd >= 0) { write(fd, line, n); close(fd); rename(tmp, path); }
    p->fifo = open(fifo, 1 /* O_WRONLY */);   // waits for the launcher's player
    enum { BLOCK = 512 };
    static unsigned char buf[4][BLOCK * 64];
    unsigned char *b = buf[p - vine_proxies];
    while (p->running && p->fifo >= 0) {
        VineABL l = {1, 0, {{p->fmt.channels, BLOCK * p->frame_bytes, b}}};
        VineTS ts = {p->sample, mach_absolute_time(), 1.0, 0, {0}, 1 | 2, 0};
        uint32_t fl = 0;
        if (p->cb(p->ref, &fl, &ts, 0, BLOCK, &l) != 0) memset(b, 0, BLOCK * p->frame_bytes);
        p->sample += BLOCK;
        for (long off = 0, len = BLOCK * p->frame_bytes; off < len; ) {
            long w = write(p->fifo, b + off, len - off);
            if (w <= 0) { p->running = 0; break; }   // player gone
            off += w;
        }
    }
    if (p->fifo >= 0) close(p->fifo);
    p->fifo = -1;
    return 0;
}

OSStatus AudioUnitSetProperty(void *u, uint32_t prop, uint32_t scope, uint32_t elem, const void *data, uint32_t size) {
    static OSStatus (*o)(void *, uint32_t, uint32_t, uint32_t, const void *, uint32_t);
    if (!o) o = vine_orig(AT_FULL, "AudioUnitSetProperty");
    if (prop == 8 && scope == 1 && elem == 0 && data && size >= 40) {   // StreamFormat, input scope: what the callback renders
        const VineASBD *f = data;
        for (int i = 0; i < 4; i++) if (vine_fmt_unit[i] == u || !vine_fmt_unit[i]) {
            vine_fmt_unit[i] = u; vine_fmt[i] = *f;
            vine_frame_bytes[i] = (f->flags & 32 /* non-interleaved */) || f->bytesPerFrame > 64 ? 0 : f->bytesPerFrame;
            break;
        }
    }
    if (prop == 23 && scope == 1 && elem == 0 && data && size >= 16 && !getenv("VINE_DIRECT_RENDER")) {   // SetRenderCallback
        uint32_t fb = 0;
        for (int i = 0; i < 4; i++) if (vine_fmt_unit[i] == u) fb = vine_frame_bytes[i];
        VineProxy *p = fb ? vine_proxy_for(u, 1) : 0;
        if (p && !p->running) {
            const struct { VineRender cb; void *ref; } *rc = data;
            p->cb = rc->cb; p->ref = rc->ref; p->frame_bytes = fb; p->head = p->tail = 0; p->sample = 0; p->fifo = -1;
            for (int i = 0; i < 4; i++) if (vine_fmt_unit[i] == u) p->fmt = vine_fmt[i];
            struct { VineRender cb; void *ref; } mine = {vine_render_proxy, p};
            OSStatus st = o(u, prop, scope, elem, &mine, sizeof mine);
            if (st) p->unit = 0;
            AU_TRACE("AudioUnitSetProperty", st, prop, scope, elem);
            return st;
        }
    }
    OSStatus st = o(u, prop, scope, elem, data, size);
    // kAudioUnitProperty_AudioChannelLayout (19): Darling's AUBase answers InvalidProperty (-10879);
    // FMOD sets it (stereo) and treats the failure as FMOD_ERR_OUTPUT_INIT. The layout only
    // describes the channels; Darling's device plays plain stereo. ponytail: accepted, not stored.
    if (st == -10879 && prop == 19) return 0;
    AU_TRACE("AudioUnitSetProperty", st, prop, scope, elem);
    return st;
}
OSStatus AudioUnitGetProperty(void *u, uint32_t prop, uint32_t scope, uint32_t elem, void *data, uint32_t *size) {
    static OSStatus (*o)(void *, uint32_t, uint32_t, uint32_t, void *, uint32_t *);
    if (!o) o = vine_orig(AT_FULL, "AudioUnitGetProperty");
    OSStatus st = o(u, prop, scope, elem, data, size);
    AU_TRACE("AudioUnitGetProperty", st, prop, scope, elem);
    return st;
}
OSStatus AudioUnitInitialize(void *u) {
    static OSStatus (*o)(void *);
    if (!o) o = vine_orig(AT_FULL, "AudioUnitInitialize");
    OSStatus st = o(u);
    AU_TRACE("AudioUnitInitialize", st, 0, 0, 0);
    return st;
}
OSStatus AudioOutputUnitStart(void *u) {
    static OSStatus (*o)(void *);
    if (!o) o = vine_orig(AT_FULL, "AudioOutputUnitStart");
    VineProxy *p = vine_proxy_for(u, 0);
    if (p && p->cb && !p->running) {
        struct { long sig; char opaque[56]; } attr;
        pthread_attr_init(&attr); pthread_attr_setstacksize(&attr, 8u << 20);
        int host = getenv("VINE_AUDIO_FIFO") && vine_pcm_format(&p->fmt);
        p->running = 1;
        if (pthread_create(&p->thread, &attr, host ? vine_fifo_thread : vine_render_thread, p)) p->running = 0;
        else if (host) { dprintf(2, "vine-audio: host playback %s %u Hz %u ch\n", vine_pcm_format(&p->fmt), (unsigned)p->fmt.rate, p->fmt.channels); return 0; }
    }
    OSStatus st = o(u);
    AU_TRACE("AudioOutputUnitStart", st, 0, 0, 0);
    return st;
}

OSStatus AudioOutputUnitStop(void *u) {
    static OSStatus (*o)(void *);
    if (!o) o = vine_orig(AT_FULL, "AudioOutputUnitStop");
    VineProxy *p = vine_proxy_for(u, 0);
    if (p && p->running) {
        int host = p->fifo >= 0 || (getenv("VINE_AUDIO_FIFO") && vine_pcm_format(&p->fmt));
        p->running = 0; pthread_join(p->thread, 0);
        if (host) return 0;
    }
    return o(u);
}
OSStatus AudioComponentInstanceDispose(void *u) {
    static OSStatus (*o)(void *);
    if (!o) o = vine_orig("/System/Library/Frameworks/AudioToolbox.framework/Versions/A/AudioToolbox.darling", "AudioComponentInstanceDispose");
    VineProxy *p = vine_proxy_for(u, 0);
    if (p) { if (p->running) { p->running = 0; pthread_join(p->thread, 0); } p->unit = 0; p->cb = 0; }
    for (int i = 0; i < 4; i++) if (vine_fmt_unit[i] == u) vine_fmt_unit[i] = 0;
    return o ? o(u) : -50;
}

// A disposed AudioUnit must fail calls with badComponentInstance, as on macOS. Darling's
// AudioComponentManager::isOurInstance only tests the handle's high bit, so every AudioUnit call on
// a disposed unit (Roblox's voice code stops its unit after disposing it) dereferenced the NULL
// interface it found. Now an instance is ours only while the manager still has it; other handles
// take Darling's Component Manager path, which rejects them.
#define AT_IMG "AudioToolbox.framework/Versions/A/AudioToolbox.darling"
static void *(*at_manager)(void);
static void *(*at_interface)(void *self, void *instance);
static BOOL vine_is_our_instance(void *instance) {
    return ((uint32_t)(uintptr_t)instance & 0x80000000u) && at_interface(at_manager(), instance);
}
static BOOL vine_is_our_component(void *component) {   // Darling's overload for components forwarded to
    return ((uint32_t)(uintptr_t)component & 0x80000000u) != 0;   // the instance check: keep the bit test
}
__attribute__((constructor)) static void vine_audio_instances(void) {
    void *check = vine_local_symbol(AT_IMG, "__ZN21AudioComponentManager13isOurInstanceEP23ComponentInstanceRecord");
    at_manager = vine_local_symbol(AT_IMG, "__ZN21AudioComponentManager8instanceEv");
    at_interface = vine_local_symbol(AT_IMG, "__ZN21AudioComponentManager17instanceInterfaceEP23ComponentInstanceRecord");
    void *comp = vine_local_symbol(AT_IMG, "__ZN21AudioComponentManager13isOurInstanceEP20OpaqueAudioComponent");
    if (!check || !comp || !at_manager || !at_interface) return;
    vine_detour_addr(comp, (void *)vine_is_our_component);
    vine_detour_addr(check, (void *)vine_is_our_instance);
}
#endif

#ifdef FW_AppKit
// +[NSEvent addLocalMonitorForEventsMatchingMask:handler:] / +removeMonitor: are unimplemented
// stubs in Darling; Roblox installs local monitors at start-up. macOS semantics: before an event is
// dispatched by -[NSApplication sendEvent:], every monitor whose mask includes the event's type gets
// it; the handler returns the event to dispatch (possibly a different one) or nil to swallow it.
void *_Block_copy(const void *);
void _Block_release(const void *);
typedef id (^VineMonitorBlock)(id);
static struct { unsigned long long mask; VineMonitorBlock handler; id token; } vine_monitors[32];
static int vine_monitor_count;
static id vine_add_monitor(id self, SEL _cmd, unsigned long long mask, VineMonitorBlock handler) {
    if (!handler || vine_monitor_count == 32) return 0;
    id token = [[NSObject alloc] init];
    vine_monitors[vine_monitor_count].mask = mask;
    vine_monitors[vine_monitor_count].handler = (VineMonitorBlock)_Block_copy(handler);
    vine_monitors[vine_monitor_count].token = token;
    vine_monitor_count++;
    return token;
}
static void vine_remove_monitor(id self, SEL _cmd, id token) {
    for (int i = 0; i < vine_monitor_count; i++)
        if (vine_monitors[i].token == token) {
            _Block_release(vine_monitors[i].handler);
            vine_monitors[i] = vine_monitors[--vine_monitor_count];
            return;
        }
}
static void (*orig_app_sendEvent)(id, SEL, id);
static void vine_app_sendEvent(id self, SEL _cmd, id event) {
    for (int i = 0; event && i < vine_monitor_count; i++) {
        unsigned long type = [event type];
        if (type < 64 && (vine_monitors[i].mask & (1ULL << type)))
            event = vine_monitors[i].handler(event);
    }
    if (event) orig_app_sendEvent(self, _cmd, event);
}
// Mouse motion coalescing, as macOS AppKit does. Darling posts one NSEvent per X motion event, so a
// 1000 Hz mouse sends ~1000 events/s through Roblox's input handling; the game falls behind and
// freezes while the mouse moves (finding credited to MacOBlox: 180-340 events late). A moved or
// dragged event that would queue behind another of the same type, window and modifiers replaces it:
// newest position, deltas summed. Nothing else changes order.
@interface NSObject (VineQueue) - (id)lastObject; - (unsigned long)count; - (void)replaceObjectAtIndex:(unsigned long)i withObject:(id)o;
+ (id)mouseEventWithType:(unsigned long)t location:(NSPoint)l modifierFlags:(unsigned long)f window:(id)w clickCount:(long)c deltaX:(double)dx deltaY:(double)dy; @end
static double (*orig_deltaY)(id, SEL);
static void (*orig_postEvent)(id, SEL, id, BOOL);
static long vine_queue_ivar = -1;
static void vine_postEvent(id self, SEL _cmd, id ev, BOOL atStart) {
    unsigned long t = [ev type];
    if (vine_lock.on && (t == 5 || t == 6 || t == 7 || t == 27)) {
        NSPoint l = [ev locationInWindow];
        // (y stays in Darling's convention here; -deltaY flips it for every motion event, below)
        static double sens = -1;
        if (sens < 0) { const char *v = getenv("VINE_MOUSE_SENSITIVITY"); sens = v ? atof(v) : 1; if (sens <= 0 || sens > 20) sens = 1; }
        // The first event the X server generated after our warp measures from the warp's destination,
        // even when it merges the warp with real motion; earlier ones from the previous event.
        if (vine_warp_pending && (long)(vine_cur_serial - vine_warp_serial) >= 0) {   // where the warp really left it
            vine_lock.prev = (NSPoint){vine_lock.center.x + vine_warp_off_x, vine_lock.center.y - vine_warp_off_y};
            vine_warp_pending = 0;
        }
        double dx = (l.x - vine_lock.prev.x) * sens, dy = (l.y - vine_lock.prev.y) * sens;
        vine_lock.prev = l;
        id fixed = [objc_getClass("NSEvent") mouseEventWithType:t location:l modifierFlags:[ev modifierFlags] window:[ev window]
                                                   clickCount:1 deltaX:dx deltaY:dy];
        if (fixed) ev = fixed;
        double ox = l.x - vine_lock.center.x, oy = l.y - vine_lock.center.y;
        if (!vine_warp_pending && ox * ox + oy * oy > vine_lock.radius * vine_lock.radius) vine_lock_center(self);
    }
    if (!atStart && vine_queue_ivar >= 0 && (t == 5 || t == 6 || t == 7 || t == 27)) {   // moved, dragged
        id q = *(id *)((char *)self + vine_queue_ivar), last = [q lastObject];
        if (last && [last type] == t && [last window] == [ev window] && [last modifierFlags] == [ev modifierFlags]) {
            id merged = [objc_getClass("NSEvent") mouseEventWithType:t location:[ev locationInWindow] modifierFlags:[ev modifierFlags]
                                                               window:[ev window] clickCount:1
                                                               deltaX:[last deltaX] + [ev deltaX]
                                                               deltaY:(orig_deltaY ? orig_deltaY(last, sel_registerName("deltaY")) + orig_deltaY(ev, sel_registerName("deltaY")) : [last deltaY] + [ev deltaY])];
            if (merged) { [q replaceObjectAtIndex:[q count] - 1 withObject:merged]; return; }
        }
    }
    orig_postEvent(self, _cmd, ev, atStart);
}

// Mouse motion deltaY: macOS reports y growing downwards; Darling computes it in its y-up window
// coordinates, so vertical camera movement was inverted (MacOBlox flips it the same way).
static double vine_deltaY(id self, SEL _cmd) {
    unsigned long t = [self type];
    double d = orig_deltaY(self, _cmd);
    return t == 5 || t == 6 || t == 7 || t == 27 ? -d : d;
}
// NSOpenGLPixelFormat attributes, walked with their values (see vine_gl_mark_profile in the
// OpenGL wrapper): the core profile request reaches CGLCreateContext.
static id (*orig_pf_init)(id, SEL, const uint32_t *);
static id vine_pf_init(id self, SEL _cmd, const uint32_t *a) {
    id r = orig_pf_init(self, _cmd, a);
    int profile = 0;
    for (int i = 0; a && a[i] && i < 128; ) {
        uint32_t k = a[i];
        if (k == 99) { profile = a[i + 1]; break; }
        // attributes followed by a value (NSOpenGLPFA...): AuxBuffers, ColorSize, AlphaSize, DepthSize,
        // StencilSize, AccumSize, SampleBuffers, Samples, RendererID, ScreenMask,
        // VirtualScreenCount, OpenGLProfile
        int arg = k == 7 || k == 8 || k == 11 || k == 12 || k == 13 || k == 14 || k == 55 || k == 56 ||
                  k == 70 || k == 84 || k == 128 || k == 99;
        i += arg ? 2 : 1;
    }
    Ivar iv = r ? class_getInstanceVariable(object_getClass(r), "_cglPixelFormat") : 0;
    static void (*mark)(void *, int);   // in Vine's OpenGL wrapper (resolved at run time)
    if (!mark) mark = (void (*)(void *, int))dlsym((void *)-2 /* RTLD_DEFAULT */, "vine_gl_mark_profile");
    if (profile && iv && mark) mark(*(void **)((char *)r + ivar_getOffset(iv)), profile);
    return r;
}
__attribute__((constructor)) static void vine_event_monitors(void) {
    {
        Method m = class_getInstanceMethod(objc_getClass("NSOpenGLPixelFormat"), sel_registerName("initWithAttributes:"));
        if (m) orig_pf_init = (id (*)(id, SEL, const uint32_t *))method_setImplementation(m, (IMP)vine_pf_init);
    }
    {
        Class mc = objc_getClass("NSEvent_mouse");   // Darling's mouse events (may override NSEvent's)
        Method dm = class_getInstanceMethod(mc ? mc : objc_getClass("NSEvent"), sel_registerName("deltaY"));
        if (dm) orig_deltaY = (double (*)(id, SEL))method_setImplementation(dm, (IMP)vine_deltaY);
    }
    {
        Class d = objc_getClass("NSDisplay");
        Ivar iv = d ? class_getInstanceVariable(d, "_eventQueue") : 0;
        Method pm = d ? class_getInstanceMethod(d, sel_registerName("postEvent:atStart:")) : 0;
        if (iv && pm) {
            vine_queue_ivar = ivar_getOffset(iv);
            orig_postEvent = (void (*)(id, SEL, id, BOOL))method_setImplementation(pm, (IMP)vine_postEvent);
        }
    }
    Class meta = object_getClass((id)objc_getClass("NSEvent"));
    Method m;
    if ((m = class_getInstanceMethod(meta, sel_registerName("addLocalMonitorForEventsMatchingMask:handler:"))))
        method_setImplementation(m, (IMP)vine_add_monitor);
    if ((m = class_getInstanceMethod(meta, sel_registerName("removeMonitor:"))))
        method_setImplementation(m, (IMP)vine_remove_monitor);
    if ((m = class_getInstanceMethod(objc_getClass("NSApplication"), sel_registerName("sendEvent:"))))
        orig_app_sendEvent = (void (*)(id, SEL, id))method_setImplementation(m, (IMP)vine_app_sendEvent);
}
#endif

#ifdef FW_CFNetwork
// Persistent cookies. Darling's NSHTTPCookieStorage is an in-memory array, so Roblox's login cookie
// was lost at every exit (macOS persists cookies that have an expiry). Persistent cookies (Expires in
// the future) are written to ~/Library/Cookies/Vine-Cookies.plist (0600, atomic rename) whenever the
// shared store changes, and loaded into it the first time it is used. The file holds the user's
// session: treat it like a browser profile.
@interface NSObject (VineCookies)
+ (id)sharedHTTPCookieStorage; + (id)cookieWithProperties:(id)p; + (id)date; + (id)array; + (id)dictionary;
- (id)cookies; - (id)properties; - (id)objectForKey:(id)k; - (void)setObject:(id)o forKey:(id)k; - (void)addObject:(id)o;
- (id)allKeys; - (unsigned long)count; - (id)objectAtIndex:(unsigned long)i; - (long)compare:(id)o;
- (BOOL)isKindOfClass:(Class)c; - (id)absoluteString; - (const char *)UTF8String; - (BOOL)boolValue;
@end
typedef const void *CFPropertyListRef; typedef const struct __CFData *CFDataRef;
CFDataRef CFPropertyListCreateData(CFAllocatorRef, CFPropertyListRef, long, unsigned long, void **);
CFPropertyListRef CFPropertyListCreateWithData(CFAllocatorRef, CFDataRef, unsigned long, long *, void **);
CFDataRef CFDataCreate(CFAllocatorRef, const unsigned char *, CFIndex);
const unsigned char *CFDataGetBytePtr(CFDataRef); CFIndex CFDataGetLength(CFDataRef);
int open(const char *, int, ...); long write(int, const void *, size_t); long read(int, void *, size_t);
int close(int); int rename(const char *, const char *); int mkdir(const char *, unsigned short);
char *strcpy(char *, const char *); char *strcat(char *, const char *);
#define O_RDONLY 0
#define O_WRONLY 1
#define O_CREAT 0x200
#define O_TRUNC 0x400
static int vine_cookie_loading;
static const char *vine_cookie_file(const char *suffix) {
    static char path[1024];
    const char *home = getenv("HOME");
    if (!home || strlen(home) > 900) return 0;
    strcpy(path, home); strcat(path, "/Library"); mkdir(path, 0700);
    strcat(path, "/Cookies"); mkdir(path, 0700);
    strcat(path, "/Vine-Cookies.plist"); strcat(path, suffix);
    return path;
}
static BOOL vine_cookie_persistent(id props) {
    id exp = [props objectForKey:@"Expires"];
    if ([exp isKindOfClass:objc_getClass("NSDate")]) return [exp compare:[objc_getClass("NSDate") date]] > 0;
    if ([exp isKindOfClass:objc_getClass("NSString")]) {
        const char *s = [exp UTF8String];
        double t = s ? vine_http_date(s, s + strlen(s)) : 0;
        return t > CFAbsoluteTimeGetCurrent();
    }
    return 0;
}
static void vine_cookies_save(id storage) {
    if (vine_cookie_loading) return;
    id cookies = [storage cookies], out = [objc_getClass("NSMutableArray") array];
    for (unsigned long i = 0; i < [cookies count]; i++) {
        id props = [[cookies objectAtIndex:i] properties];
        if (!vine_cookie_persistent(props)) continue;
        id clean = [objc_getClass("NSMutableDictionary") dictionary], keys = [props allKeys];
        for (unsigned long k = 0; k < [keys count]; k++) {   // plist-safe values only
            id key = [keys objectAtIndex:k], v = [props objectForKey:key];
            if ([v isKindOfClass:objc_getClass("NSURL")]) v = [v absoluteString];
            if ([v isKindOfClass:objc_getClass("NSString")] || [v isKindOfClass:objc_getClass("NSDate")] ||
                [v isKindOfClass:objc_getClass("NSNumber")])
                [clean setObject:v forKey:key];
        }
        [out addObject:clean];
    }
    CFDataRef data = CFPropertyListCreateData(0, (CFPropertyListRef)out, 100 /* XML */, 0, 0);
    const char *tmp = vine_cookie_file(".tmp");
    if (!data || !tmp) { if (data) CFRelease(data); return; }
    char tmpc[1024]; strcpy(tmpc, tmp);
    int fd = open(tmpc, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (fd >= 0) {
        long n = write(fd, CFDataGetBytePtr(data), CFDataGetLength(data));
        close(fd);
        if (n == CFDataGetLength(data)) rename(tmpc, vine_cookie_file(""));
    }
    CFRelease(data);
}
static void (*orig_setCookie)(id, SEL, id), (*orig_deleteCookie)(id, SEL, id), (*orig_setCookiesForURL)(id, SEL, id, id, id);
static id (*orig_sharedStorage)(id, SEL);
// Trace of cookie traffic in the run log: names and domains only, never values.
static void vine_cookie_trace(const char *op, id c) {
    id props = [c properties];
    dprintf(2, "vine-cookie: %s %s domain=%s persistent=%d\n", op, [[c name] UTF8String],
            [[props objectForKey:@"Domain"] UTF8String], (int)vine_cookie_persistent(props));
}
static void vine_setCookie(id self, SEL _cmd, id c) { vine_cookie_trace("set", c); orig_setCookie(self, _cmd, c); vine_cookies_save(self); }
static void vine_deleteCookie(id self, SEL _cmd, id c) { vine_cookie_trace("delete", c); orig_deleteCookie(self, _cmd, c); vine_cookies_save(self); }
// Darling's -setCookies:forURL:mainDocumentURL: is an empty stub, and it is how Roblox stores the
// sign-in cookie (.ROBLOSECURITY): it was dropped, so the login lived only in Roblox's own jar for
// one session. Store each cookie as -setCookie: does (cookies parsed from a response already carry
// their domain).
static void vine_setCookiesForURL(id self, SEL _cmd, id cs, id u, id m) {
    for (unsigned long i = 0; i < [cs count]; i++) {
        vine_cookie_trace("set-for-url", [cs objectAtIndex:i]);
        orig_setCookie(self, sel_registerName("setCookie:"), [cs objectAtIndex:i]);
    }
    vine_cookies_save(self);
}
static id (*orig_cookiesForURL)(id, SEL, id);
// Darling's -cookiesForURL: returns every stored cookie, whatever the URL: Roblox's login cookie
// went out with requests to any host, and a caller deleting "its" cookies deleted all of them.
// Keep only cookies that match as RFC 6265 says: host equals or is a subdomain of the cookie's
// domain, path prefix, Secure only over https, not expired.
int strcasecmp(const char *, const char *); int strncmp(const char *, const char *, size_t);
@interface NSObject (VineCookieURL) - (id)host; - (id)path; - (id)scheme; - (BOOL)boolValue; - (void)addObject:(id)o; @end
static int vine_cookie_matches(id c, id url) {
    id props = [c properties];
    const char *host = [[url host] UTF8String], *dom = [[props objectForKey:@"Domain"] UTF8String];
    const char *path = [[url path] UTF8String], *cpath = [[props objectForKey:@"Path"] UTF8String];
    if (!host || !dom) return 0;
    if (*dom == '.') dom++;
    size_t hl = strlen(host), dl = strlen(dom);
    if (hl < dl || strcasecmp(host + hl - dl, dom) || (hl > dl && host[hl - dl - 1] != '.')) return 0;
    if (cpath && *cpath) {
        size_t pl = strlen(cpath);
        if (!path || !*path) path = "/";
        if (strncmp(path, cpath, pl) || (path[pl] && cpath[pl - 1] != '/' && path[pl] != '/')) return 0;
    }
    id secure = [props objectForKey:@"Secure"];
    BOOL sec = [secure isKindOfClass:objc_getClass("NSString")] ? (strcasecmp([secure UTF8String], "TRUE") == 0 || !strcmp([secure UTF8String], "1")) : [secure boolValue];
    if (sec && strcasecmp([[url scheme] UTF8String] ?: "", "https")) return 0;
    id exp = [props objectForKey:@"Expires"];
    if (exp && !vine_cookie_persistent(props) && ([exp isKindOfClass:objc_getClass("NSDate")] || [exp isKindOfClass:objc_getClass("NSString")])) return 0;
    return 1;
}
static id vine_cookiesForURL(id self, SEL _cmd, id url) {
    id all = orig_cookiesForURL(self, _cmd, url), r = [objc_getClass("NSMutableArray") array];
    for (unsigned long i = 0; i < [all count]; i++)
        if (vine_cookie_matches([all objectAtIndex:i], url)) [r addObject:[all objectAtIndex:i]];
    dprintf(2, "vine-cookie: get %s -> %lu cookie(s), store has %lu\n", [[url absoluteString] UTF8String],
            (unsigned long)[r count], (unsigned long)[[self cookies] count]);
    return r;
}
static id vine_sharedStorage(id self, SEL _cmd) {
    id storage = orig_sharedStorage(self, _cmd);
    static int loaded;
    if (loaded++ || !storage) return storage;
    const char *path = vine_cookie_file("");
    int fd = path ? open(path, O_RDONLY) : -1;
    if (fd < 0) return storage;
    static unsigned char buf[1 << 20];   // ponytail: cookie file up to 1 MiB
    long n = read(fd, buf, sizeof buf);
    close(fd);
    CFDataRef data = n > 0 ? CFDataCreate(0, buf, n) : 0;
    id list = data ? (id)CFPropertyListCreateWithData(0, data, 0, 0, 0) : 0;
    if (data) CFRelease(data);
    vine_cookie_loading = 1;
    for (unsigned long i = 0; list && i < [list count]; i++) {
        id props = [[list objectAtIndex:i] mutableCopy];
        if (!vine_cookie_persistent(props)) continue;
        for (int b = 0; b < 2; b++) {   // Darling reads these with CFBooleanGetValue: must be booleans
            id key = b ? @"HTTPOnly" : @"Secure", v = [props objectForKey:key];
            BOOL on = [v isKindOfClass:objc_getClass("NSString")] ? (strcmp([v UTF8String], "TRUE") == 0 || strcmp([v UTF8String], "1") == 0)
                    : (v ? [v boolValue] : 0);
            [props setObject:(id)(on ? kCFBooleanTrue : kCFBooleanFalse) forKey:key];
        }
        id cookie = [objc_getClass("NSHTTPCookie") cookieWithProperties:props];
        if (cookie) orig_setCookie(storage, sel_registerName("setCookie:"), cookie);
    }
    vine_cookie_loading = 0;
    dprintf(2, "vine-cookie: restored %lu saved cookie(s)\n", list ? (unsigned long)[list count] : 0ul);
    if (list) CFRelease((CFTypeRef)list);
    return storage;
}
@interface NSObject (VineMutableCopy) - (id)mutableCopy; @end
int strcmp(const char *, const char *);
__attribute__((constructor)) static void vine_cookie_persistence(void) {
    Class c = objc_getClass("NSHTTPCookieStorage");
    Method m;
    if (!c) return;
    if ((m = class_getInstanceMethod(object_getClass((id)c), sel_registerName("sharedHTTPCookieStorage"))))
        orig_sharedStorage = (id (*)(id, SEL))method_setImplementation(m, (IMP)vine_sharedStorage);
    if ((m = class_getInstanceMethod(c, sel_registerName("setCookie:"))))
        orig_setCookie = (void (*)(id, SEL, id))method_setImplementation(m, (IMP)vine_setCookie);
    if ((m = class_getInstanceMethod(c, sel_registerName("deleteCookie:"))))
        orig_deleteCookie = (void (*)(id, SEL, id))method_setImplementation(m, (IMP)vine_deleteCookie);
    if ((m = class_getInstanceMethod(c, sel_registerName("setCookies:forURL:mainDocumentURL:"))))
        orig_setCookiesForURL = (void (*)(id, SEL, id, id, id))method_setImplementation(m, (IMP)vine_setCookiesForURL);
    if ((m = class_getInstanceMethod(c, sel_registerName("cookiesForURL:"))))
        orig_cookiesForURL = (id (*)(id, SEL, id))method_setImplementation(m, (IMP)vine_cookiesForURL);
}
#endif

#ifdef FW_Security
// Keychain generic passwords that survive a restart (finding credited to MacOBlox). Roblox keeps its
// login as a generic password item (kSecClassGenericPassword, keyed by kSecAttrAccount). Darling's
// SecItem* wait for a security daemon that does not run here, so the login was never stored and every
// launch started signed out. Generic password items with an account live in
// ~/Library/Keychains/Vine-GenericPasswords.plist (directory 0700, file 0600, atomic rewrite): an
// array of {svce, acct, v_Data}. Other item classes still go to Darling.
// ponytail: whole-file rewrite per change; fine for the handful of items an app keeps.
extern CFStringRef kSecClass, kSecClassGenericPassword, kSecAttrService, kSecAttrAccount, kSecValueData,
    kSecReturnData, kSecReturnAttributes;
int mkdir(const char *, unsigned short); int chmod(const char *, unsigned short);
void *vine_orig(const char *image, const char *sym);
#define SEC_IMG "/System/Library/Frameworks/Security.framework/Versions/A/Security.darling"
@interface NSObject (VineKeychain)
+ (id)arrayWithContentsOfFile:(id)p; + (id)stringWithFormat:(id)f, ...; + (id)data; + (id)dictionary;
- (BOOL)writeToFile:(id)p atomically:(BOOL)a; - (id)mutableCopy; - (BOOL)boolValue;
- (void)removeObjectAtIndex:(unsigned long)i; - (void)addObject:(id)o; - (void)setObject:(id)o forKey:(id)k;
- (void)removeObjectForKey:(id)k; - (id)retain; - (const char *)UTF8String; - (unsigned long)count;
- (id)objectAtIndex:(unsigned long)i; - (id)objectForKey:(id)k; - (BOOL)isEqual:(id)o;
@end

static id vine_kc_file(void) {
    const char *home = getenv("HOME");
    if (!home) return 0;
    id dir = [objc_getClass("NSString") stringWithFormat:@"%s/Library/Keychains", home];
    mkdir([dir UTF8String], 0700);
    return [objc_getClass("NSString") stringWithFormat:@"%@/Vine-GenericPasswords.plist", dir];
}
static BOOL vine_kc_ours(id q) {   // generic password with an account: handled here
    return q && [[q objectForKey:(id)kSecClass] isEqual:(id)kSecClassGenericPassword] && [q objectForKey:(id)kSecAttrAccount];
}
static BOOL vine_kc_match(id item, id q) {
    id keys[] = {(id)kSecAttrAccount, (id)kSecAttrService};
    for (int i = 0; i < 2; i++) {
        id want = [q objectForKey:keys[i]];
        if (want && ![want isEqual:[item objectForKey:keys[i]]]) return 0;
    }
    return 1;
}
static id vine_kc_load(void) {
    id list = [objc_getClass("NSMutableArray") arrayWithContentsOfFile:vine_kc_file()];
    return list ? list : [objc_getClass("NSMutableArray") array];
}
static int vine_kc_save(id list) {
    id path = vine_kc_file();
    if (!path || ![list writeToFile:path atomically:1]) return -36;   // errSecIO
    chmod([path UTF8String], 0600);
    return 0;
}

int SecItemAdd(id attrs, id *result) {
    static int (*orig)(id, id *);
    if (!vine_kc_ours(attrs)) {
        if (!orig) orig = (int (*)(id, id *))vine_orig(SEC_IMG, "SecItemAdd");
        return orig ? orig(attrs, result) : -4;   // errSecUnimplemented
    }
    @synchronized (objc_getClass("NSObject")) {
        id list = vine_kc_load();
        for (unsigned long i = 0; i < [list count]; i++)
            if (vine_kc_match([list objectAtIndex:i], attrs)) return -25299;   // errSecDuplicateItem
        id item = [objc_getClass("NSMutableDictionary") dictionary], v;
        [item setObject:[attrs objectForKey:(id)kSecAttrAccount] forKey:(id)kSecAttrAccount];
        if ((v = [attrs objectForKey:(id)kSecAttrService])) [item setObject:v forKey:(id)kSecAttrService];
        v = [attrs objectForKey:(id)kSecValueData];
        [item setObject:v ? v : [objc_getClass("NSData") data] forKey:(id)kSecValueData];
        [list addObject:item];
        if (result) *result = 0;
        return vine_kc_save(list);
    }
}

int SecItemCopyMatching(id q, id *result) {
    static int (*orig)(id, id *);
    if (!vine_kc_ours(q)) {
        if (!orig) orig = (int (*)(id, id *))vine_orig(SEC_IMG, "SecItemCopyMatching");
        return orig ? orig(q, result) : -4;
    }
    @synchronized (objc_getClass("NSObject")) {
        id list = vine_kc_load();
        for (unsigned long i = 0; i < [list count]; i++) {
            id item = [list objectAtIndex:i];
            if (!vine_kc_match(item, q)) continue;
            if (result) {
                BOOL data = [[q objectForKey:(id)kSecReturnData] boolValue], attrs = [[q objectForKey:(id)kSecReturnAttributes] boolValue];
                id out = 0;
                if (attrs) {
                    out = [item mutableCopy];   // +1, as SecItemCopyMatching returns
                    [out setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
                    if (!data) [out removeObjectForKey:(id)kSecValueData];
                } else if (data) out = [[item objectForKey:(id)kSecValueData] retain];
                *result = out;
            }
            return 0;
        }
        return -25300;   // errSecItemNotFound
    }
}

int SecItemDelete(id q) {
    static int (*orig)(id);
    if (!vine_kc_ours(q)) {
        if (!orig) orig = (int (*)(id))vine_orig(SEC_IMG, "SecItemDelete");
        return orig ? orig(q) : -4;
    }
    @synchronized (objc_getClass("NSObject")) {
        id list = vine_kc_load();
        unsigned long before = [list count];
        for (unsigned long i = before; i-- > 0; )
            if (vine_kc_match([list objectAtIndex:i], q)) [list removeObjectAtIndex:i];
        return [list count] == before ? -25300 : vine_kc_save(list);
    }
}
#endif
