#!/usr/bin/env bash
# Profile a running Roblox under Darling while the problem happens (in game, during lag).
#  1. CPU per thread over 5 s (Roblox and darlingserver);
#  2. 25 stack samples of the main thread and the 3 busiest others (gdb attach; each pauses the game briefly);
#  3. symbolized, ranked report: logs/profile-<time>.txt
# Usage: tests/profile.sh [samples=25]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
N=${1:-25}
PID=$(pgrep -f '^/Applications/RobloxPlayer.app/Contents/MacOS/RobloxPlayer' | head -1)
[ -n "$PID" ] || { echo "RobloxPlayer is not running"; exit 1; }
DS=$(pgrep -f '^darlingserver' | head -1)
OUT="$ROOT/logs/profile-$(date +%Y%m%d-%H%M%S).txt"; TMP=$(mktemp -d)
cpu() { for t in /proc/$1/task/*; do awk -v t="${t##*/}" '{sub(/^[^)]*\) /, ""); print t, $12 + $13}' $t/stat 2>/dev/null; done; }
cpu $PID > $TMP/a; d0=$(awk '{sub(/^[^)]*\) /, ""); print $12 + $13}' /proc/$DS/stat 2>/dev/null)
echo "measuring CPU for 5 s..."; sleep 5
cpu $PID > $TMP/b; d1=$(awk '{sub(/^[^)]*\) /, ""); print $12 + $13}' /proc/$DS/stat 2>/dev/null)
{
  echo "# CPU over 5 s (100% = one core)"
  echo "darlingserver: $(( (d1 - d0) / 5 ))%"
  join <(sort $TMP/a) <(sort $TMP/b) | awk '{print $1, ($3 - $2) / 5}' | sort -k2 -nr | head -12 |
    while read tid pct; do printf '  tid %-8s %5s%%  %s\n' $tid $pct "$(cat /proc/$PID/task/$tid/comm 2>/dev/null)"; done
} > "$OUT"
# the main thread (frame loop) plus the 3 busiest others
TOP=$( (echo $PID; join <(sort $TMP/a) <(sort $TMP/b) | awk '{print $1, $3 - $2}' | sort -k2 -nr | awk -v p=$PID '$1 != p {print $1}' | head -3) | paste -sd,)
cat > $TMP/walk.py <<'PY'
import gdb, struct, os
want = set(int(x) for x in os.environ['VINE_TIDS'].split(','))
out = open(os.environ['VINE_OUT'], 'a')
inf = gdb.selected_inferior()
for t in inf.threads():
    if t.ptid[1] not in want: continue
    t.switch()
    rip = int(gdb.parse_and_eval('$rip')) & (2**64 - 1); rbp = int(gdb.parse_and_eval('$rbp')) & (2**64 - 1)
    addrs = [rip]
    for _ in range(48):   # frame-pointer chain (Darwin code keeps rbp)
        if not rbp or rbp % 8: break
        try: nrbp, ret = struct.unpack('<QQ', bytes(inf.read_memory(rbp, 16)))
        except Exception: break
        if ret < 0x1000: break
        addrs.append(ret)
        if nrbp <= rbp: break
        rbp = nrbp
    out.write('T %d %s\n' % (t.ptid[1], ' '.join(hex(a) for a in addrs)))
    rsp = int(gdb.parse_and_eval('$rsp')) & (2**64 - 1)   # stack scan: frame pointers end in ELF code
    try: words = struct.unpack('<2048Q', bytes(inf.read_memory(rsp, 16384)))
    except Exception: words = ()
    out.write('S %d %s\n' % (t.ptid[1], ' '.join(hex(w) for w in words if 0x100000000 <= w < 0x800000000000)))
PY
echo "sampling $N stacks of threads $TOP..."
for i in $(seq 1 $N); do
  VINE_TIDS=$TOP VINE_OUT=$TMP/stacks timeout 20 gdb -nx -batch -p $PID -ex 'set auto-solib-add off' -ex "source $TMP/walk.py" >/dev/null 2>&1
  sleep 0.3
