// Darwin test (runs in Darling): os_log is off and nearly free (Roblox's workers spent most of their
// time formatting os_log messages into ASL). 100k _os_log_impl calls on the default log.
#include "../../shims/vine.h"
int printf(const char *, ...);
extern struct os_log_s _os_log_default;
_Bool os_log_type_enabled(void *, unsigned char);
void _os_log_impl(void *, void *, unsigned char, const char *, unsigned char *, unsigned);
extern char __dso_handle;
uint64_t mach_absolute_time(void);
int main(void) {
    int en = os_log_type_enabled(&_os_log_default, 0 /* default */) + os_log_type_enabled(&_os_log_default, 2 /* debug */);
    unsigned char buf[2] = {0, 0};
    uint64_t t0 = mach_absolute_time();
    for (int i = 0; i < 100000; i++) _os_log_impl(&__dso_handle, &_os_log_default, 0, "vine test %d", buf, 2);
    double us = (mach_absolute_time() - t0) / 1e3 / 100000;
    int ok = !en && us < 1;
    printf("%s os_log enabled=%d, %.3f us per _os_log_impl call\n", ok ? "PASS" : "FAIL", en, us);
    return !ok;
}
