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

// ---- sockets ------------------------------------------------------------------------------
// recvfrom (and recv, which libc builds on it): Darling's sys_recvfrom computes the Linux flags but
// passes the Darwin ones (recvfrom.c), so MSG_DONTWAIT (0x80) reached Linux as MSG_EOR and a
// "non-blocking" receive slept until data or SO_RCVTIMEO (MacOBlox found this too). Translate here;
// the handler then passes them through unchanged. recvmsg/sendto/sendmsg translate correctly.
enum { SYS_recvfrom = 29, SYS_recvfrom_nocancel = 403, SYS_connect = 98, SYS_bind = 104, SYS_sendmsg = 28 };
static int msg_flags_linux(int f) {
    static const int map[][2] = {{0x1, 0x1}, {0x2, 0x2}, {0x4, 0x4}, {0x8, 0x80}, {0x10, 0x20},
                                 {0x20, 0x8}, {0x40, 0x100}, {0x80, 0x40}};   // OOB PEEK DONTROUTE EOR TRUNC CTRUNC WAITALL DONTWAIT
    int o = 0;
    for (size_t i = 0; i < sizeof map / sizeof *map; i++) if (f & map[i][0]) o |= map[i][1];
    return o;
}
// VINE_TRACE_UDP=1: UDP sends/receives (300 per socket, 12 sockets) to stderr (time, socket, size, how long a
// receive waited), to see where a game join's handshake waits. Read from /proc/self/environ: this
// wrapper sits underneath libc (no getenv).
enum { L_write = 1, L_getsockopt = 55, L_clock_gettime = 228 };
static int udp_trace_on(void) {
    static int on = -1;
    if (on >= 0) return on;
    char buf[8192]; long fd = __linux_syscall(L_open, "/proc/self/environ", 0), n;
    on = 0;
    if (fd < 0) return on;
    n = __linux_syscall(L_read, fd, buf, sizeof buf - 1);
    __linux_syscall(L_close, fd);
    static const char key[] = "VINE_TRACE_UDP=1";
    for (long i = 0; i + 16 <= n; i++) {
        if (i && buf[i - 1]) continue;
        int k = 0; while (k < 16 && buf[i + k] == key[k]) k++;
        if (k == 16) on = 1;
    }
    return on;
}
static long now_us(void) {
    struct { long s, ns; } t; __linux_syscall(L_clock_gettime, 1, &t); return t.s * 1000000 + t.ns / 1000;
}
static int is_net_udp(int fd) {   // UDP over IPv4/IPv6 (not local socket pairs)
    int type = 0, dom = 0; unsigned len = 4, len2 = 4;
    return __linux_syscall(L_getsockopt, fd, 1, 3 /* SO_TYPE */, &type, &len) == 0 && type == 2 &&
           __linux_syscall(L_getsockopt, fd, 1, 39 /* SO_DOMAIN */, &dom, &len2) == 0 && (dom == 2 || dom == 10);
}
static void udp_trace(const char *op, int fd, long bytes, long waited_us) {
    // 300 events per socket, 12 sockets: the join's RakNet socket is traced even after the menu's
    // other UDP traffic (a QUIC-style connection, STUN probes)
    static struct { int fd, n; } socks[12]; static int nsocks, skip[32], nskip; static long t0;
    if (!udp_trace_on()) return;
    // ponytail: a skipped number reused later by a network socket stays untraced; check per call if it matters
    for (int k = 0; k < nskip; k++) if (skip[k] == fd) return;   // known local socket pairs
    int i = 0;
    while (i < nsocks && socks[i].fd != fd) i++;
    if (i == nsocks) {
        if (nsocks == 12) return;
        if (!is_net_udp(fd)) { if (nskip < 32) skip[nskip++] = fd; return; }
        socks[nsocks].fd = fd; socks[nsocks++].n = 0;
    }
    if (socks[i].n++ >= 300) return;
    if (!t0) t0 = now_us();
    char line[96], *p = line + 96;   // "vine-udp: +SSS.mmm op fd=N bytes waited=Nms\n", built backwards
    #define PUT(c) (*--p = (c))
    #define NUM(v) do { long v_ = (v); int neg_ = v_ < 0; if (neg_) v_ = -v_; do PUT('0' + v_ % 10); while (v_ /= 10); if (neg_) PUT('-'); } while (0)
    PUT('\n'); PUT('s'); PUT('m'); NUM(waited_us / 1000); PUT('='); PUT('t'); PUT('i'); PUT('a'); PUT('w'); PUT(' ');
    NUM(bytes); PUT(' '); NUM(fd); PUT('='); PUT('d'); PUT('f'); PUT(' ');
    const char *e = op; while (*e) e++;
    while (e > op) PUT(*--e);
    PUT(' '); long ms = (now_us() - t0) / 1000;
    PUT('0' + ms % 10); PUT('0' + ms / 10 % 10); PUT('0' + ms / 100 % 10); PUT('.'); NUM(ms / 1000); PUT('+'); PUT(' ');
    static const char tag[] = "vine-udp:";
    for (int i = 8; i >= 0; i--) PUT(tag[i]);
    __linux_syscall(L_write, 2, p, line + 96 - p);
    #undef PUT
    #undef NUM
}
static ssize_t vine_recvfrom(int nr, int fd, void *buf, size_t len, int flags, void *from, void *fromlen) {
    long t = udp_trace_on() ? now_us() : 0;
    ssize_t r = p_bsd_syscall(nr, fd, buf, len, msg_flags_linux(flags), from, fromlen);
    if (t && r >= 0) udp_trace("recvfrom", fd, r, now_us() - t);
    return r;
}
ssize_t recvfrom(int fd, void *b, size_t n, int f, void *from, void *fl) { return vine_recvfrom(SYS_recvfrom, fd, b, n, f, from, fl); }
ssize_t recvfrom_nocancel(int, void *, size_t, int, void *, void *) __asm__("_recvfrom$NOCANCEL");
ssize_t recvfrom_nocancel(int fd, void *b, size_t n, int f, void *from, void *fl) { return vine_recvfrom(SYS_recvfrom_nocancel, fd, b, n, f, from, fl); }
ssize_t __recvfrom(int fd, void *b, size_t n, int f, void *from, void *fl) { return vine_recvfrom(SYS_recvfrom, fd, b, n, f, from, fl); }
ssize_t __recvfrom_nocancel(int fd, void *b, size_t n, int f, void *from, void *fl) { return vine_recvfrom(SYS_recvfrom_nocancel, fd, b, n, f, from, fl); }

