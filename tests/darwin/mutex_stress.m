// Darwin test (runs in Darling): contended pthread mutexes — exact count under 8 threads, recursive
// mutexes — with waits off darlingserver (tests/darwin/mutex_stress.sh compares its CPU time).
#include "../../shims/vine.h"
int printf(const char *, ...);
typedef struct { long sig; char opaque[56]; } pthread_mutex_t;
typedef struct { long sig; char opaque[8]; } pthread_mutexattr_t;
typedef void *pthread_t;
int pthread_mutex_init(pthread_mutex_t *, const pthread_mutexattr_t *); int pthread_mutex_lock(pthread_mutex_t *);
int pthread_mutex_unlock(pthread_mutex_t *); int pthread_mutex_trylock(pthread_mutex_t *);
int pthread_mutexattr_init(pthread_mutexattr_t *); int pthread_mutexattr_settype(pthread_mutexattr_t *, int);
int pthread_create(pthread_t *, void *, void *(*)(void *), void *); int pthread_join(pthread_t, void **);
uint64_t mach_absolute_time(void);
static pthread_mutex_t mu; static volatile long counter;
static void *worker(void *a) {
    for (int i = 0; i < 100000; i++) {
        pthread_mutex_lock(&mu);
        long c = counter; for (volatile int k = 0; k < 20; k++) ; counter = c + 1;   // hold it a bit
        pthread_mutex_unlock(&mu);
    }
    return 0;
}
int main(void) {
    pthread_mutex_init(&mu, 0);
    pthread_t t[8];
    uint64_t t0 = mach_absolute_time();
    for (int i = 0; i < 8; i++) pthread_create(&t[i], 0, worker, 0);
    for (int i = 0; i < 8; i++) pthread_join(t[i], 0);
    int ok1 = counter == 800000;
    printf("%s contended: count %ld (want 800000) in %.0f ms\n", ok1 ? "PASS" : "FAIL", counter, (mach_absolute_time() - t0) / 1e6);
    pthread_mutexattr_t at; pthread_mutex_t rm;
    pthread_mutexattr_init(&at); pthread_mutexattr_settype(&at, 2 /* PTHREAD_MUTEX_RECURSIVE */);
    pthread_mutex_init(&rm, &at);
    int a = pthread_mutex_lock(&rm), b = pthread_mutex_lock(&rm), c = pthread_mutex_unlock(&rm), d = pthread_mutex_unlock(&rm), e = pthread_mutex_trylock(&rm);
    int ok2 = !a && !b && !c && !d && !e;
    printf("%s recursive: lock/lock/unlock/unlock/trylock = %d %d %d %d %d\n", ok2 ? "PASS" : "FAIL", a, b, c, d, e);
    return !ok1 + !ok2;
}
