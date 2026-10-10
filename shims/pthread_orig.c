// Darling's own pthread_mutex_lock/unlock for shims/pthread.c, which replaces those names in the
// libsystem_pthread wrapper (references there would bind to its own definitions). This helper links
// directly against the renamed original (libsystem_pthread.dylib.darling); the pointers are data,
// bound at load (no lazy stubs: this sits underneath libSystem).
int pthread_mutex_lock(void *);
int pthread_mutex_unlock(void *);
int (*vine_darling_mutex_lock)(void *) = pthread_mutex_lock;
int (*vine_darling_mutex_unlock)(void *) = pthread_mutex_unlock;