// connectx: unimplemented in Darling (syscall 447, ENOSYS). Roblox's RbxTransport connects its UDP
// socket with it; the socket stayed unconnected and the game connection failed (finding credited
// to MacOBlox). Done as Apple documents it: bind to the source if given, connect to the destination,
// send the optional initial data. A pending (EINPROGRESS) connect is returned as such.
typedef struct { unsigned srcif; const void *src; uint32_t srclen; const void *dst; uint32_t dstlen; } vine_sa_endpoints;
struct vine_msghdr { void *name; uint32_t namelen; const void *iov; int iovlen; void *control; uint32_t controllen; int flags; };
int connectx(int s, const vine_sa_endpoints *ep, uint32_t assoc, unsigned flags, const void *iov, unsigned iovcnt,
             size_t *sent, uint32_t *connid) {
    if (sent) *sent = 0;
    if (!ep || !ep->dst) { *__error() = 22; return -1; }   // EINVAL
    if (ep->src && p_bsd_syscall(SYS_bind, s, ep->src, ep->srclen) < 0) return -1;
    if (p_bsd_syscall(SYS_connect, s, ep->dst, ep->dstlen) < 0) return -1;
    if (connid) *connid = 1;
    if (iov && iovcnt) {
        struct vine_msghdr m = {0, 0, iov, (int)iovcnt, 0, 0, 0};
        long n = p_bsd_syscall(SYS_sendmsg, s, &m, 0);
        if (n < 0) return -1;
        if (sent) *sent = (size_t)n;
    }
    return 0;
}

