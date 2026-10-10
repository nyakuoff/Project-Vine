#!/usr/bin/env bash
# Runs tests/darwin/mouse_lock.m on a private Xvfb, moves the mouse 300 x 4 px right once it is
# locked, a fast 60 x 10 px flick, then 300 x 4 px down; PASS if dx is +1800 and dy +1200 (+-5 %;
# macOS: y grows downwards) and no single event jumps more than 600 px (merged fast motion).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
Xvfb :96 -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & X=$!; sleep 1
OUT=$(mktemp)
DISPLAY=:96 timeout 150 "$ROOT/tests/darwin/run.sh" mouse_lock > "$OUT" 2>&1 &
for i in $(seq 1 300); do grep -q LOCKED "$OUT" && break; sleep 0.2; done; sleep 0.5
python3 - <<'PY'
import ctypes, ctypes.util, time
x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library('X11')); xtst = ctypes.cdll.LoadLibrary(ctypes.util.find_library('Xtst'))
x11.XOpenDisplay.restype = ctypes.c_void_p
d = ctypes.c_void_p(x11.XOpenDisplay(b':96'))
for i in range(300):
    xtst.XTestFakeRelativeMotionEvent(d, 4, 0, 0); x11.XFlush(d); time.sleep(0.002)
for i in range(60):   # fast flick (600 px, stays on screen): no delay, merged with our recentring warps
    xtst.XTestFakeRelativeMotionEvent(d, 10, 0, 0)
x11.XFlush(d); time.sleep(0.5)
for i in range(300):   # then down: macOS deltaY is positive downwards
    xtst.XTestFakeRelativeMotionEvent(d, 0, 4, 0); x11.XFlush(d); time.sleep(0.002)
PY
for i in $(seq 1 120); do grep -q "events " "$OUT" && break; sleep 0.25; done
grep -a -E "events |type |LOCKED|moved at|XFixes" "$OUT" >&2
line=$(grep -a 'events ' "$OUT" | tail -1)
kill $X 2>/dev/null; rm -f "$OUT"
python3 -c "
import re,sys
m=re.search(r'total dx (-?\d+) dy (-?\d+), largest single step (\d+)', '''$line''')
ok = m and 1710 <= int(m[1]) <= 1890 and 1080 <= int(m[2]) <= 1320 and int(m[3]) <= 600
print('PASS' if ok else 'FAIL'); sys.exit(0 if ok else 1)"
