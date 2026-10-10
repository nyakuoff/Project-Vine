// Wrapper for /usr/lib/system/libsystem_platform.dylib: fast memory and string primitives.
//
// Darling builds libsystem_platform without optimization (Apple ships hand-written assembly):
// memmove copies a word at a time through the stack, memset ran at 0.4 GB/s here
// (tests/darwin/libc_speed.m), and MacOBlox measured a third of Roblox's menu main thread in
// _platform_memmove (finding credited to MacOBlox, fast_libc.c). libsystem_c's memcpy/memmove/
// memset/bzero/memcmp/strlen call these. Vine's own versions: `rep movsb` / `rep stosb` for blocks of
// 256 bytes and more, 8-byte words below that, a backward word loop for overlapping moves.
// Freestanding, no builtins: the build checks that no function calls itself through a libc name.
#include <stddef.h>
#include <stdint.h>

typedef uint64_t __attribute__((may_alias, aligned(1))) u64u;   // unaligned 8-byte access

static inline void copy_fwd(unsigned char *d, const unsigned char *s, size_t n) {
    if (n >= 256) { __asm__ volatile("rep movsb" : "+D"(d), "+S"(s), "+c"(n) : : "memory"); return; }
    for (; n >= 8; n -= 8, d += 8, s += 8) *(u64u *)d = *(const u64u *)s;
    for (; n; n--) *d++ = *s++;
}
static inline void copy_bwd(unsigned char *d, const unsigned char *s, size_t n) {   // d > s, overlapping
    d += n; s += n;
    for (; n >= 8; n -= 8) { d -= 8; s -= 8; *(u64u *)d = *(const u64u *)s; }
    for (; n; n--) *--d = *--s;
}
void *_platform_memmove(void *dst, const void *src, size_t n) {
    unsigned char *d = dst; const unsigned char *s = src;
    if (d == s || !n) return dst;
    if ((uintptr_t)d - (uintptr_t)s >= n) copy_fwd(d, s, n);   // d before s, or no overlap
    else copy_bwd(d, s, n);
    return dst;
}
void *_platform_memset(void *dst, int c, size_t n) {
    unsigned char *d = dst;
    if (n >= 256) { __asm__ volatile("rep stosb" : "+D"(d), "+c"(n) : "a"(c) : "memory"); return dst; }
    uint64_t v = (unsigned char)c * 0x0101010101010101ull;
    for (; n >= 8; n -= 8, d += 8) *(u64u *)d = v;
    for (; n; n--) *d++ = (unsigned char)c;
    return dst;
}
void _platform_bzero(void *dst, size_t n) { _platform_memset(dst, 0, n); }
void __bzero(void *dst, size_t n) __asm__("___bzero");
void __bzero(void *dst, size_t n) { _platform_memset(dst, 0, n); }

int _platform_memcmp(const void *a, const void *b, size_t n) {
    const unsigned char *x = a, *y = b;
    for (; n >= 8; n -= 8, x += 8, y += 8) if (*(const u64u *)x != *(const u64u *)y) break;
    for (; n; n--, x++, y++) if (*x != *y) return *x - *y;
    return 0;
}
size_t _platform_strlen(const char *s) {
    const char *p = s;
    for (; (uintptr_t)p & 7; p++) if (!*p) return p - s;   // to 8-byte alignment (never crosses a page)
    for (;; p += 8) {
        uint64_t w = *(const uint64_t *)p;
        if ((w - 0x0101010101010101ull) & ~w & 0x8080808080808080ull) break;
    }
    while (*p) p++;
    return p - s;
}
// Patterns: write one copy, then double the filled prefix (non-overlapping forward copies).
static void fill_pattern(unsigned char *d, const unsigned char *pat, size_t plen, size_t n) {
    size_t done = n < plen ? n : plen;
    copy_fwd(d, pat, done);
    while (done < n) { size_t k = done < n - done ? done : n - done; copy_fwd(d + done, d, k); done += k; }
}
void _platform_memset_pattern4(void *b, const void *p, size_t n) { fill_pattern(b, p, 4, n); }
void _platform_memset_pattern8(void *b, const void *p, size_t n) { fill_pattern(b, p, 8, n); }
void _platform_memset_pattern16(void *b, const void *p, size_t n) { fill_pattern(b, p, 16, n); }
