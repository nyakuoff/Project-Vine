// Wrapper for /usr/lib/system/libsystem_kernel.dylib (Darling 0.1.20260608 fixes).
//
// 1. exit in a forked child: Darling's sys_exit runs glibc exit() (host atexit handlers) before
//    exit_group. After fork() in a process that already loaded Mesa, Mesa's atexit handler
//    pthread_join()s worker threads that do not exist in the child -> the child never exits and
//    the parent's wait4() hangs (crashpad's fork/spawn/exit handler launch in Roblox).
//    Single-threaded processes now exit_group directly (a forked child is single-threaded, while
//    any process that really runs Mesa has its worker threads); others keep Darling's path.
//    (No constructor-based pid check: dyld rejects initializers in images not linking libSystem.)
//
// 2. xattrs:
// Darling 0.1.20260608 passes macOS attribute names (e.g. "org.chromium.x") straight to Linux,
// which only accepts namespaced names (EOPNOTSUPP), and getxattr() returns 0 instead of the size.
// Here: macOS names live under Linux "user.", sizes are returned, options/errno are translated.
// Links only against the wrapped library (no libSystem: this sits underneath it).
#include <stddef.h>
#include <stdint.h>

typedef long ssize_t;
int __linux_syscall(int nr, ...);
int __darling_vchroot_expand(const char *path, char *out);
int *__error(void);
void *elfcalls_get_pointer(void);
// Called through data pointers (bound at load): direct calls would need lazy stubs and
// dyld_stub_binder, i.e. libSystem, which this library sits underneath.
static int (*volatile p_syscall)(int, ...) = __linux_syscall;
static int (*volatile p_expand)(const char *, char *) = __darling_vchroot_expand;
static int *(*volatile p_error)(void) = __error;
static void *(*volatile p_elfcalls)(void) = elfcalls_get_pointer;
#define __linux_syscall p_syscall
#define __darling_vchroot_expand p_expand
#define __error p_error

enum { L_setxattr = 188, L_lsetxattr, L_fsetxattr, L_getxattr, L_lgetxattr, L_fgetxattr,
       L_listxattr, L_llistxattr, L_flistxattr, L_removexattr, L_lremovexattr, L_fremovexattr };
#define XATTR_NOFOLLOW 1
#define XATTR_CREATE 2
#define XATTR_REPLACE 4
#define PFX "user."

static long fail(long linux_err) {
    static const struct { int l, d; } map[] = {
        {2, 2}, {7, 7}, {9, 9}, {13, 13}, {20, 20}, {22, 22}, {28, 28}, {30, 30},
        {34, 34}, {36, 63}, {61, 93 /* ENODATA -> ENOATTR */}, {95, 45 /* ENOTSUP */}, {17, 17},
    };
    int e = (int)-linux_err, d = 5 /* EIO */;
    for (size_t i = 0; i < sizeof map / sizeof *map; i++) if (map[i].l == e) d = map[i].d;
    *__error() = d;
    return -1;
}

static int has_ns(const char *n) {
    static const char *ns[] = {"user.", "trusted.", "security.", "system."};
    for (int i = 0; i < 4; i++) {
        const char *a = ns[i], *b = n;
        while (*a && *a == *b) a++, b++;
        if (!*a) return 1;
    }
    return 0;
}

// Linux name for a Darwin name, written into buf (256 = XATTR_MAXNAMELEN-ish + prefix).
static const char *lname(const char *name, char buf[300]) {
    if (has_ns(name)) return name;
    size_t i = 0;
    for (const char *p = PFX; *p; ) buf[i++] = *p++;
    for (const char *p = name; *p && i < 299; ) buf[i++] = *p++;
    buf[i] = 0;
    return buf;
}

static const char *hpath(const char *path, char out[4096]) {
    return __darling_vchroot_expand(path, out) < 0 ? path : out;
}

static int bad_position(uint32_t pos) { if (pos) { *__error() = 22; return 1; } return 0; }

