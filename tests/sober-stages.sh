#!/usr/bin/env bash
# Map a Sober log onto the Phase 4 lifecycle stages. Read-only; prints no secrets.
# Usage: tests/sober-stages.sh [logfile]   (default: newest Sober log)
LOG="${1:-$(ls -t ~/.var/app/org.vinegarhq.Sober/data/sober/sober_logs/2*.log 2>/dev/null | head -1)}"
[ -f "$LOG" ] || { echo "no Sober log found" >&2; exit 2; }
echo "log: $LOG"
stage() { if grep -qE "$2" "$LOG"; then echo "PASS  $1"; else echo "----  $1"; fi; }
stage "client version known"          'AppVersion=[0-9]+'
stage "vulkan loaded"                 'Loaded Vulkan libs successfully'
stage "window created"                'Will create window'
stage "GPU device selected"           'Vulkan Device: '
stage "joining experience"            'Joining game'
stage "server connection accepted"    'Connection accepted'
stage "clean exit"                    'clean_exit_success'
grep -oE 'AppVersion=[0-9]+' "$LOG" | head -1
grep -oE 'Vulkan Device: [^(]+\(RADV[^)]*\)|Vulkan Device: [A-Z][^,]{0,50}' "$LOG" | head -1
awk -F, '/setStage: \(stage:None\)/{t=$2} END{if(t) printf "session length: %.0fs\n", t}' "$LOG"
grep -oE 'Sending disconnect with reason: [0-9]+' "$LOG" | sort -u