// sendmsg/recvmsg/setsockopt for UDP transports (Roblox's RbxTransport). Darling (network/*.c):
//  - recvmsg sets only the family byte of the sender address: sin_len stays 2 (Linux's family low
//    byte), so a peer check against the server's address fails;
//  - sendmsg converts just the first control message and keeps the Darwin type numbers, which
//    mean other options on Linux (Darwin IP_TOS 3 = Linux IP_RETOPTS) -> EINVAL, packet not sent;
//  - recvmsg returns control messages with Linux type numbers;
//  - setsockopt rejects IP_RECVPKTINFO, IP_RECVTOS, IP_DONTFRAG and their IPv6 forms (ENOTSUP).
// All checked by tests/darwin/udp_probe.m. Here both calls go to Linux directly with full
// conversion. ponytail: these are not cancellation points; add if a thread is ever pthread_cancel'ed
// in one.
enum { L_sendmsg = 46, L_recvmsg = 47, L_setsockopt = 54, SYS_setsockopt = 105 };
static long net_err(long r) {   // Linux -errno -> Darwin errno, -1
    static const short map[][2] = {{11, 35}, {90, 40}, {111, 61}, {101, 51}, {113, 65}, {105, 55}, {107, 57},
        {88, 38}, {95, 45}, {89, 39}, {104, 54}, {99, 49}, {98, 48}, {110, 60}, {106, 56}, {97, 47}, {92, 42}, {93, 43}};
    int e = (int)-r, d = e;
    for (size_t i = 0; i < sizeof map / sizeof *map; i++) if (map[i][0] == e) d = map[i][1];
    *__error() = d;
    return -1;
}
// {level, Darwin type, Linux type} for control messages and the socket options that enable them.
static const int cmsg_map[][3] = {
    {0, 3, 1} /* IP_TOS */, {0, 27, 1} /* IP_RECVTOS (received as IP_TOS) */, {0, 26, 8} /* IP_PKTINFO */,
    {0, 4, 2} /* IP_TTL */, {0, 24, 2} /* IP_RECVTTL (received as IP_TTL) */,
    {41, 36, 67} /* IPV6_TCLASS */, {41, 46, 50} /* IPV6_PKTINFO */, {41, 47, 52} /* IPV6_HOPLIMIT */,
    {41, 62, 62} /* IPV6_DONTFRAG */, {0xffff, 0x400, 29} /* SO_TIMESTAMP */, {0xffff, 1, 1} /* SCM_RIGHTS */,
};
static int cmsg_to_linux(int level, int type) {   // Darwin -> Linux (first match: the sending form)
    for (size_t i = 0; i < sizeof cmsg_map / sizeof *cmsg_map; i++)
        if (cmsg_map[i][0] == level && cmsg_map[i][1] == type) return cmsg_map[i][2];
    return type;
}
static int cmsg_to_darwin(int level, int type) {   // Linux -> Darwin, received form
    if (level == 0 && type == 1) return 27;   // IP_TOS arrives as IP_RECVTOS on Darwin
    if (level == 0 && type == 2) return 24;   // IP_TTL arrives as IP_RECVTTL
    for (size_t i = 0; i < sizeof cmsg_map / sizeof *cmsg_map; i++)
        if (cmsg_map[i][0] == level && cmsg_map[i][2] == type) return cmsg_map[i][1];
    return type;
}
static int level_to_linux(int l) { return l == 0xffff ? 1 : l; }
static int level_to_darwin(int l) { return l == 1 ? 0xffff : l; }
static int family_to_linux(int f) { return f == 30 ? 10 : f; }
static int family_to_darwin(int f) { return f == 10 ? 30 : f; }

struct d_msghdr { void *name; uint32_t namelen; void *iov; int iovlen; void *control; uint32_t controllen; int flags; };
struct l_msghdr { void *name; uint32_t namelen; void *iov; size_t iovlen; void *control; size_t controllen; int flags; };
struct d_cmsg { uint32_t len; int level, type; };
struct l_cmsg { size_t len; int level, type; };
#define D_ALIGN(n) (((n) + 3) & ~(size_t)3)
#define L_ALIGN(n) (((n) + 7) & ~(size_t)7)
static void copy_bytes(void *d, const void *s, size_t n) { for (size_t i = 0; i < n; i++) ((char *)d)[i] = ((const char *)s)[i]; }

