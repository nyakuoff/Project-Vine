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

ENV=(MESA_SHADER_CACHE_DIR=/tmp/vine-mesa-cache DISPLAY="$DISP" VINE_OBJC_LENIENT="${VINE_OBJC_LENIENT:-1}"
     VINE_TRACE_UDP="${VINE_TRACE_UDP:-1}")   # first game join's UDP handshake in the log (shims/kernel.c)
# Video memory for Roblox's graphics budget (IOFBMemorySize; shims/frameworks.m): the largest GPU's
# VRAM (amdgpu sysfs); unset -> 2 GiB.
VRAM=$(cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | sort -n | tail -1)
[ -n "$VRAM" ] && ENV+=(VINE_VRAM_BYTES="$VRAM")
[ -n "${VINE_ENV:-}" ] && ENV+=($VINE_ENV)   # extra env, e.g. VINE_ENV="GALLIUM_HUD=fps"
[ "${VINE_XTRACE:-0}" = 1 ] && ENV+=(XTRACE_NO_COLOR=1 XTRACE_LOG_FILE=/private/tmp/rbx.xtrace XTRACE_LOG_FILE_PER_THREAD=1
                                   DYLD_INSERT_LIBRARIES=/usr/lib/darling/libxtrace.dylib)
LOG="$ROOT/logs/darling-roblox-$TS.log"
# Game audio is played on the host from a FIFO (Darling's PulseAudio output path crashes; see
# shims/frameworks.m). VINE_DARLING_AUDIO=1 keeps Darling's path.
FIFO=""
if [ "${VINE_DARLING_AUDIO:-0}" != 1 ] && command -v pacat >/dev/null; then
  FIFO="${XDG_RUNTIME_DIR:-/tmp}/vine-audio-$$"; rm -f "$FIFO" "$FIFO.fmt"; mkfifo -m 600 "$FIFO"
  "$ROOT/tests/host-audio.sh" "$FIFO" & PLAYER=$!
  ENV+=(VINE_AUDIO_FIFO="/Volumes/SystemRoot$FIFO")
fi
# Fresh container, started by a throwaway command: darlingserver must not be a child of the timed run.
"$ROOT/tests/darling-ns.sh" --stop
# Start-up render throttle off (finding credited to MacOBlox; patches/startup_throttle.py). Vine's own
# copy of the app only; VINE_NO_THROTTLE_PATCH=1 restores the original instruction.
python3 "$ROOT/patches/startup_throttle.py" "$APP/Contents/MacOS/RobloxPlayer" \
  $([ "${VINE_NO_THROTTLE_PATCH:-0}" = 1 ] && echo --undo) > /dev/null
# Join games over RakNet: Roblox's newer RbxTransport fails under Darling ~10 s after connecting
# (error 256). Finding credited to MacOBlox; patches/raknet_transport.py. VINE_RBXTRANSPORT=1 undoes it.
echo "raknet transport patch: $(python3 "$ROOT/patches/raknet_transport.py" "$APP/Contents/MacOS/RobloxPlayer" \
  $([ "${VINE_RBXTRANSPORT:-0}" = 1 ] && echo --undo))" >&2
# (darling-ns.sh boots new containers with null stdio)
timeout "$T" "$ROOT/tests/darling-ns.sh" shell env "${ENV[@]}" \
  /Applications/RobloxPlayer.app/Contents/MacOS/RobloxPlayer "$@" > "$LOG" 2>&1 &
RUN=$!; SECONDS=0
# Sleep until second $1 of the run, returning early (status 1) once Roblox has quit.
until_s() { while kill -0 $RUN 2>/dev/null; do [ $SECONDS -lt $1 ] || return 0; sleep 1; done; return 1; }
if [ -n "$XVFB" ]; then   # screenshots at 15 s, 45 s, then every 60 s
  for s in 15 45 $(seq 105 60 "$T"); do
    [ "$s" -lt "$T" ] && until_s "$s" || break
    import -display "$DISP" -window root "$ROOT/logs/screens/$TS-${s}s.png" 2>/dev/null
  done
fi
# Wait for Roblox to quit (the container is stopped right after) or the deadline; if it is still
# running 5 s before the deadline, log the live state of every Darling process (Linux pid, Darwin
# pid, blocking point).
until_s $(( T - 5 ))
kill -0 $RUN 2>/dev/null && for p in $(pgrep -f '^/Applications/|mldr'); do
  for t in /proc/$p/task/*; do
    printf '# live pid=%s darwin=%s tid=%s %s wchan=%s syscall=%s %s\n' "$p" "$(awk '/NSpid/{print $3}' /proc/$p/status)" \
      "${t##*/}" "$(awk '/State/{print $2}' $t/status)" "$(cat $t/wchan)" "$(cut -d' ' -f1 $t/syscall)" "$(tr '\0' ' ' < /proc/$p/cmdline | cut -c1-60)"
  done
done >> "$LOG" 2>/dev/null
wait $RUN; echo "# exit: $?" >> "$LOG"
"$ROOT/tests/darling-ns.sh" --stop
[ -n "$XVFB" ] && kill $XVFB
[ -n "$FIFO" ] && { rm -f "$FIFO" "$FIFO.fmt"; pkill -P $PLAYER 2>/dev/null; kill $PLAYER 2>/dev/null; }
echo "$LOG"
