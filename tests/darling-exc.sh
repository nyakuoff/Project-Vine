#!/usr/bin/env bash
# Start Roblox under Darling and report Objective-C exceptions as they are thrown (name, reason,
# thread), then a symbolized stack scan at the Nth one (VINE_EXC_STOP_AFTER, default 1).
# Usage: tests/darling-exc.sh [seconds=60]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T=${1:-60}
OUT="$ROOT/logs/darling-exc-$(date +%Y%m%d-%H%M%S).txt"
OBJC="$ROOT/.work/darling-root/usr/libexec/darling/usr/lib/libobjc.A.dylib"
export VINE_OBJC_OFFS=$(llvm-nm --arch=x86_64 "$OBJC" | awk '$3 ~ /^_(objc_exception_throw|objc_msgSend|sel_registerName)$/ {printf "%s%s=0x%s", s, substr($3,2), $1; s=","}')
"$ROOT/tests/run-roblox-darling.sh" "$T" > /dev/null 2>&1 &
RUN=$!
for _ in $(seq 1 150); do
  P=$(for p in $(pgrep -f '^/Applications/RobloxPlayer.app/Contents/MacOS/RobloxPlayer$'); do
        [ "$(ls /proc/$p/task 2>/dev/null | wc -l)" -gt 1 ] && echo $p; done | head -1)
  [ -n "$P" ] && break; sleep 0.2
done
[ -n "$P" ] || { echo "main process not found"; wait $RUN; exit 1; }
H=$(cat "$ROOT/.work/darling-ns.pid")
RAW="${OUT%.txt}.raw"
timeout $((T + 10)) nsenter --target "$H" --user --preserve-credentials -- env VINE_OBJC_OFFS="$VINE_OBJC_OFFS" \
  VINE_EXC_STOP_AFTER="${VINE_EXC_STOP_AFTER:-1}" gdb -q -batch -p "$P" \
  -ex 'set pagination off' -ex 'handle all nostop noprint pass' -ex "source $ROOT/tests/gdb-objc-exc.py" \
  -ex continue -ex 'x/512gx $rsp' -ex 'info proc mappings' -ex kill > "$RAW" 2>&1
{ grep -a 'OBJC-EXCEPTION' "$RAW"
  python3 "$ROOT/tests/darling-symbolize.py" "$RAW" \
    "$ROOT/.work/vine-overlay/usr/libexec/darling:$ROOT/.work/darling-root/usr/libexec/darling:$ROOT/.work/darling-prefix"
} > "$OUT"
wait $RUN
echo "$OUT"