static int msg_flags_darwin(int f) {   // received msg_flags: Linux -> Darwin
    static const int map[][2] = {{0x1, 0x1}, {0x80, 0x8}, {0x20, 0x10}, {0x8, 0x20}};   // OOB EOR TRUNC CTRUNC
    int o = 0;
    for (size_t i = 0; i < sizeof map / sizeof *map; i++) if (f & map[i][0]) o |= map[i][1];
    return o;
}

static ssize_t vine_sendmsg(int fd, const struct d_msghdr *m, int flags) {
    char name[128], ctl[1024];
    struct l_msghdr l = {0, 0, m->iov, (size_t)m->iovlen, 0, 0, 0};
    if (m->name && m->namelen) {
        if (m->namelen > sizeof name) { *__error() = 22; return -1; }
        copy_bytes(name, m->name, m->namelen);
        *(uint16_t *)name = (uint16_t)family_to_linux(((uint8_t *)m->name)[1]);
        l.name = name; l.namelen = m->namelen;
    }
    size_t out = 0;
    for (size_t pos = 0; m->control && pos + sizeof(struct d_cmsg) <= m->controllen; ) {
        const struct d_cmsg *d = (const struct d_cmsg *)((char *)m->control + pos);
        if (d->len < sizeof *d || pos + d->len > m->controllen) break;
        size_t data = d->len - sizeof *d;
        if (out + L_ALIGN(sizeof(struct l_cmsg) + data) > sizeof ctl) { *__error() = 55; return -1; }   // ENOBUFS
        struct l_cmsg *c = (struct l_cmsg *)(ctl + out);
        c->len = sizeof *c + data; c->level = level_to_linux(d->level); c->type = cmsg_to_linux(d->level, d->type);
        copy_bytes(c + 1, d + 1, data);
        out += L_ALIGN(c->len);
        pos += D_ALIGN(d->len);
    }
    if (out) { l.control = ctl; l.controllen = out; }
    long r = __linux_syscall(L_sendmsg, fd, &l, msg_flags_linux(flags));
    if (r >= 0) udp_trace("sendmsg", fd, r, 0);
    return r < 0 ? net_err(r) : r;
}

static ssize_t vine_recvmsg(int fd, struct d_msghdr *m, int flags) {
    char ctl[2048];
    struct l_msghdr l = {m->name, m->namelen, m->iov, (size_t)m->iovlen, 0, 0, 0};
    if (m->control && m->controllen) { l.control = ctl; l.controllen = sizeof ctl; }
    long t = udp_trace_on() ? now_us() : 0;
    long r = __linux_syscall(L_recvmsg, fd, &l, msg_flags_linux(flags));
    if (r < 0) return net_err(r);
    if (t) udp_trace("recvmsg", fd, r, now_us() - t);
    if (m->name && l.namelen >= 2) {   // sockaddr: Linux u16 family -> Darwin {len, family}
        uint8_t *a = m->name;
        int fam = family_to_darwin(*(uint16_t *)a);
        a[0] = (uint8_t)(l.namelen < 255 ? l.namelen : 255); a[1] = (uint8_t)fam;
    }
    m->namelen = l.namelen;
    int f = msg_flags_darwin(l.flags);
    size_t out = 0;
    for (size_t pos = 0; l.control && pos + sizeof(struct l_cmsg) <= l.controllen; ) {
        const struct l_cmsg *c = (const struct l_cmsg *)(ctl + pos);
        if (c->len < sizeof *c || pos + c->len > l.controllen) break;
        size_t data = c->len - sizeof *c;
        if (out + sizeof(struct d_cmsg) + data > m->controllen) { f |= 0x20; break; }   // MSG_CTRUNC
        struct d_cmsg *d = (struct d_cmsg *)((char *)m->control + out);
        d->len = (uint32_t)(sizeof *d + data); d->level = level_to_darwin(c->level); d->type = cmsg_to_darwin(c->level, c->type);
        copy_bytes(d + 1, c + 1, data);
        out += D_ALIGN(d->len);
        pos += L_ALIGN(c->len);
    }
    if (m->control) m->controllen = (uint32_t)(out < m->controllen ? out : m->controllen);
    m->flags = f;
    return r;
}
ssize_t sendmsg(int fd, const struct d_msghdr *m, int f) { return vine_sendmsg(fd, m, f); }
ssize_t sendmsg_nocancel(int, const struct d_msghdr *, int) __asm__("_sendmsg$NOCANCEL");
ssize_t sendmsg_nocancel(int fd, const struct d_msghdr *m, int f) { return vine_sendmsg(fd, m, f); }
ssize_t __sendmsg(int fd, const struct d_msghdr *m, int f) { return vine_sendmsg(fd, m, f); }
ssize_t __sendmsg_nocancel(int fd, const struct d_msghdr *m, int f) { return vine_sendmsg(fd, m, f); }
ssize_t recvmsg(int fd, struct d_msghdr *m, int f) { return vine_recvmsg(fd, m, f); }
ssize_t recvmsg_nocancel(int, struct d_msghdr *, int) __asm__("_recvmsg$NOCANCEL");
ssize_t recvmsg_nocancel(int fd, struct d_msghdr *m, int f) { return vine_recvmsg(fd, m, f); }
ssize_t __recvmsg(int fd, struct d_msghdr *m, int f) { return vine_recvmsg(fd, m, f); }
ssize_t __recvmsg_nocancel(int fd, struct d_msghdr *m, int f) { return vine_recvmsg(fd, m, f); }

