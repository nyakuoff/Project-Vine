#!/usr/bin/env bash
# Route A baseline: start the official Windows player under Wine in an isolated
# prefix and record how far it gets. No login, no auth ticket, no host changes.
# Usage: tests/route-a-wine-startup.sh [wine-binary] [extra args to the player...]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WINE="${1:-wine}"; shift || true
NAME="$(echo "$WINE" | sed -nE "s:.*/([^/]+)/files/bin/wine$:\1:p" | tr " " -)"
TAG="${NAME:-system-$("$WINE" --version | cut -d" " -f1)}-$(date +%Y%m%d-%H%M%S)"
export WINESERVER="${WINE}server"
export WINEPREFIX="$ROOT/.work/prefix-route-a-$("$WINE" --version 2>/dev/null | tr -c "a-zA-Z0-9.\n-" _)"
export WINEDEBUG="${WINEDEBUG:-+seh,+loaddll,+process,err+all,warn+module}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-winemenubuilder.exe=d}"
LOG="$ROOT/logs/route-a-$TAG.log"
APP="$WINEPREFIX/drive_c/Roblox"

mkdir -p "$ROOT/logs" "$APP"
[ -f "$WINEPREFIX/system.reg" ] || "$WINE" wineboot -i >/dev/null 2>&1
cp -n "$ROOT"/artifacts/win/* "$APP/"
printf '<Settings><ContentFolder>content</ContentFolder><BaseUrl>http://www.roblox.com</BaseUrl></Settings>\n' > "$APP/AppSettings.xml"

{ echo "# wine: $("$WINE" --version 2>&1)  kernel: $(uname -r)  date: $(date -Is)"
  echo "# exe sha256: $(sha256sum "$APP/RobloxPlayerBeta.exe" | cut -c1-16)"; } > "$LOG"
cd "$APP"
timeout 90 xvfb-run -a -s '-screen 0 1280x720x24' "$WINE" RobloxPlayerBeta.exe "$@" >>"$LOG" 2>&1
echo "# exit: $?" >> "$LOG"
echo "$LOG"