ssize_t getxattr(const char *path, const char *name, void *value, size_t size, uint32_t pos, int opt) {
    char p[4096], n[300];
    if (bad_position(pos)) return -1;
    long r = __linux_syscall(opt & XATTR_NOFOLLOW ? L_lgetxattr : L_getxattr, hpath(path, p), lname(name, n), value, size);
    return r < 0 ? fail(r) : r;
}

ssize_t fgetxattr(int fd, const char *name, void *value, size_t size, uint32_t pos, int opt) {
    char n[300];
    if (bad_position(pos)) return -1;
    long r = __linux_syscall(L_fgetxattr, fd, lname(name, n), value, size);
    return r < 0 ? fail(r) : r;
}

static int lflags(int opt) { return (opt & XATTR_CREATE ? 1 : 0) | (opt & XATTR_REPLACE ? 2 : 0); }

int setxattr(const char *path, const char *name, const void *value, size_t size, uint32_t pos, int opt) {
    char p[4096], n[300];
    if (bad_position(pos)) return -1;
    long r = __linux_syscall(opt & XATTR_NOFOLLOW ? L_lsetxattr : L_setxattr, hpath(path, p), lname(name, n), value, size, lflags(opt));
    return r < 0 ? (int)fail(r) : 0;
}

int fsetxattr(int fd, const char *name, const void *value, size_t size, uint32_t pos, int opt) {
    char n[300];
    if (bad_position(pos)) return -1;
    long r = __linux_syscall(L_fsetxattr, fd, lname(name, n), value, size, lflags(opt));
    return r < 0 ? (int)fail(r) : 0;
}

int removexattr(const char *path, const char *name, int opt) {
    char p[4096], n[300];
    long r = __linux_syscall(opt & XATTR_NOFOLLOW ? L_lremovexattr : L_removexattr, hpath(path, p), lname(name, n));
    return r < 0 ? (int)fail(r) : 0;
}

int fremovexattr(int fd, const char *name, int opt) {
    char n[300];
    long r = __linux_syscall(L_fremovexattr, fd, lname(name, n));
    return r < 0 ? (int)fail(r) : 0;
}

// Linux returns "user.a\0trusted.b\0..."; Darwin callers get "a\0..." (user.* only, prefix stripped).
static ssize_t strip_list(char *raw, long len, char *out, size_t size) {
    size_t o = 0;
    for (long i = 0; i < len; ) {
        char *e = raw + i; long l = 0;
        while (i + l < len && e[l]) l++;
        if (l > 5 && e[0] == 'u' && e[1] == 's' && e[2] == 'e' && e[3] == 'r' && e[4] == '.') {
            if (out && o + (size_t)(l - 5) + 1 > size) { *__error() = 34; return -1; }
            if (out) { for (long k = 5; k < l; k++) out[o + k - 5] = e[k]; out[o + l - 5] = 0; }
            o += (size_t)(l - 5) + 1;
        }
        i += l + 1;
    }
    return (ssize_t)o;
}

static ssize_t list_common(int nr, long target, char *namebuf, size_t size) {
    char raw[65536];   // ponytail: 64 KiB of names per file is plenty for app metadata
    long r = __linux_syscall(nr, target, raw, sizeof raw);
    return r < 0 ? fail(r) : strip_list(raw, r, namebuf, size);
}

ssize_t listxattr(const char *path, char *namebuf, size_t size, int opt) {
    char p[4096];
    return list_common(opt & XATTR_NOFOLLOW ? L_llistxattr : L_listxattr, (long)hpath(path, p), namebuf, size);
}

ssize_t flistxattr(int fd, char *namebuf, size_t size, int opt) {
    return list_common(L_flistxattr, fd, namebuf, size);
}

// ---- exit -------------------------------------------------------------------------------
enum { L_read = 0, L_open = 2, L_close = 3, L_exit_group = 231 };

