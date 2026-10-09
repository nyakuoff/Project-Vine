// Host-side check of shims/resolv.c's telemetry blocklist (compiled natively; no Darling needed).
// Run: cc -w -o /tmp/tb tests/host/telemetry_block_test.c && /tmp/tb
#include <assert.h>
#include <stdio.h>
// resolv.c calls the reentrant resolver of the wrapped library; stub it for the host build.
static int res_9_ninit(void *s) { return 0; }
static int res_9_nquery(void *s, const char *d, int c, int t, unsigned char *a, int l) { return 7; }
static void res_9_ndestroy(void *s) {}
#define res_9_ninit(x) res_9_ninit(x)
#include "../../shims/resolv.c"

int main(void) {
    assert(is_blocked("pulsar.roblox.com"));
    assert(is_blocked("PULSAR.Roblox.com."));
    assert(is_blocked("eu.sentry-relay.rbx.com"));
    assert(is_blocked("uploads.backtrace.rbx.com"));
    assert(!is_blocked("apis.roblox.com"));
    assert(!is_blocked("www.roblox.com"));
    assert(!is_blocked("notpulsar.roblox.com"));                 // whole-label match only
    assert(!is_blocked("lms-aws-ap-northeast-3.roblox.com"));
    assert(!is_blocked("roblox.com"));
    assert(res_9_query("pulsar.roblox.com", 1, 1, 0, 0) == -1);  // blocked: fails without a query
    assert(res_9_query("www.roblox.com", 1, 1, 0, 0) == 7);      // allowed: goes to the resolver
    puts("telemetry blocklist: all checks passed");
    return 0;
}
