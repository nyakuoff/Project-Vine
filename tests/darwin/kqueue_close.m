// Darwin test (runs in Darling): closing a descriptor removes its kqueue watches (macOS semantics),
// for close() and close$NOCANCEL. A stale watch reports the *next* descriptor with that number to
// the old owner's udata: libdispatch then touches a freed source (Roblox: SIGILL in
// _dispatch_kevent_merge once game audio started).
#include "../../shims/vine.h"
int printf(const char *, ...);
struct sin { uint8_t len, family; uint16_t port; uint32_t addr; char zero[8]; };
struct kev { uintptr_t ident; int16_t filter; uint16_t flags; uint32_t fflags; intptr_t data; void *udata; };
struct ts { long sec; long nsec; };
int socket(int, int, int); int bind(int, const void *, uint32_t); int getsockname(int, void *, uint32_t *);
long sendto(int, const void *, size_t, int, const void *, uint32_t); int close(int);
int close_nocancel(int) __asm__("_close$NOCANCEL");
int kqueue(void); int kevent(int, const struct kev *, int, struct kev *, int, const struct ts *);
static int check(const char *how, int (*closer)(int)) {
    struct sin any = {16, 2, 0, 0x0100007f}, addr; uint32_t len = sizeof addr;
    int kq = kqueue(), a = socket(2, 2, 17);
    bind(a, &any, sizeof any);
    struct kev add = {a, -1 /* EVFILT_READ */, 1 /* EV_ADD */, 0, 0, (void *)0xA11CE};
    kevent(kq, &add, 1, 0, 0, 0);
    closer(a);
    int b = socket(2, 2, 17);   // reuses a's number
    bind(b, &any, sizeof any); getsockname(b, &addr, &len);
    int u = socket(2, 2, 17);
    sendto(u, "x", 1, 0, &addr, sizeof addr);
    struct kev out; struct ts wait = {0, 300000000};
    int n = kevent(kq, 0, 0, &out, 1, &wait);
    int stale = n == 1 && out.udata == (void *)0xA11CE;
    printf("%s %s: same fd %d, stale event for old watch: %s\n", !stale && b == a ? "PASS" : (b != a ? "SKIP" : "FAIL"), how, b == a, stale ? "yes" : "no");
    close(b); close(u); close(kq);
    return stale;
}
int main(void) { return check("close", close) + check("close$NOCANCEL", close_nocancel); }
