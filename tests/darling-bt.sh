#!/usr/bin/env bash
# Backtrace every thread of a live Darling process (Linux pid) and symbolize Mach-O frames.
# gdb runs inside Vine's user namespace (CAP_SYS_PTRACE there), so ptrace_scope=1 is no obstacle.
# Usage: tests/darling-bt.sh <linux-pid>          live process
#        tests/darling-bt.sh --core <linux-pid>   systemd-coredump core of a crashed process
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT=$(mktemp); CORE=$(mktemp)
GDB=(gdb -q -batch -ex 'set pagination off' -ex 'info proc mappings' -ex 'thread apply all bt 40')
if [ "$1" = --core ]; then
  coredumpctl dump "$2" -o "$CORE" >/dev/null 2>&1
  "${GDB[@]}" /usr/bin/true "$CORE" >"$OUT" 2>/dev/null || true
  grep -m1 -E 'terminated with signal|Program terminated' "$OUT" || true
else
  H=$(cat "$ROOT/.work/darling-ns.pid")
  nsenter --target "$H" --user --preserve-credentials -- "${GDB[@]}" -p "$1" >"$OUT" 2>/dev/null || true
fi
python3 "$ROOT/tests/darling-symbolize.py" "$OUT" "$ROOT/.work/vine-overlay/usr/libexec/darling:$ROOT/.work/darling-root/usr/libexec/darling:$ROOT/.work/darling-prefix"
rm -f "$OUT" "$CORE"
