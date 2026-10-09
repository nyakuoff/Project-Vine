// Wrapper for /usr/lib/libresolv.9.dylib (Darling 0.1.20260608 fix).
// Darling's getaddrinfo backend (Libinfo/darling-resolver) calls res_query(), the BIND API that
// keeps one process-global resolver state, including the TCP query socket (_vcsock). Concurrent
// lookups from several threads (Roblox's HTTP client) then read/write/close each other's socket
// (connect -> EBADF, wrong-socket writev) and resolution fails ("HttpError: DnsResolve").
// res_query is answered here with the reentrant API on a private per-call state.
// Plain C, links only the wrapped library (it is loaded during libSystem start-up).

int res_9_ninit(void *statp);
int res_9_nquery(void *statp, const char *dname, int class, int type, unsigned char *answer, int anslen);
void res_9_ndestroy(void *statp);
// Called through data pointers (bound at load): direct calls would need dyld_stub_binder (libSystem).
static int (*volatile p_ninit)(void *) = res_9_ninit;
static int (*volatile p_nquery)(void *, const char *, int, int, unsigned char *, int) = res_9_nquery;
static void (*volatile p_ndestroy)(void *) = res_9_ndestroy;

#define STATE_BYTES 2048   // sizeof(struct __res_state) is ~560 on x86_64; extra room is harmless

int res_9_query(const char *name, int class, int type, unsigned char *answer, int anslen) {
    _Alignas(16) unsigned long long st[STATE_BYTES / 8];
    for (int i = 0; i < STATE_BYTES / 8; i++) st[i] = 0;   // res_ninit expects a zeroed state
    if (p_ninit(st) < 0) return -1;
    int n = p_nquery(st, name, class, type, answer, anslen);   // also sets h_errno on failure
    p_ndestroy(st);
    return n;
}
