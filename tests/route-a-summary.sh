#!/usr/bin/env bash
# One line per Route A log: wine build, first Hyperion SIGSYS offset, hard error, exit code.
# Usage: tests/route-a-summary.sh [logs...]   (default: logs/route-a-*.log)
cd "$(dirname "$0")/.."
[ $# -eq 0 ] && set -- logs/route-a-*.log
for L in "$@"; do
  T=$(grep -m1 'RobloxPlayerBeta.dll" at' "$L" | cut -d: -f1)
  B=$(grep -m1 'RobloxPlayerBeta.dll" at' "$L" | grep -oE 'at [0-9A-F]+' | cut -c4-)
  R=$(grep "^$T:.*sigsys" "$L" | head -1 | grep -oE 'rip 0x[0-9a-f]+' | cut -c5-)
  off=$([ -n "$R" ] && [ -n "$B" ] && printf '+0x%X' $(( R - 0x$B )) || echo none)
  printf '%-34s %-28s fault=%-10s %-28s %s\n' "$(basename "$L" .log)" "$(head -1 "$L" | sed 's/^# wine: //;s/  kernel.*//')" \
    "$off" "$(grep -m1 -oE 'NtRaiseHardError 0x[0-9a-f]+' "$L" || echo 'no hard error')" \
    "$(grep "^$T:" "$L" | grep -oE 'exit_code -?[0-9]+' | tail -1)$(grep -oE '^# exit: [0-9]+' "$L")"
done
