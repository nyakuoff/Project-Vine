// Wrapper for /usr/lib/system/libsystem_pthread.dylib: condition variables on Linux futexes.
//
// Darling implements the waiting side of pthread condition variables (psynch) in darlingserver.
// In game, Roblox's waits failed there ~90 times a second ("PSYNCH: psync_cvwait; invalid sequence
// numbers" in dserver.log, 9217 in one session), so waiting threads missed their wakeups or spun,
// and every wait/signal was a server round trip (~20-30 fps, stalls). Finding credited to MacOBlox
// (darling_fixes.c), which also replaced them. Vine's version: the classic futex condition variable.
//   cond layout (48 bytes, Darwin's pthread_cond_t): long sig; uint32 seq; uint32 waiters; unused.
//   wait: read seq, count in, unlock, futex-wait while seq is unchanged, count out, relock.
//   signal/broadcast: seq++, wake 1 / all (skipped when nobody waits).
// A signal between unlock and sleep changes seq, so the sleep returns at once: no lost wakeups.
// Spurious wakeups are allowed by POSIX. Not cancellation points (Roblox does not cancel threads).
// Links only against the wrapped library (no libSystem: this sits underneath it).
#include <stdint.h>
#include <stddef.h>

typedef struct { long sig; volatile uint32_t seq, waiters; char unused[32]; } vine_cond;
struct timespec { long tv_sec, tv_nsec; };
int pthread_mutex_lock(void *);
int pthread_mutex_unlock(void *);
// Called through data pointers (bound at load), as in kernel.c.
static int (*volatile p_lock)(void *) = pthread_mutex_lock;
static int (*volatile p_unlock)(void *) = pthread_mutex_unlock;

#define COND_SIG 0x434f4e44   /* 'COND', Darwin's initialized signature */
enum { FUTEX_WAIT = 0, FUTEX_WAKE = 1, FUTEX_WAIT_BITSET = 9, FUTEX_PRIVATE = 128, FUTEX_CLOCK_REALTIME = 256 };
enum { L_ETIMEDOUT = 110, D_ETIMEDOUT = 60, D_EINVAL = 22 };

static long futex(volatile uint32_t *w, long op, long val, const struct timespec *t, long bits) {
    long r;
    register long r10 __asm__("r10") = (long)t;
    register long r8 __asm__("r8") = 0;
    register long r9 __asm__("r9") = bits;
    __asm__ volatile("syscall" : "=a"(r) : "a"(202L), "D"(w), "S"(op | FUTEX_PRIVATE), "d"(val), "r"(r10), "r"(r8), "r"(r9)
                     : "rcx", "r11", "memory");
    return r;
}

int pthread_cond_init(vine_cond *c, const void *attr) {
    if (!c) return D_EINVAL;
    c->sig = COND_SIG; c->seq = 0; c->waiters = 0;
    return 0;
}
int pthread_cond_destroy(vine_cond *c) { if (c) c->sig = 0; return 0; }

// abs: CLOCK_REALTIME deadline; rel: relative timeout; neither: wait forever.
static int cond_wait(vine_cond *c, void *m, const struct timespec *abs, const struct timespec *rel) {
    if (!c || !m) return D_EINVAL;
    uint32_t seq = __atomic_load_n(&c->seq, __ATOMIC_ACQUIRE);
    __atomic_add_fetch(&c->waiters, 1, __ATOMIC_ACQ_REL);
    p_unlock(m);
    long r = abs ? futex(&c->seq, FUTEX_WAIT_BITSET | FUTEX_CLOCK_REALTIME, seq, abs, 0xffffffff)
                 : futex(&c->seq, FUTEX_WAIT, seq, rel, 0);
    __atomic_sub_fetch(&c->waiters, 1, __ATOMIC_ACQ_REL);
    p_lock(m);
    return r == -L_ETIMEDOUT ? D_ETIMEDOUT : 0;
}
int pthread_cond_wait(vine_cond *c, void *m) { return cond_wait(c, m, 0, 0); }
int pthread_cond_timedwait(vine_cond *c, void *m, const struct timespec *t) {
    if (!t || t->tv_nsec < 0 || t->tv_nsec >= 1000000000) return D_EINVAL;
    return cond_wait(c, m, t, 0);
}
int pthread_cond_timedwait_relative_np(vine_cond *c, void *m, const struct timespec *t) {
    if (t && (t->tv_nsec < 0 || t->tv_nsec >= 1000000000)) return D_EINVAL;
    return cond_wait(c, m, 0, t);
}
int cond_wait_nocancel(vine_cond *, void *) __asm__("_pthread_cond_wait$NOCANCEL");
int cond_wait_nocancel(vine_cond *c, void *m) { return cond_wait(c, m, 0, 0); }
int cond_timedwait_nocancel(vine_cond *, void *, const struct timespec *) __asm__("_pthread_cond_timedwait$NOCANCEL");
int cond_timedwait_nocancel(vine_cond *c, void *m, const struct timespec *t) { return pthread_cond_timedwait(c, m, t); }

static int cond_wake(vine_cond *c, long n) {
    if (!c) return D_EINVAL;
    __atomic_add_fetch(&c->seq, 1, __ATOMIC_ACQ_REL);
    if (__atomic_load_n(&c->waiters, __ATOMIC_ACQUIRE)) futex(&c->seq, FUTEX_WAKE, n, 0, 0);
    return 0;
}
int pthread_cond_signal(vine_cond *c) { return cond_wake(c, 1); }
int pthread_cond_broadcast(vine_cond *c) { return cond_wake(c, 0x7fffffff); }
// ponytail: wakes one waiter, not necessarily that thread; fine for a hint-style API nobody here relies on
int pthread_cond_signal_thread_np(vine_cond *c, void *thread) { return cond_wake(c, thread ? 0x7fffffff : 1); }
