#!/usr/bin/env bash
# Launch the macOS Roblox client under Darling (via tests/darling-ns.sh) and capture evidence.
# Usage: tests/run-roblox-darling.sh [seconds=150] [RobloxPlayer args...]
# Env:   VINE_DISPLAY=:0        show on a real display instead of a private Xvfb
#        VINE_OBJC_LENIENT=0    disable lenient ObjC forwarding (default on)
#        VINE_XTRACE=1          per-thread syscall trace into .work/darling-prefix/private/tmp/rbx.xtrace.*
# Output: logs/darling-roblox-<ts>.log (+ logs/screens/<ts>-<sec>s.png when headless)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T=${1:-150}; shift || true
TS=$(date +%Y%m%d-%H%M%S)
APP="$ROOT/.work/darling-prefix/Applications/RobloxPlayer.app"
[ -d "$APP" ] || cp -a --reflink=auto "$ROOT/artifacts/mac/RobloxPlayer.app" "$APP"
# Roblox's own renderer switch: GLSL 3.2 path (Mesa via Darling's CGL->EGL) instead of Metal.
mkdir -p "$APP/Contents/MacOS/ClientSettings"
cp "$ROOT/shims/ClientAppSettings.json" "$APP/Contents/MacOS/ClientSettings/ClientAppSettings.json"
mkdir -p /tmp/vine-mesa-cache "$ROOT/logs/screens"

XVFB=""
if [ -z "${VINE_DISPLAY:-}" ]; then
  for n in $(seq 90 99); do [ -e /tmp/.X11-unix/X$n ] || { DISP=:$n; break; }; done
  Xvfb "$DISP" -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & XVFB=$!
  sleep 1
else DISP=$VINE_DISPLAY; fi
echo "$DISP" > "$ROOT/.work/last-display"   # for helpers (x11-click.py, screenshots)

ENV=(MESA_SHADER_CACHE_DIR=/tmp/vine-mesa-cache DISPLAY="$DISP" VINE_OBJC_LENIENT="${VINE_OBJC_LENIENT:-1}")
[ -n "${VINE_ENV:-}" ] && ENV+=($VINE_ENV)   # extra env, e.g. VINE_ENV="GALLIUM_HUD=fps"
[ "${VINE_XTRACE:-0}" = 1 ] && ENV+=(XTRACE_NO_COLOR=1 XTRACE_LOG_FILE=/private/tmp/rbx.xtrace XTRACE_LOG_FILE_PER_THREAD=1
                                   DYLD_INSERT_LIBRARIES=/usr/lib/darling/libxtrace.dylib)
LOG="$ROOT/logs/darling-roblox-$TS.log"
# Fresh container, started by a throwaway command: darlingserver must not be a child of the timed run.
"$ROOT/tests/darling-ns.sh" --stop
# (darling-ns.sh boots new containers with null stdio)
timeout "$T" "$ROOT/tests/darling-ns.sh" shell env "${ENV[@]}" \
  /Applications/RobloxPlayer.app/Contents/MacOS/RobloxPlayer "$@" > "$LOG" 2>&1 &
RUN=$!
if [ -n "$XVFB" ]; then   # screenshots at 15 s, 45 s, then every 60 s
  for s in 15 45 $(seq 105 60 "$T"); do
    [ "$s" -lt "$T" ] || break
    sleep $(( s - ${prev:-0} )); prev=$s
    kill -0 $RUN 2>/dev/null || break
    import -display "$DISP" -window root "$ROOT/logs/screens/$TS-${s}s.png" 2>/dev/null
  done
fi
# Live state of every Darling process just before the deadline (Linux pid, Darwin pid, blocking point).
sleep $(( T - ${prev:-0} - 5 > 0 ? T - ${prev:-0} - 5 : 0 ))
for p in $(pgrep -f '^/Applications/|mldr'); do
  for t in /proc/$p/task/*; do
    printf '# live pid=%s darwin=%s tid=%s %s wchan=%s syscall=%s %s\n' "$p" "$(awk '/NSpid/{print $3}' /proc/$p/status)" \
      "${t##*/}" "$(awk '/State/{print $2}' $t/status)" "$(cat $t/wchan)" "$(cut -d' ' -f1 $t/syscall)" "$(tr '\0' ' ' < /proc/$p/cmdline | cut -c1-60)"
  done
done >> "$LOG" 2>/dev/null
wait $RUN; echo "# exit: $?" >> "$LOG"
"$ROOT/tests/darling-ns.sh" --stop
[ -n "$XVFB" ] && kill $XVFB
echo "$LOG"
