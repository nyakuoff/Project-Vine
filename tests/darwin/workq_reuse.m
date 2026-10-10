// Workqueue thread reuse must not grow the stack. Darling's workq_kernreturn re-entered
// _start_wqthread without resetting the stack pointer, so each reuse of a parked GCD worker left
// ~580 B behind: SIGSEGV after ~900 jobs on one thread (Roblox crashed right after joining a game).
// Runs 3000 sequential jobs (each one parks the worker, the next reuses it) and checks that the
// stack depth of the job block stays put on every thread.
#include <stdint.h>
int printf(const char *, ...);
typedef void *pthread_t, *dispatch_queue_t, *dispatch_semaphore_t;
pthread_t pthread_self(void);
dispatch_queue_t dispatch_get_global_queue(long qos, unsigned long flags);
void dispatch_async(dispatch_queue_t q, void (^block)(void));
dispatch_semaphore_t dispatch_semaphore_create(long value);
long dispatch_semaphore_signal(dispatch_semaphore_t s);
long dispatch_semaphore_wait(dispatch_semaphore_t s, uint64_t timeout);

#define MAXT 64
static pthread_t tid[MAXT];
static uintptr_t lo[MAXT], hi[MAXT];
static int nt, uses[MAXT];

int main(void) {
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    for (int i = 0; i < 3000; i++) {
        dispatch_async(dispatch_get_global_queue(0x15, 0), ^{
            volatile char here;
            uintptr_t sp = (uintptr_t)&here;
            pthread_t me = pthread_self();
            int k = 0;
            while (k < nt && tid[k] != me) k++;
            if (k == nt && nt < MAXT) { tid[nt] = me; lo[nt] = hi[nt] = sp; nt++; }
            if (k < MAXT) {
                if (sp < lo[k]) lo[k] = sp;
                if (sp > hi[k]) hi[k] = sp;
                uses[k]++;
            }
            dispatch_semaphore_signal(done);
        });
        dispatch_semaphore_wait(done, ~0ull);
    }
    int bad = 0, most = 0;
    for (int k = 0; k < nt; k++) {
        if (uses[k] > most) most = uses[k];
        if (hi[k] - lo[k] > 16384) {
            printf("FAIL thread %d: %d jobs, stack drifted %lu bytes\n", k, uses[k], (unsigned long)(hi[k] - lo[k]));
            bad = 1;
        }
    }
    printf("%s: %d threads, busiest ran %d jobs\n", bad ? "FAIL" : "PASS", nt, most);
    return bad;
}