int setsockopt(int fd, int level, int name, const void *val, uint32_t len) {
    static const int opt[][3] = {   // {level, Darwin option, Linux option}
        {0, 26, 8} /* IP_RECVPKTINFO -> IP_PKTINFO */, {0, 27, 13} /* IP_RECVTOS */,
        {41, 61, 49} /* IPV6_RECVPKTINFO */, {41, 35, 66} /* IPV6_RECVTCLASS */, {41, 36, 67} /* IPV6_TCLASS */,
        {41, 62, 62} /* IPV6_DONTFRAG */, {41, 37, 51} /* IPV6_RECVHOPLIMIT */,
    };
    long r;
    // SO_SNDTIMEO/SO_RCVTIMEO: Darwin's timeval is {long, int} + 4 bytes padding, Linux's {long, long};
    // Darling passed it unconverted, so junk padding became a huge tv_usec -> EDOM (RakNet's send
    // timeout failed; MacOBlox finding). Pass Linux's layout.
    if (level == 0xffff && (name == 0x1005 || name == 0x1006) && val && len >= 12) {
        struct { long sec, usec; } tv = {((const long *)val)[0], ((const int *)val)[2]};
        r = __linux_syscall(L_setsockopt, fd, 1 /* SOL_SOCKET */, name == 0x1005 ? 21 : 20, &tv, sizeof tv);
        return r < 0 ? (int)net_err(r) : 0;
    }
    if (level == 0 && name == 28 && val && len >= 4) {   // IP_DONTFRAG -> IP_MTU_DISCOVER DO/DONT
        int v = *(const int *)val ? 2 : 0;
        r = __linux_syscall(L_setsockopt, fd, 0, 10, &v, 4);
        return r < 0 ? (int)net_err(r) : 0;
    }
    for (size_t i = 0; i < sizeof opt / sizeof *opt; i++)
        if (opt[i][0] == level && opt[i][1] == name) {
            r = __linux_syscall(L_setsockopt, fd, level, opt[i][2], val, len);
            return r < 0 ? (int)net_err(r) : 0;
        }
    return (int)p_bsd_syscall(SYS_setsockopt, fd, level, name, val, len);
}

