#!/usr/bin/env bash
# Run the Windows player under gdb and print the NtRaiseHardError text (system Wine).
# Reuses the prefix created by route-a-wine-startup.sh for the same Wine build.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export WINEPREFIX="$ROOT/.work/prefix-route-a-$(wine --version | tr -c "a-zA-Z0-9.\n-" _)"
export WINEDEBUG=-all
# No preloader: it maps ld.so by hand, which hides ntdll.so from gdb.
export WINELOADERNOEXEC=1
OUT="$ROOT/.work/hard-error-gdb.txt"
cd "$WINEPREFIX/drive_c/Roblox" || { echo "run tests/route-a-wine-startup.sh first" >&2; exit 2; }
wineserver -k 2>/dev/null
wineserver -p 5   # started outside gdb so there is no fork to follow
# Output to a file, not a pipe: Wine's background services inherit the fd and would hold a pipe open.
timeout 120 xvfb-run -a gdb -q -batch -x "$ROOT/tests/hard-error-text.gdb" --args wine RobloxPlayerBeta.exe >"$OUT" 2>&1
wineserver -k 2>/dev/null
grep -E 'HARDERROR|exited' "$OUT"
