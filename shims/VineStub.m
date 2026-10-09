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

// ---- local symbols of loaded images ---------------------------------------------------------------
// Resolves any symbol in a loaded image's symbol table (including non-exported "t" symbols that
// dlsym cannot see) by walking LC_SYMTAB in its mapped __LINKEDIT. image_suffix matches the end of
// the image path. Returns NULL if the image isn't loaded or the symbol is absent.
uint32_t _dyld_image_count(void);
const char *_dyld_get_image_name(uint32_t);
const void *_dyld_get_image_header(uint32_t);
intptr_t _dyld_get_image_vmaddr_slide(uint32_t);
int strcmp(const char *, const char *);
size_t strlen(const char *);
void *vine_local_symbol(const char *image_suffix, const char *sym) {
    size_t sl = strlen(image_suffix);
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        size_t nl = name ? strlen(name) : 0;
        if (nl < sl || strcmp(name + nl - sl, image_suffix)) continue;
        const uint8_t *h = _dyld_get_image_header(i);
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        uint32_t ncmds = *(const uint32_t *)(h + 16);
        const uint8_t *p = h + 32;
        uint64_t le_vm = 0, le_off = 0; const uint32_t *st = 0;
        for (uint32_t c = 0; c < ncmds; c++) {
            uint32_t cmd = ((const uint32_t *)p)[0], size = ((const uint32_t *)p)[1];
            if (cmd == 0x19 && !strcmp((const char *)p + 8, "__LINKEDIT")) { le_vm = *(const uint64_t *)(p + 24); le_off = *(const uint64_t *)(p + 40); }
            if (cmd == 0x2) st = (const uint32_t *)p;   // LC_SYMTAB: cmd, size, symoff, nsyms, stroff, strsize
            p += size;
        }
        if (!st || !le_vm) return 0;
        const uint8_t *base = (const uint8_t *)(slide + le_vm - le_off);
        const uint8_t *syms = base + st[2];
        const char *strs = (const char *)base + st[4];
        for (uint32_t k = 0; k < st[3]; k++) {
            const uint8_t *n = syms + 16 * k;   // nlist_64: strx(4) type(1) sect(1) desc(2) value(8)
            if (n[4] & 0xe0) continue;          // N_STAB debugging entries
            if (!strcmp(strs + *(const uint32_t *)n, sym)) return (void *)(*(const uint64_t *)(n + 8) + slide);
        }
        return 0;
    }
    return 0;
}

int vine_detour_addr(void *fn, void *repl) {
    unsigned char *f = fn;
    if (!f || f == repl) return -1;
    uintptr_t page = (uintptr_t)f & ~(uintptr_t)4095;
    if (mprotect((void *)page, 8192, 7)) return -1;
    f[0] = 0x48; f[1] = 0xb8; __builtin_memcpy(f + 2, &repl, 8); f[10] = 0xff; f[11] = 0xe0;   // movabs rax, repl; jmp rax
    mprotect((void *)page, 8192, 5);
    return 0;
}
