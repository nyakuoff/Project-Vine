// Darling's own host_statistics/host_statistics64 for shims/kernel.c, which replaces those names in
// the libsystem_kernel wrapper. Linked directly against the renamed original; data pointers, bound
// at load (no lazy stubs: this sits underneath libSystem).
int host_statistics(unsigned, int, unsigned *, unsigned *);
int host_statistics64(unsigned, int, unsigned *, unsigned *);
int (*vine_darling_host_statistics)(unsigned, int, unsigned *, unsigned *) = host_statistics;
int (*vine_darling_host_statistics64)(unsigned, int, unsigned *, unsigned *) = host_statistics64;
