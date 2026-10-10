// Darwin test (runs in Darling): the UDP socket behaviour Roblox's game transport relies on, over
// loopback. Candidates from MacOBlox's network notes (connectx_compat.c, net_trace.c):
//   connectx    connect a UDP socket with connectx() (RbxTransport does)
//   rcvtimeo    setsockopt(SO_RCVTIMEO) accepted and honoured
//   dontwait    recv(MSG_DONTWAIT) on an empty socket returns EAGAIN at once
//   kevent      EV_CLEAR EVFILT_READ (Asio's style) reports every arriving datagram
// One line per check; exit status = number of failures.
#include "../../shims/vine.h"
int printf(const char *, ...);
struct sin { uint8_t len, family; uint16_t port; uint32_t addr; char zero[8]; };
struct iov { void *base; size_t len; };
typedef struct { unsigned srcif; const void *src; uint32_t srclen; const void *dst; uint32_t dstlen; } sa_endpoints_t;
struct kev { uintptr_t ident; int16_t filter; uint16_t flags; uint32_t fflags; intptr_t data; void *udata; };
struct tv { long sec; int usec; };
struct ts { long sec; long nsec; };
int socket(int, int, int); int bind(int, const void *, uint32_t); int getsockname(int, void *, uint32_t *);
int connectx(int, const sa_endpoints_t *, uint32_t, unsigned, const struct iov *, unsigned, size_t *, uint32_t *);
long send(int, const void *, size_t, int); long recv(int, void *, size_t, int);
int setsockopt(int, int, int, const void *, uint32_t);
int kqueue(void); int kevent(int, const struct kev *, int, struct kev *, int, const struct ts *);
int *__error(void);
uint64_t mach_absolute_time(void);   // nanoseconds on Darling

static int fails;
static void report(int ok, const char *what, const char *detail, long a, long b) {
    dprintf(1, "%s %-9s %s (%ld, %ld)\n", ok ? "ok  " : "FAIL", what, detail, a, b);
    fails += !ok;
}
static double ms_since(uint64_t t0) { return (mach_absolute_time() - t0) / 1e6; }

