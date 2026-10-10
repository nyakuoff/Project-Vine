// Darwin test (runs in Darling): accuracy and darlingserver cost of short sleeps (frame pacing).
// Prints the average time a 1 ms nanosleep and usleep(1000) really take. Exit 1 if over 1.5 ms.
#include "../../shims/vine.h"
int printf(const char *, ...);
struct timespec { long tv_sec, tv_nsec; };
int nanosleep(const struct timespec *, struct timespec *); int usleep(unsigned);
uint64_t mach_absolute_time(void);
int main(void) {
    struct timespec ms = {0, 1000000};
    uint64_t t0 = mach_absolute_time();
    for (int i = 0; i < 500; i++) nanosleep(&ms, 0);
    double ns = (mach_absolute_time() - t0) / 500e6;
    t0 = mach_absolute_time();
    for (int i = 0; i < 500; i++) usleep(1000);
    double us = (mach_absolute_time() - t0) / 500e6;
    int ok = ns < 1.5 && us < 1.5;
    printf("%s 1 ms nanosleep takes %.3f ms, usleep(1000) %.3f ms\n", ok ? "PASS" : "FAIL", ns, us);
    return !ok;
}
