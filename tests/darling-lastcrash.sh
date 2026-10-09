#!/usr/bin/env bash
# Explain the most recent RobloxPlayer crash under Darling from its systemd-coredump core:
# recovers the real faulting frame (tests/core-sigframe.py) and symbolizes it.
# Usage: tests/darling-lastcrash.sh [coredump-pid]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID=${1:-$(coredumpctl list --no-pager --no-legend 2>/dev/null | grep mldr | tail -1 | awk '{print $5}')}   # newest (list is chronological)
[ -n "$PID" ] || { echo "no core"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
coredumpctl info "$PID" --no-pager 2>/dev/null | grep -E 'Timestamp|Signal|Command Line' | sed 's/^ *//'
coredumpctl dump "$PID" -o "$T/core" >/dev/null 2>&1
python3 "$ROOT/tests/core-sigframe.py" "$T/core" > "$T/frames"
gdb -q -batch -ex 'info proc mappings' /usr/bin/true "$T/core" > "$T/maps" 2>/dev/null
grep -E '^SIGFRAME|^  rax' "$T/frames"
# symbolize each recovered frame separately (first one with a plausible rip is usually the fault)
awk -v d="$T" '/^SIGFRAME/{n++} {print > (d "/f" n)}' "$T/frames"
for f in "$T"/f[0-9]*; do
  head -1 "$f" | grep -q 'rip 0x7f\|rip 0x10' || continue
  echo "== $(head -1 "$f" | cut -d: -f1)"
  cat "$T/maps" "$f" > "$T/all"
  python3 "$ROOT/tests/darling-symbolize.py" "$T/all" \
    "$ROOT/.work/vine-overlay/usr/libexec/darling:$ROOT/.work/darling-root/usr/libexec/darling:$ROOT/.work/darling-prefix" |
    grep -vE 'OBJC_CLASS|OBJC_METACLASS|kCFAllocator|__kCF|dyld!' | head -"${LINES_PER_FRAME:-30}"
done
