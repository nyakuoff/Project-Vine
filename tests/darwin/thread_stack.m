// Darwin test (runs in Darling): a thread asking for a small stack gets at least 8 MiB (FMOD's
// audio threads overflowed inside Darling's RPC code with the sizes they request).
#include "../../shims/vine.h"
int printf(const char *, ...);
typedef struct { long sig; char opaque[56]; } pthread_attr_t;
typedef void *pthread_t;
int pthread_attr_init(pthread_attr_t *); int pthread_attr_setstacksize(pthread_attr_t *, size_t);
int pthread_create(pthread_t *, const pthread_attr_t *, void *(*)(void *), void *); int pthread_join(pthread_t, void **);
size_t pthread_get_stacksize_np(pthread_t); pthread_t pthread_self(void);
static void *run(void *p) { *(size_t *)p = pthread_get_stacksize_np(pthread_self()); return 0; }
int main(void) {
    pthread_attr_t a; pthread_t t; size_t got = 0;
    pthread_attr_init(&a);
    int st = pthread_attr_setstacksize(&a, 64 * 1024), bad = pthread_attr_setstacksize(&a, 1000);
    pthread_create(&t, &a, run, &got); pthread_join(t, 0);
    int ok = st == 0 && bad == 22 && got >= (8u << 20);
    printf("%s asked 64 KiB, thread got %zu KiB (set: %d, unaligned: %d)\n", ok ? "PASS" : "FAIL", got / 1024, st, bad);
    return !ok;
}
