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

// Telemetry, analytics and crash-report hosts (user policy: no data collection). A name matches if
// it equals an entry or is a subdomain of it. Blocked lookups fail immediately as "no such host",
// which also stops Roblox waiting on beacon timeouts. Functional hosts (apis, www, users, voice,
// realtime-signalr, clientsettingscdn, lms-* latency probes, CDNs) are deliberately not listed.
static const char *const blocked[] = {
    "client-telemetry.roblox.com", "ecsv2.roblox.com", "test.public.ecs.roblox.com",
    "tracing.roblox.com", "tracing-grpc.roblox.com",
    "pulsar.roblox.com", "silver.roblox.com", "gold.roblox.com",
    "ephemeralcounters.api.roblox.com",
    "sentry-relay.rbx.com", "uploads.backtrace.rbx.com",
};

static int is_blocked(const char *name) {
    char h[256];
    int n = 0;
    for (; name[n] && n < 255; n++) h[n] = name[n] >= 'A' && name[n] <= 'Z' ? name[n] + 32 : name[n];
    if (n && h[n - 1] == '.') n--;          // trailing root dot
    h[n] = 0;
    for (unsigned i = 0; i < sizeof blocked / sizeof *blocked; i++) {
        int m = 0;
        while (blocked[i][m]) m++;
        if (n < m || (n > m && h[n - m - 1] != '.')) continue;   // whole label boundary only
        int j = 0;
        while (j < m && h[n - m + j] == blocked[i][j]) j++;
        if (j == m) return 1;
    }
    return 0;
}

#define STATE_BYTES 2048   // sizeof(struct __res_state) is ~560 on x86_64; extra room is harmless

int res_9_query(const char *name, int class, int type, unsigned char *answer, int anslen) {
    if (name && is_blocked(name)) return -1;   // NXDOMAIN-equivalent: getaddrinfo reports "no such host"
    _Alignas(16) unsigned long long st[STATE_BYTES / 8];
    for (int i = 0; i < STATE_BYTES / 8; i++) st[i] = 0;   // res_ninit expects a zeroed state
    if (p_ninit(st) < 0) return -1;
    int n = p_nquery(st, name, class, type, answer, anslen);   // also sets h_errno on failure
    p_ndestroy(st);
    return n;
}