done
python3 - /proc/$PID/maps > $TMP/maps <<'PY'
import sys   # /proc maps -> gdb "info proc mappings" lines (paths may contain spaces)
for line in open(sys.argv[1]):
    f = line.rstrip('\n').split(None, 5)
    if len(f) == 6 and f[5].startswith('/'):
        a, b = f[0].split('-')
        print('0x%s 0x%s 0x0 0x%s %s' % (a, b, f[2], f[5]))
PY
python3 - /proc/$PID/maps $TMP/stacks > $TMP/frames <<'PY'
import sys, bisect   # every sampled address, scan words only when they point into executable code
ex = []
for line in open(sys.argv[1]):
    f = line.split(None, 5)
    if len(f) >= 2 and 'x' in f[1]:
        a, b = f[0].split('-'); ex.append((int(a, 16), int(b, 16)))
ex.sort(); starts = [a for a, b in ex]
def code(v):
    i = bisect.bisect_right(starts, v) - 1
    return i >= 0 and v < ex[i][1]
for line in open(sys.argv[2]):
    w = line.split()
    for i, v in enumerate(w[2:]):
        if w[0] == 'T' or code(int(v, 16)): print('#%d %s' % (i, v))
PY
cat $TMP/maps $TMP/frames > $TMP/in
python3 "$ROOT/tests/darling-symbolize.py" $TMP/in "$ROOT/.work/vine-overlay/usr/libexec/darling:$ROOT/.work/darling-prefix:$ROOT/.work/darling-root/usr/libexec/darling" > $TMP/sym 2>/dev/null
python3 - "$TMP/stacks" "$TMP/sym" "$PID" >> "$OUT" <<'PY'
import sys, re, collections
stacks = [l.split() for l in open(sys.argv[1])]
syms = [re.sub(r'^\s*#\d+\s+0x[0-9a-f]+\s+', '', l.rstrip()) for l in open(sys.argv[2]) if re.match(r'^\s*#\d+', l)]
pid = sys.argv[3]
k = 0
top, incl = collections.defaultdict(collections.Counter), collections.defaultdict(collections.Counter)
first_sys = collections.defaultdict(collections.Counter)
per = collections.Counter()
import bisect
ex = []
for line in open('/proc/%s/maps' % pid):
    f = line.split(None, 5)
    if len(f) >= 2 and 'x' in f[1]:
        a, b = f[0].split('-'); ex.append((int(a, 16), int(b, 16)))
ex.sort(); starts = [a for a, b in ex]
def code(v):
    i = bisect.bisect_right(starts, v) - 1
    return i >= 0 and v < ex[i][1]
clean = lambda n: re.sub(r' \[0x[0-9a-f]+\]$', '', n)
for s in stacks:
    kind, tid, frames = s[0], s[1], s[2:]
    if kind == 'S': frames = [f for f in frames if code(int(f, 16))]
    names = syms[k:k + len(frames)]; k += len(frames)
    if not names: continue
    if kind == 'T':
        per[tid] += 1
        top[tid][names[0]] += 1
        sysf = next((n for n in names if not n.startswith('RobloxPlayer')), None)
        if sysf: first_sys[tid][sysf] += 1
    else:
        for n in set(clean(x) for x in names if '?' not in x): incl[tid][n] += 1
for tid in per:
    try: comm = open('/proc/%s/task/%s/comm' % (pid, tid)).read().strip()
    except Exception: comm = '?'
    print('\n# thread %s (%s): %d samples' % (tid, comm, per[tid]))
    print('  where it was (innermost frame):')
    for n, c in top[tid].most_common(8): print('    %3d  %s' % (c, n))
    print('  innermost non-Roblox frame (system library it is in):')
    for n, c in first_sys[tid].most_common(8): print('    %3d  %s' % (c, n))
    print('  functions found on the stack (scan, inclusive):')
    for n, c in incl[tid].most_common(25): print('    %3d  %s' % (c, n))
PY
mkdir -p "${OUT%.txt}"; cp $TMP/stacks $TMP/maps $TMP/sym "${OUT%.txt}/"; rm -rf $TMP   # raw data kept
echo "report: $OUT"; head -16 "$OUT"
