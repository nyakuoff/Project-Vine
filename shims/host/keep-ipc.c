/* LD_PRELOAD for Darling's host programs `darling` and `darlingserver`.
 *
 * Darling gives its container a private SysV IPC namespace (the client unshares CLONE_NEWIPC,
 * darlingserver clones launchd with it). Mesa's software presentation hands frames to the X server
 * through MIT-SHM (SysV shared memory), which the X server cannot attach across IPC namespaces
 * ("MESA: error: Failed to attach to x11 shm"), so frames never appear. This keeps the host IPC
 * namespace; PID, mount and UTS isolation are unchanged. (User-approved trade-off, DECISIONS D9.)
 * Every other process removes the preload from its environment so Darwin programs don't carry it. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <sched.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>

static int active;

__attribute__((constructor)) static void keep_ipc_init(void) {
    char exe[4096];
    ssize_t n = readlink("/proc/self/exe", exe, sizeof exe - 1);
    exe[n > 0 ? n : 0] = 0;
    const char *base = strrchr(exe, '/') ? strrchr(exe, '/') + 1 : exe;
    active = !strcmp(base, "darling") || !strcmp(base, "darlingserver");
    if (!active) unsetenv("LD_PRELOAD");
}

int unshare(int flags) {
    static int (*real)(int);
    if (!real) real = (int (*)(int))dlsym(RTLD_NEXT, "unshare");
    return real(active ? flags & ~CLONE_NEWIPC : flags);
}

long syscall(long nr, ...) {
    static long (*real)(long, ...);
    if (!real) real = (long (*)(long, ...))dlsym(RTLD_NEXT, "syscall");
    va_list ap;
    va_start(ap, nr);
    long a[6];
    for (int i = 0; i < 6; i++) a[i] = va_arg(ap, long);
    va_end(ap);
    if (active && (nr == SYS_clone || nr == SYS_unshare)) a[0] &= ~(long)CLONE_NEWIPC;
    return real(nr, a[0], a[1], a[2], a[3], a[4], a[5]);
}
