// Darwin test (runs in Darling): cost of a POSIX cancellation point. Darling's cancellable syscalls
// (write, read, sendto, recvfrom, close, poll, select, ...) first ask darlingserver whether the thread
// was cancelled (dserver_rpc_pthread_canceled), seen in Roblox's in-game stack samples.
// Prints the time per write(2) through the cancellable and the $NOCANCEL entry.
#include "../../shims/vine.h"
int printf(const char *, ...);
int open(const char *, int, ...); long write(int, const void *, size_t);
long write_nocancel(int, const void *, size_t) __asm__("_write$NOCANCEL");
uint64_t mach_absolute_time(void);
typedef void *pthread_t; int pthread_create(pthread_t *, void *, void *(*)(void *), void *); unsigned sleep(unsigned);
static void *idle(void *a) { sleep(100); return 0; }
int main(void) {
    pthread_t t; pthread_create(&t, 0, idle, 0);   // Darling only asks darlingserver in threaded processes
    int fd = open("/dev/null", 1);
    uint64_t t0 = mach_absolute_time();
    for (int i = 0; i < 100000; i++) write(fd, "x", 1);
    double c = (mach_absolute_time() - t0) / 1e3 / 100000;
    t0 = mach_absolute_time();
    for (int i = 0; i < 100000; i++) write_nocancel(fd, "x", 1);
    double n = (mach_absolute_time() - t0) / 1e3 / 100000;
    printf("%s write in a threaded process: %.2f us (public name), %.2f us ($NOCANCEL)\n", c < 2 * n + 1 ? "PASS" : "FAIL", c, n);
    return c >= 2 * n + 1;
}
