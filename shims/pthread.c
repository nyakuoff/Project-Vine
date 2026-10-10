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
// Darling's own mutex lock/unlock (this file replaces those names; see pthread_orig.c).
extern int (*vine_darling_mutex_lock)(void *), (*vine_darling_mutex_unlock)(void *);
#define p_lock vine_darling_mutex_lock
#define p_unlock vine_darling_mutex_unlock

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

int vine_mutex_lock(void *m) __asm__("_pthread_mutex_lock");
int vine_mutex_unlock(void *m) __asm__("_pthread_mutex_unlock");
// abs: CLOCK_REALTIME deadline; rel: relative timeout; neither: wait forever.
static int cond_wait(vine_cond *c, void *m, const struct timespec *abs, const struct timespec *rel) {
    if (!c || !m) return D_EINVAL;
    uint32_t seq = __atomic_load_n(&c->seq, __ATOMIC_ACQUIRE);
    __atomic_add_fetch(&c->waiters, 1, __ATOMIC_ACQ_REL);
    vine_mutex_unlock(m);
    long r = abs ? futex(&c->seq, FUTEX_WAIT_BITSET | FUTEX_CLOCK_REALTIME, seq, abs, 0xffffffff)
                 : futex(&c->seq, FUTEX_WAIT, seq, rel, 0);
    __atomic_sub_fetch(&c->waiters, 1, __ATOMIC_ACQ_REL);
    vine_mutex_lock(m);
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

// Contended mutexes. Darling waits for a busy mutex in darlingserver (psynch_mutexwait /
// psynch_mutexdrop RPCs, seen in stack samples; darlingserver ~33% of a core in game). Finding
// credited to MacOBlox. Here a busy lock spins briefly, then sleeps on a futex word chosen by the
// mutex address; unlock wakes that word's sleepers. Taking and releasing the mutex itself stay
// Darling's (trylock/unlock), so ownership, recursion and types are unchanged; a lock still busy
// after 10 s falls back to Darling's wait (error-checking mutexes then report EDEADLK).
int pthread_mutex_trylock(void *);
static int (*volatile p_trylock)(void *) = pthread_mutex_trylock;
static struct { volatile uint32_t seq, waiters; } mbucket[256];
enum { D_EBUSY = 16 };
static inline unsigned mhash(void *m) { uintptr_t a = (uintptr_t)m; return (unsigned)((a >> 4) ^ (a >> 12)) & 255; }
static uint64_t now_ns(void) {
    struct timespec t; long r;
    __asm__ volatile("syscall" : "=a"(r) : "a"(228L), "D"(1L /* CLOCK_MONOTONIC */), "S"(&t) : "rcx", "r11", "memory");
    return (uint64_t)t.tv_sec * 1000000000u + t.tv_nsec;
}
int vine_mutex_lock(void *m) {
    int r = p_trylock(m);
    if (r != D_EBUSY) return r;
    for (int i = 0; i < 64; i++) {   // brief spin: most holds are short
        __asm__ volatile("pause");
        if ((r = p_trylock(m)) != D_EBUSY) return r;
    }
    unsigned b = mhash(m);
    uint64_t start = now_ns();
    struct timespec nap = {0, 10000000};   // 10 ms safety re-check
    for (;;) {
        uint32_t seq = __atomic_load_n(&mbucket[b].seq, __ATOMIC_SEQ_CST);
        __atomic_add_fetch(&mbucket[b].waiters, 1, __ATOMIC_SEQ_CST);
        r = p_trylock(m);
        if (r != D_EBUSY) { __atomic_sub_fetch(&mbucket[b].waiters, 1, __ATOMIC_SEQ_CST); return r; }
        futex(&mbucket[b].seq, FUTEX_WAIT, seq, &nap, 0);
        __atomic_sub_fetch(&mbucket[b].waiters, 1, __ATOMIC_SEQ_CST);
        if ((r = p_trylock(m)) != D_EBUSY) return r;
        if (now_ns() - start > 10000000000ull) return p_lock(m);   // Darling's own wait
    }
}
int vine_mutex_unlock(void *m) {
    int r = p_unlock(m);
    unsigned b = mhash(m);
    if (__atomic_load_n(&mbucket[b].waiters, __ATOMIC_SEQ_CST)) {
        __atomic_add_fetch(&mbucket[b].seq, 1, __ATOMIC_SEQ_CST);
        futex(&mbucket[b].seq, FUTEX_WAKE, 0x7fffffff, 0, 0);
    }
    return r;
}
