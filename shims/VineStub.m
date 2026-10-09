// libvinestub.dylib
//  - VineStub: base class for stubbed Apple classes; unknown selectors return nil/0 (logged).
//  - Lenient mode (VINE_OBJC_LENIENT=1): any object's unrecognized selector is forwarded to a
//    VineStub instead of raising NSInvalidArgumentException. Bring-up aid: it logs every gap in
//    one run; zero is not always a correct answer, so it is opt-in.
#include "vine.h"

char *getenv(const char *);

// Returns 0 in every return register (rax, rdx, xmm0, xmm1) so id/int/float/small-struct callers all see zero.
__attribute__((naked)) static void vine_zero(void) {
    __asm__("xorl %eax, %eax\n xorl %edx, %edx\n xorps %xmm0, %xmm0\n xorps %xmm1, %xmm1\n ret");
}

static BOOL vine_resolve(Class target, id self, SEL sel, const char *kind) {
    dprintf(2, "vine-stub: %s[%s %s] -> 0\n", kind, class_getName((Class)self), sel_getName(sel));
    return class_addMethod(target, sel, (IMP)vine_zero, "@@:");
}

@implementation VineStub
+ (BOOL)resolveInstanceMethod:(SEL)sel { return vine_resolve((Class)self, self, sel, "-"); }
+ (BOOL)resolveClassMethod:(SEL)sel { return vine_resolve(object_getClass(self), self, sel, "+"); }
@end

@interface VineSink : VineStub @end
@implementation VineSink @end

static int lenient = -1;
static id vine_forward(id self, SEL sel, const char *kind, Class cls) {
    if (lenient < 0) { const char *e = getenv("VINE_OBJC_LENIENT"); lenient = e && *e == '1'; }
    if (!lenient) return 0;
    dprintf(2, "vine-objc: %s[%s %s] unimplemented\n", kind, class_getName(cls), sel_getName(sel));
    static id sink;
    if (!sink) sink = [[VineSink alloc] init];
    return sink;
}

@implementation NSObject (VineLenient)
- (id)forwardingTargetForSelector:(SEL)sel { return vine_forward(self, sel, "-", object_getClass(self)); }
+ (id)forwardingTargetForSelector:(SEL)sel { return vine_forward(self, sel, "+", (Class)self); }
@end

// ---- vine_detour: redirect a function inside a Darling library to a Vine replacement ----------
// Wrappers only catch calls *into* a library; calls a library makes to itself (e.g. CFNetwork's
// URL loader -> its own cookie parser) need the original's entry point patched with a jump.
void *dlopen(const char *, int);
void *dlsym(void *, const char *);
int mprotect(void *, size_t, int);
#define RTLD_LAZY 1
#define RTLD_NOLOAD 0x10

int vine_detour(const char *image, const char *sym, void *repl) {
    void *h = dlopen(image, RTLD_LAZY | RTLD_NOLOAD);
    unsigned char *f = h ? dlsym(h, sym) : 0;
    if (!f || (void *)f == repl) { dprintf(2, "vine-detour: %s not found in %s\n", sym, image); return -1; }
    uintptr_t page = (uintptr_t)f & ~(uintptr_t)4095;
    if (mprotect((void *)page, 8192, 7 /* RWX */)) { dprintf(2, "vine-detour: mprotect failed for %s\n", sym); return -1; }
    // movabs rax, repl ; jmp rax
    f[0] = 0x48; f[1] = 0xb8; __builtin_memcpy(f + 2, &repl, 8); f[10] = 0xff; f[11] = 0xe0;
    mprotect((void *)page, 8192, 5 /* RX */);
    return 0;
}

// Original implementation of a symbol a wrapper overrides (looked up in the renamed .darling copy).
void *vine_orig(const char *image, const char *sym) {
    void *h = dlopen(image, RTLD_LAZY | RTLD_NOLOAD);
    void *f = h ? dlsym(h, sym) : 0;
    if (!f) dprintf(2, "vine-orig: %s not found in %s\n", sym, image);
    return f;
}
