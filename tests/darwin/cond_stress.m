// Darwin test (runs in Darling): pthread condition variables — correctness under contention, timed
// waits, broadcast — without darlingserver's psynch (dserver.log must gain no psync_cvwait errors).
#include "../../shims/vine.h"
int printf(const char *, ...);
typedef struct { long sig; char opaque[56]; } pthread_mutex_t;
typedef struct { long sig; char opaque[40]; } pthread_cond_t;
typedef void *pthread_t;
struct timespec { long tv_sec, tv_nsec; };
int pthread_mutex_init(pthread_mutex_t *, void *); int pthread_mutex_lock(pthread_mutex_t *); int pthread_mutex_unlock(pthread_mutex_t *);
int pthread_cond_init(pthread_cond_t *, void *); int pthread_cond_wait(pthread_cond_t *, pthread_mutex_t *);
int pthread_cond_timedwait(pthread_cond_t *, pthread_mutex_t *, const struct timespec *);
int pthread_cond_signal(pthread_cond_t *); int pthread_cond_broadcast(pthread_cond_t *);
int pthread_create(pthread_t *, void *, void *(*)(void *), void *); int pthread_join(pthread_t, void **);
int clock_gettime(int, struct timespec *); uint64_t mach_absolute_time(void);

#define ITEMS 200000
#define CAP 16
static pthread_mutex_t mu; static pthread_cond_t not_empty, not_full = {0x3CB0B1BB};   // static initializer form too
static long queue[CAP], head, tail, count, produced, consumed_sum, consumed;
static void *producer(void *a) {
    for (;;) {
        pthread_mutex_lock(&mu);
        while (count == CAP && produced < ITEMS) pthread_cond_wait(&not_full, &mu);
        if (produced == ITEMS) { pthread_mutex_unlock(&mu); return 0; }
        queue[tail++ % CAP] = ++produced; count++;
        pthread_cond_signal(&not_empty);
        pthread_mutex_unlock(&mu);
    }
}
static void *consumer(void *a) {
    for (;;) {
        pthread_mutex_lock(&mu);
        while (count == 0 && consumed < ITEMS) pthread_cond_wait(&not_empty, &mu);
        if (consumed == ITEMS) { pthread_mutex_unlock(&mu); return 0; }
        consumed_sum += queue[head++ % CAP]; count--; consumed++;
        if (consumed == ITEMS) pthread_cond_broadcast(&not_empty);
        pthread_cond_signal(&not_full);
        pthread_mutex_unlock(&mu);
    }
}
static pthread_cond_t gate; static int open_, woke;
static void *waiter(void *a) {
    pthread_mutex_lock(&mu);
    while (!open_) pthread_cond_wait(&gate, &mu);
    woke++;
    pthread_mutex_unlock(&mu);
    return 0;
}
int main(void) {
    pthread_mutex_init(&mu, 0); pthread_cond_init(&not_empty, 0); pthread_cond_init(&gate, 0);
    pthread_t t[8];
    uint64_t t0 = mach_absolute_time();
    for (int i = 0; i < 4; i++) pthread_create(&t[i], 0, producer, 0);
    for (int i = 4; i < 8; i++) pthread_create(&t[i], 0, consumer, 0);
    for (int i = 0; i < 8; i++) pthread_join(t[i], 0);
    long want = (long)ITEMS * (ITEMS + 1) / 2;
    int ok1 = consumed == ITEMS && consumed_sum == want;
    printf("%s queue: %ld items through 4x4 threads in %.0f ms\n", ok1 ? "PASS" : "FAIL", consumed, (mach_absolute_time() - t0) / 1e6);

    struct timespec now; clock_gettime(0 /* CLOCK_REALTIME */, &now);
    struct timespec dl = {now.tv_sec, now.tv_nsec + 50000000};
    if (dl.tv_nsec >= 1000000000) { dl.tv_sec++; dl.tv_nsec -= 1000000000; }
    pthread_cond_t idle; pthread_cond_init(&idle, 0);
    pthread_mutex_lock(&mu);
    t0 = mach_absolute_time();
    int r = pthread_cond_timedwait(&idle, &mu, &dl);
    double ms = (mach_absolute_time() - t0) / 1e6;
    pthread_mutex_unlock(&mu);
    int ok2 = r == 60 && ms > 40 && ms < 150;
    printf("%s timedwait: %d (ETIMEDOUT=60) after %.0f ms (want ~50)\n", ok2 ? "PASS" : "FAIL", r, ms);

    for (int i = 0; i < 8; i++) pthread_create(&t[i], 0, waiter, 0);
    struct timespec nap = {0, 100000000}; int nanosleep(const struct timespec *, struct timespec *); nanosleep(&nap, 0);
    pthread_mutex_lock(&mu); open_ = 1; pthread_cond_broadcast(&gate); pthread_mutex_unlock(&mu);
    for (int i = 0; i < 8; i++) pthread_join(t[i], 0);
    int ok3 = woke == 8;
    printf("%s broadcast woke %d/8\n", ok3 ? "PASS" : "FAIL", woke);
    return !ok1 + !ok2 + !ok3;
}
