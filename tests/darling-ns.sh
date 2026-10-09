#!/usr/bin/env bash
# Run the unpacked Darling release without installing it: an unprivileged user+mount
# namespace overlays .work/darling-root/usr onto /usr (visible only inside the namespace).
# One long-lived holder namespace is reused so every call joins the same Darling container.
# Usage: tests/darling-ns.sh [darling args...]   e.g. tests/darling-ns.sh shell uname -a
#        tests/darling-ns.sh --stop               shut Darling down and drop the namespace
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DR="$ROOT/.work/darling-root"
PIDF="$ROOT/.work/darling-ns.pid"
[ -x "$DR/usr/bin/darling" ] || { echo "unpack Darling into $DR first (see README)" >&2; exit 2; }
export DPREFIX="${DPREFIX:-$ROOT/.work/darling-prefix}"

# The holder is valid only if it is our "sleep infinity" AND lives in a different user namespace
# than this script (a recycled pid must never make --stop target the host namespace).
holder() {
  local h; h=$(cat "$PIDF" 2>/dev/null) || return 0
  [ -n "$h" ] && [ "$( { tr '\0' ' ' < /proc/$h/cmdline; } 2>/dev/null)" = "sleep infinity " ] &&
    [ "$(readlink /proc/$h/ns/user)" != "$(readlink /proc/self/ns/user)" ] && echo "$h"
  return 0
}
enter() { nsenter --target "$(holder)" --user --mount --preserve-credentials -- "$@"; }

if [ "${1:-}" = --stop ]; then
  if [ -n "$(holder)" ]; then
    H=$(holder); NS=$(readlink /proc/$H/ns/user)
    [ -n "$NS" ] && [ "$NS" != "$(readlink /proc/self/ns/user)" ] || { echo "refusing: bad namespace" >&2; exit 1; }
    timeout 20 nsenter --target "$H" --user --mount --preserve-credentials -- /usr/bin/darling shutdown >/dev/null 2>&1 || true
    # anything left in our user namespace or one nested in it is ours (wedged container, launchd,
    # orphaned Darwin processes); ns-procs.py never returns processes of the caller's namespace
    for p in $(python3 "$ROOT/tests/ns-procs.py" "$NS" --prefix "$DPREFIX"); do kill -9 "$p" 2>/dev/null; done
  fi
  for p in $(python3 "$ROOT/tests/ns-procs.py" none --prefix "$DPREFIX"); do kill -9 "$p" 2>/dev/null; done
  rm -f "$PIDF" "$DPREFIX/.init.pid" "$DPREFIX/.darlingserver.sock"; exit 0   # stale ones make darling join a dead container
fi

# Vine shim layer (shims/build.sh) sits above Darling when present.
SHIMS=""; [ -d "$ROOT/.work/vine-overlay/usr" ] && SHIMS="$ROOT/.work/vine-overlay/usr:"
if [ -z "$(holder)" ]; then
  chmod u+s "$DR/usr/bin/darling"   # owned by us = owned by root inside the namespace
  unshare --user --map-root-user --mount --propagation private -- bash -c '
    mount -t overlay overlay -o "lowerdir=$2$1/usr:/usr" /usr && exec sleep infinity' _ "$DR" "$SHIMS" \
    </dev/null >/dev/null 2>&1 &
  echo $! > "$PIDF"
  sleep 0.5
  # Boot the container with null stdio: darlingserver/launchd inherit the first client's fds and
  # would otherwise hold the caller's pipe open forever.
  # keep-ipc.so: the container keeps the host SysV IPC namespace (X11 MIT-SHM; shims/host/keep-ipc.c).
  # (LD_PRELOAD splits on spaces and the project path may contain one: use a per-user runtime path)
  KEEP_IPC="${XDG_RUNTIME_DIR:-/tmp}/vine-keep-ipc.so"
  [ "$KEEP_IPC" -nt "$ROOT/shims/host/keep-ipc.c" ] || gcc -shared -fPIC -O2 -o "$KEEP_IPC" "$ROOT/shims/host/keep-ipc.c" -ldl
  # Darling's libkqueue walks a map sized to the hard RLIMIT_NOFILE on every close() (under a global
  # lock); hosts default to 1048576, which made teardown/transitions take seconds. 65536 is ample.
  NOFILE=${VINE_NOFILE:-65536}
  enter bash -c 'ulimit -Sn "$1" 2>/dev/null; ulimit -Hn "$1"; exec env LD_PRELOAD="$2" /usr/bin/darling shell true' _ "$NOFILE" "$KEEP_IPC" </dev/null >/dev/null 2>&1 || true
fi
enter /usr/bin/darling "$@"
