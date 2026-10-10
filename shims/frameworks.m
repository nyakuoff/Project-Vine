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
static void vine_warp_mouse(id self, SEL _cmd, struct { double x, y; } p) {
    void *dpy = *(void **)((char *)self + x_display_ivar);
    x_warp(dpy, 0, x_root(dpy), 0, 0, 0, 0, (int)p.x, (int)p.y);
    x_sync(dpy, 0);
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
    if (!iv || !m || !x_warp || !x_sync || !x_root) return;
    x_display_ivar = ivar_getOffset(iv);
    method_setImplementation(m, (IMP)vine_warp_mouse);
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
OSStatus AudioUnitSetProperty(void *u, uint32_t prop, uint32_t scope, uint32_t elem, const void *data, uint32_t size) {
    static OSStatus (*o)(void *, uint32_t, uint32_t, uint32_t, const void *, uint32_t);
    if (!o) o = vine_orig(AT_FULL, "AudioUnitSetProperty");
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
    OSStatus st = o(u);
    AU_TRACE("AudioOutputUnitStart", st, 0, 0, 0);
    return st;
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
static void (*orig_postEvent)(id, SEL, id, BOOL);
static long vine_queue_ivar = -1;
static void vine_postEvent(id self, SEL _cmd, id ev, BOOL atStart) {
    unsigned long t = [ev type];
    if (!atStart && vine_queue_ivar >= 0 && (t == 5 || t == 6 || t == 7 || t == 27)) {   // moved, dragged
        id q = *(id *)((char *)self + vine_queue_ivar), last = [q lastObject];
        if (last && [last type] == t && [last window] == [ev window] && [last modifierFlags] == [ev modifierFlags]) {
            id merged = [objc_getClass("NSEvent") mouseEventWithType:t location:[ev locationInWindow] modifierFlags:[ev modifierFlags]
                                                               window:[ev window] clickCount:1
                                                               deltaX:[last deltaX] + [ev deltaX] deltaY:[last deltaY] + [ev deltaY]];
            if (merged) { [q replaceObjectAtIndex:[q count] - 1 withObject:merged]; return; }
        }
    }
    orig_postEvent(self, _cmd, ev, atStart);
}

__attribute__((constructor)) static void vine_event_monitors(void) {
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
