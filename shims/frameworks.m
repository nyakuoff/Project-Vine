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

// One cookie "name=value; Domain=x; Path=/; Secure; HttpOnly" -> appended cookie object.
static void vine_cookie(const char *s, const char *e, CFURLRef url, CFMutableArrayRef out) {
    CFStringRef name = 0, value = 0, domain = 0, path = 0;
    BOOL secure = 0, httponly = 0;
    for (const char *t = s; t < e; ) {
        const char *te = t; while (te < e && *te != ';') te++;
        const char *eq = t; while (eq < te && *eq != '=') eq++;
        const char *ks = t, *ke = eq, *vs = eq < te ? eq + 1 : te, *ve = te;
        vine_trim(&ks, &ke); vine_trim(&vs, &ve);
        if (!name) { if (eq < te && ke > ks) { name = vine_str(ks, ke); value = vine_str(vs, ve); } else break; }
        else if (vine_ieq(ks, ke - ks, "domain") && ve > vs) { if (domain) CFRelease(domain); domain = vine_str(vs, ve); }
        else if (vine_ieq(ks, ke - ks, "path") && ve > vs) { if (path) CFRelease(path); path = vine_str(vs, ve); }
        else if (vine_ieq(ks, ke - ks, "secure")) secure = 1;
        else if (vine_ieq(ks, ke - ks, "httponly")) httponly = 1;
        t = te < e ? te + 1 : e;
    }
    if (!domain && url) domain = CFURLCopyHostName(url);
    if (name && domain) {
        const void *k[] = {CFSTR("Name"), CFSTR("Value"), CFSTR("Domain"), CFSTR("Path"), CFSTR("Secure"), CFSTR("HTTPOnly"), CFSTR("OriginURL")};
        const void *v[] = {name, value, domain, path ? path : CFSTR("/"), secure ? kCFBooleanTrue : kCFBooleanFalse,
                           httponly ? kCFBooleanTrue : kCFBooleanFalse, url};
        CFDictionaryRef props = CFDictionaryCreate(0, k, v, url ? 7 : 6, kCFTypeDictionaryKeyCallBacks, kCFTypeDictionaryValueCallBacks);
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
@implementation NSDisplay (VineSharedDisplay)
+ (id)currentDisplay {
    if ([NSThread isMainThread]) return vine_main_display = NSThreadSharedInstance(@"NSDisplay");
    return vine_main_display ? vine_main_display : NSThreadSharedInstance(@"NSDisplay");
}
@end
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