// ---- memory statistics ---------------------------------------------------------------------
// Darling's host_statistics/host_statistics64 (HOST_VM_INFO, HOST_VM_INFO64) succeed with every
// page count 0. Roblox derives available memory from free + inactive pages, saw 0 MB, raised "Low
// memory warning" at every game join and unloaded its menu app (black screen while joining, slow
// return to the menu). Finding credited to MacOBlox (memory_stats.c). When Darling's counts are
// zero they come from /proc/meminfo: free = MemFree, inactive = the rest of MemAvailable (cache that
// can be dropped, as macOS counts inactive), active = the rest of MemTotal.
extern int (*vine_darling_host_statistics)(unsigned, int, unsigned *, unsigned *);
extern int (*vine_darling_host_statistics64)(unsigned, int, unsigned *, unsigned *);
static int meminfo_kb(unsigned long long *total, unsigned long long *freek, unsigned long long *avail) {
    char buf[2048];
    long fd = __linux_syscall(L_open, "/proc/meminfo", 0), n;
    if (fd < 0) return 0;
    n = __linux_syscall(L_read, fd, buf, sizeof buf - 1);
    __linux_syscall(L_close, fd);
    if (n <= 0) return 0;
    buf[n] = 0;
    *total = *freek = *avail = 0;
    for (char *p = buf; *p; ) {
        unsigned long long *dst = 0;
        if (p[0] == 'M' && p[1] == 'e' && p[2] == 'm') {
            if (p[3] == 'T') dst = total; else if (p[3] == 'F') dst = freek; else if (p[3] == 'A') dst = avail;
        }
        while (*p && *p != ':') p++;
        if (*p) p++;
        while (*p == ' ') p++;
        unsigned long long v = 0;
        while (*p >= '0' && *p <= '9') v = v * 10 + (*p++ - '0');
        if (dst) *dst = v;
        while (*p && *p != '\n') p++;
        if (*p) p++;
    }
    return *total && *avail;
}
static void fill_vm_counts(unsigned *w, unsigned count, int wide) {
    unsigned long long total, freek, avail;
    if (count < 4 || w[0] || !meminfo_kb(&total, &freek, &avail)) return;   // Darling had real data
    w[0] = (unsigned)(freek / 4);                                            // 4 KiB pages
    w[1] = (unsigned)((total - avail) / 4);
    w[2] = (unsigned)((avail - freek) / 4);
    if (wide && count >= 36) { w[34] = w[2]; w[35] = w[1]; }   // external (file) / internal (anonymous)
}
int host_statistics(unsigned host, int flavor, unsigned *info, unsigned *count) {
    int r = vine_darling_host_statistics(host, flavor, info, count);
    if (!r && flavor == 2 /* HOST_VM_INFO */ && count) fill_vm_counts(info, *count, 0);
    return r;
}
int host_statistics64(unsigned host, int flavor, unsigned *info, unsigned *count) {
    int r = vine_darling_host_statistics64(host, flavor, info, count);
    if (!r && (flavor == 4 /* HOST_VM_INFO64 */ || flavor == 2) && count) fill_vm_counts(info, *count, flavor == 4);
    return r;
}

// sendto: unchanged (Darling's translates correctly), traced with VINE_TRACE_UDP=1.
enum { SYS_sendto = 133, SYS_sendto_nocancel = 413 };
static ssize_t vine_sendto(int nr, int fd, const void *b, size_t n, int f, const void *to, uint32_t tl) {
    ssize_t r = p_bsd_syscall(nr, fd, b, n, f, to, tl);
    if (r >= 0) udp_trace("sendto", fd, r, 0);
    return r;
}
ssize_t sendto(int fd, const void *b, size_t n, int f, const void *to, uint32_t tl) { return vine_sendto(SYS_sendto, fd, b, n, f, to, tl); }
ssize_t sendto_nocancel(int, const void *, size_t, int, const void *, uint32_t) __asm__("_sendto$NOCANCEL");
ssize_t sendto_nocancel(int fd, const void *b, size_t n, int f, const void *to, uint32_t tl) { return vine_sendto(SYS_sendto_nocancel, fd, b, n, f, to, tl); }
ssize_t __sendto(int fd, const void *b, size_t n, int f, const void *to, uint32_t tl) { return vine_sendto(SYS_sendto, fd, b, n, f, to, tl); }
ssize_t __sendto_nocancel(int fd, const void *b, size_t n, int f, const void *to, uint32_t tl) { return vine_sendto(SYS_sendto_nocancel, fd, b, n, f, to, tl); }
