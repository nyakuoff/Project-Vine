#!/usr/bin/env bash
# Start Roblox under Darling, attach gdb to the main process early and stop at the first real
# fault (SIGSEGV/SIGBUS/SIGILL/SIGFPE) to record the faulting instruction and stack, symbolized.
# Crashpad turns faults into a later kill(), so post-mortem cores do not show the fault itself.
# Usage: tests/darling-catch.sh [seconds=60]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T=${1:-60}
OUT="$ROOT/logs/darling-catch-$(date +%Y%m%d-%H%M%S).txt"
"$ROOT/tests/run-roblox-darling.sh" "$T" > /dev/null 2>&1 &
RUN=$!
for _ in $(seq 1 150); do   # main process: exact cmdline, more than one thread
  P=$(for p in $(pgrep -f '^/Applications/RobloxPlayer.app/Contents/MacOS/RobloxPlayer$'); do
        [ "$(ls /proc/$p/task 2>/dev/null | wc -l)" -gt 1 ] && echo $p; done | head -1)
  [ -n "$P" ] && break; sleep 0.2
done
[ -n "$P" ] || { echo "main process not found"; wait $RUN; exit 1; }
H=$(cat "$ROOT/.work/darling-ns.pid")
RAW=$(mktemp)
timeout $((T + 10)) nsenter --target "$H" --user --preserve-credentials -- gdb -q -batch -p "$P" \
  -ex 'set pagination off' -ex 'handle all nostop noprint pass' \
  -ex 'handle SIGSEGV SIGBUS SIGILL SIGFPE stop print pass' \
  -ex continue -ex 'info registers' -ex 'x/6i $pc' -ex 'x/512gx $rsp' -ex 'info proc mappings' -ex 'bt 40' -ex kill \
  > "$RAW" 2>&1
{ echo "# pid $P"; grep -E 'received signal|^rip|^rsp|^rax|^rdi|^rsi|=> ' "$RAW"
  python3 "$ROOT/tests/darling-symbolize.py" "$RAW" \
    "$ROOT/.work/vine-overlay/usr/libexec/darling:$ROOT/.work/darling-root/usr/libexec/darling:$ROOT/.work/darling-prefix"
} > "$OUT"
mv "$RAW" "${OUT%.txt}.raw"; wait $RUN
echo "$OUT"
