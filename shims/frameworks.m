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
- (long)buttonNumber; - (long)clickCount; - (double)timestamp; - (long)windowNumber; @end
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
int CGAssociateMouseAndMouseCursorPosition(unsigned int connected) {
    static int state = 1;   // associated
    connected = connected != 0;
    if ((int)connected == state) return 0;
    state = connected;
    id display = [objc_getClass("NSDisplay") currentDisplay];
    if (!display) return 1001;   // kCGErrorInvalidConnection
    [display grabMouse:!connected];
    return 0;
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
