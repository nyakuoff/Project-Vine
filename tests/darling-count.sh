#!/usr/bin/env bash
# Count calls to Darwin functions in a running Roblox (under tests/run-roblox-darling.sh) for N seconds.
# Usage: tests/darling-count.sh <seconds> <image-path-in-darling-root>:<symbol> ...
#   e.g. tests/darling-count.sh 10 System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL:_CGLFlushDrawable
# A symbol may be an ObjC method name as llvm-nm prints it, e.g. "-[NSOpenGLContext flushBuffer]".
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/.work/darling-root/usr/libexec/darling"
S=$1; shift
SPEC=""
for a in "$@"; do
  img=${a%%:*}; sym=${a#*:}
  off=$(llvm-nm --arch=x86_64 "$D/$img" 2>/dev/null | awk -v s="$sym" '{n=$0; sub(/^[0-9a-f]+ [a-zA-Z] /, "", n); if (n == s) {print "0x"$1; exit}}')
  [ -n "$off" ] || { echo "no symbol $sym in $img" >&2; continue; }
  name=$(basename "$img"); [ -e "$ROOT/.work/vine-overlay/usr/libexec/darling/$img.darling" ] && name="$name.darling"
  SPEC+="$name|$sym|$off;"
done
P=$(for p in $(pgrep -f '^/Applications/RobloxPlayer.app/Contents/MacOS/RobloxPlayer$'); do
      [ "$(ls /proc/$p/task 2>/dev/null | wc -l)" -gt 1 ] && echo $p; done | head -1)
[ -n "$P" ] || { echo "Roblox not running"; exit 1; }
H=$(cat "$ROOT/.work/darling-ns.pid")
timeout $((S + 30)) nsenter --target "$H" --user --preserve-credentials -- env VINE_COUNT="$SPEC" VINE_COUNT_SECONDS="$S" \
  gdb -q -batch -p "$P" -ex 'set pagination off' -ex 'handle all nostop noprint pass' -ex "source $ROOT/tests/gdb-count.py" 2>&1 | grep '^COUNT'