int main(void) {
    struct sin any = {16, 2, 0, 0x0100007f /* 127.0.0.1 */}, srv;
    uint32_t len = sizeof srv;
    int s = socket(2, 2, 17), c = socket(2, 2, 17);
    bind(s, &any, sizeof any); getsockname(s, &srv, &len);

    sa_endpoints_t ep = {0, 0, 0, &srv, sizeof srv};
    int r = connectx(c, &ep, 0, 0, 0, 0, 0, 0), e = r ? *__error() : 0;
    char buf[64];
    long sent = r ? -1 : send(c, "hello", 5, 0);
    report(r == 0 && sent == 5, "connectx", "connect + send on a UDP socket", r, e);

    struct tv t = {0, 300000};
    r = setsockopt(s, 0xffff, 0x1006 /* SO_RCVTIMEO */, &t, sizeof t); e = r ? *__error() : 0;
    long got = recv(s, buf, sizeof buf, 0);   // drain "hello" (if connectx worked)
    uint64_t t0 = mach_absolute_time();
    got = recv(s, buf, sizeof buf, 0);
    double waited = ms_since(t0);
    report(r == 0 && got < 0 && waited > 200 && waited < 1000, "rcvtimeo", "empty recv waits ~300 ms", r, (long)waited);

    t0 = mach_absolute_time();
    got = recv(s, buf, sizeof buf, 0x80 /* MSG_DONTWAIT */); e = *__error();
    waited = ms_since(t0);
    report(got < 0 && e == 35 && waited < 50, "dontwait", "empty recv(MSG_DONTWAIT) -> EAGAIN at once", e, (long)waited);

    int kq = kqueue(), missed = 0, rounds = 500;
    struct kev add = {s, -1 /* EVFILT_READ */, 1 | 0x20 /* EV_ADD|EV_CLEAR */, 0, 0, 0}, out;
    kevent(kq, &add, 1, 0, 0, 0);
    struct ts wait = {1, 0};
    struct sin dst = srv;
    int u = socket(2, 2, 17);
    long sendto(int, const void *, size_t, int, const void *, uint32_t);
    for (int i = 0; i < rounds; i++) {
        sendto(u, "p", 1, 0, &dst, sizeof dst);
        if (kevent(kq, 0, 0, &out, 1, &wait) != 1) missed++;
        while (recv(s, buf, sizeof buf, 0x80) > 0) ;
    }
    report(missed == 0, "kevent", "EV_CLEAR read events, 500 datagrams", rounds, missed);

    // recvmsg: sender address in Darwin form (sin_len 16), and per-packet metadata (control messages)
    // with Darwin levels/types: IP_RECVPKTINFO/IP_PKTINFO (26), IP_RECVTOS (27).
    struct msg { void *name; uint32_t namelen; struct iov *iov; int iovlen; void *control; uint32_t controllen; int flags; };
    struct cm { uint32_t len; int level, type; };
    long recvmsg(int, struct msg *, int); long sendmsg(int, const struct msg *, int);
    int one = 1;
    int p1 = setsockopt(s, 0, 26 /* IP_RECVPKTINFO */, &one, 4), p2 = setsockopt(s, 0, 27 /* IP_RECVTOS */, &one, 4);
    report(p1 == 0 && p2 == 0, "rcvopts", "setsockopt IP_RECVPKTINFO / IP_RECVTOS", p1, p2);
    struct sin peer; char ctl[256]; struct iov io = {buf, sizeof buf};
    sendto(u, "q", 1, 0, &dst, sizeof dst);
    struct msg m = {&peer, sizeof peer, &io, 1, ctl, sizeof ctl, 0};
    long n = recvmsg(s, &m, 0);
    report(n == 1 && peer.len == 16 && peer.family == 2 && m.namelen == 16, "rmsgname", "recvmsg sender sin_len/family", peer.len, peer.family);
    int pkt = 0, tos = 0;
    for (char *c = ctl; m.controllen && c + sizeof(struct cm) <= ctl + m.controllen; ) {
        struct cm *h = (struct cm *)c;
        if (h->len < sizeof *h) break;
        dprintf(1, "     cmsg level %d type %d len %u\n", h->level, h->type, h->len);
        if (h->level == 0 && h->type == 26) pkt = 1;
        if (h->level == 0 && h->type == 27) tos = 1;
        c += (h->len + 3) & ~3u;
    }
    report(pkt && tos, "rmsgctl", "control messages IP_PKTINFO(26) + IP_RECVTOS(27)", pkt, tos);

    // sendmsg with a control message (IP_TOS = 3 on Darwin): must be sent.
    struct { struct cm h; int v; } tctl = {{sizeof tctl, 0, 3}, 0};
    struct iov sio = {"r", 1};
    struct msg sm = {&dst, sizeof dst, &sio, 1, &tctl, sizeof tctl, 0};
    long sn = sendmsg(u, &sm, 0); e = sn < 0 ? *__error() : 0;
    report(sn == 1, "smsgctl", "sendmsg with IP_TOS control message", sn, e);
    // SO_SNDTIMEO/SO_RCVTIMEO with junk in the padding after tv_usec (Darwin timeval is long + int):
    // Darling passed it to Linux as is -> huge tv_usec -> EDOM (MacOBlox saw RakNet fail on this).
    struct { long sec; int usec; int pad; } tvj = {0, 200000, (int)0xdeadbeef};
    int t1 = setsockopt(s, 0xffff, 0x1005 /* SO_SNDTIMEO */, &tvj, 16), e1 = t1 ? *__error() : 0;
    int t2 = setsockopt(s, 0xffff, 0x1006 /* SO_RCVTIMEO */, &tvj, 16), e2 = t2 ? *__error() : 0;
    while (recv(s, buf, sizeof buf, 0x80) > 0) ;   // drain earlier datagrams
    t0 = mach_absolute_time(); got = recv(s, buf, sizeof buf, 0); waited = ms_since(t0);
    report(t1 == 0 && t2 == 0 && waited > 150 && waited < 600, "timeopad", "SO_SND/RCVTIMEO with junk padding", e1 * 1000 + e2, (long)waited);
    dprintf(1, "%d failure(s)\n", fails);
    return fails;
}