static int thread_count(void) {   // "Threads:\t<n>" from /proc/self/status, -1 if unknown
    char buf[4096];
    long fd = __linux_syscall(L_open, "/proc/self/status", 0), n;
    if (fd < 0) return -1;
    n = __linux_syscall(L_read, fd, buf, sizeof buf - 1);
    __linux_syscall(L_close, fd);
    if (n <= 0) return -1;
    buf[n] = 0;
    for (char *p = buf; *p; p++)
        if (p[0] == 'T' && p[1] == 'h' && p[2] == 'r' && p[3] == 'e' && p[4] == 'a' && p[5] == 'd' && p[6] == 's' && p[7] == ':') {
            int v = 0;
            for (p += 8; *p == '\t' || *p == ' '; p++) ;
            while (*p >= '0' && *p <= '9') v = v * 10 + (*p++ - '0');
            return v;
        }
    return -1;
}

// struct elf_calls (mldr): dlsym is slot 2, exit is slot 19 in current sources. The exit slot is
// only trusted if it matches glibc's exit as reported by the table's own dlsym.
static void native_exit(int status) {
    void **ec = p_elfcalls ? (void **)p_elfcalls() : 0;
    if (!ec) return;
    void *(*dl)(void *, const char *) = (void *(*)(void *, const char *))ec[2];
    if (dl && ec[19] && ec[19] == dl(0 /* RTLD_DEFAULT */, "exit"))
        ((void (*)(int))ec[19])(status);
}

static void vine_exit(int status) {
    if (thread_count() != 1)
        native_exit(status);   // Darling's normal behaviour
    for (;;) __linux_syscall(L_exit_group, status);
}
void _exit(int status) { vine_exit(status); }
void __exit(int status) __asm__("___exit");
void __exit(int status) { vine_exit(status); }

// ---- workqueue thread reuse ---------------------------------------------------------------
// Darling's sys_workq_kernreturn parks a GCD worker on THREAD_RETURN and, when the worker is
// reused, jumps back into _start_wqthread without resetting the stack pointer (its comment says
// "reset stack"; XNU does). Each reuse leaves ~580 B of dead frames on the 512 KiB stack, so a busy
// worker hits its guard page after ~900 jobs (Roblox: SIGSEGV seconds after joining a game).
// Fix: run those two ops from the top of the worker's stack, as XNU starts it. Nothing above is
// live: a workqueue pthread sits exactly at its stack top, Darling keeps its own thread-start
// frames on a separate host stack (threads.c, setjmp/longjmp), and neither op returns.
// Entered through Darwin's generic syscall() so the original handler runs unchanged.
int syscall(int, ...);
static long (*volatile p_bsd_syscall)(int, ...) = (long (*)(int, ...))syscall;
enum { SYS_workq_kernreturn = 368, WQOPS_THREAD_RETURN = 4, WQOPS_THREAD_KEVENT_RETURN = 0x40 };

int __workq_kernreturn(int options, void *item, int affinity, int prio) __asm__("___workq_kernreturn");
int __workq_kernreturn(int options, void *item, int affinity, int prio) {
    uintptr_t top, sp = (uintptr_t)__builtin_frame_address(0);
    __asm__("movq %%gs:0, %0" : "=r"(top));   // TSD slot 0: pthread_self
    int parks = options == WQOPS_THREAD_RETURN || options == WQOPS_THREAD_KEVENT_RETURN;
    // Only on a real workqueue stack, and never when the kevent list lives in the dropped frames.
    if (parks && top > sp && top - sp < (8u << 20) && !((uintptr_t)item >= sp && (uintptr_t)item < top)) {
        register long a0 __asm__("rdi") = SYS_workq_kernreturn;
        register long a1 __asm__("rsi") = options;
        register void *a2 __asm__("rdx") = item;
        register long a3 __asm__("rcx") = affinity;
        register long a4 __asm__("r8") = prio;
        __asm__ volatile("movq %[top], %%rsp\n\txorl %%ebp, %%ebp\n\txorl %%eax, %%eax\n\tcallq *%[fn]\n\tud2"
                         :: [top] "r"((top & ~(uintptr_t)15) - 128), [fn] "r"(p_bsd_syscall),
                            "r"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(a4) : "rax", "memory");
        __builtin_unreachable();
    }
    return (int)p_bsd_syscall(SYS_workq_kernreturn, options, item, affinity, prio);
}
