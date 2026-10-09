// Regression test (runs inside Darling): system DNS resolution as Roblox/curl use it
// (getaddrinfo with AI_ADDRCONFIG / per-family, from a worker thread, res_init).
#include "../../shims/vine.h"
int printf(const char *, ...);
struct addrinfo { int ai_flags, ai_family, ai_socktype, ai_protocol; unsigned ai_addrlen;
                  char *ai_canonname; void *ai_addr; struct addrinfo *ai_next; };
int getaddrinfo(const char *, const char *, const struct addrinfo *, struct addrinfo **);
const char *gai_strerror(int);
int res_9_init(void);
typedef struct { long sig; char opaque[56]; } pthread_t_;
int pthread_create(void **, void *, void *(*)(void *), void *);
int pthread_join(void *, void **);
#define AI_ADDRCONFIG 0x400
static int bad;
static void try(const char *what, const char *host, int family, int flags) {
    struct addrinfo *res = 0, h = {0};
    h.ai_family = family; h.ai_socktype = 1; h.ai_flags = flags;
    int rc = getaddrinfo(host, "443", &h, &res);
    printf("%s %-28s %s -> %d %s\n", rc ? "FAIL" : "PASS", what, host, rc, rc ? gai_strerror(rc) : "");
    bad += rc != 0;
}
static void *worker(void *a) {
    try("thread unspec", "clientsettingscdn.roblox.com", 0, 0);
    try("thread ADDRCONFIG", "clientsettingscdn.roblox.com", 0, AI_ADDRCONFIG);
    return 0;
}
int main(void) {
    printf("res_9_init -> %d\n", res_9_init());
    try("unspec", "www.roblox.com", 0, 0);
    try("inet", "www.roblox.com", 2, 0);
    try("inet6", "www.roblox.com", 30, 0);
    try("ADDRCONFIG", "www.roblox.com", 0, AI_ADDRCONFIG);
    void *t; pthread_create(&t, 0, worker, 0); pthread_join(t, 0);
    return bad;
}
