// Wrapper for /usr/lib/system/libsystem_trace.dylib: os_log off.
// Darling's os_log_type_enabled returns true for every type (debug included) and _os_log_impl formats
// each message to text and sends it through ASL, synchronously on the caller's thread. In game,
// Roblox's busiest worker threads were mostly inside _os_log_impl -> sbuf_printf / vasprintf /
// asl_msg_set_key_val_op (tests/profile.sh). macOS defers formatting and keeps no debug/info by
// default; under Vine nobody reads these logs (Roblox writes its own log files), so nothing is
// logged. Links only against the wrapped library (no libSystem: this sits underneath it).
typedef unsigned char os_log_type_t;
_Bool os_log_type_enabled(void *log, os_log_type_t type) { return 0; }
void _os_log_impl(void *dso, void *log, os_log_type_t type, const char *format, unsigned char *buf, unsigned size) {}
