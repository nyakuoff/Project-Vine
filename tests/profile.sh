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
PY
echo "sampling $N stacks of threads $TOP..."
for i in $(seq 1 $N); do
  VINE_TIDS=$TOP VINE_OUT=$TMP/stacks timeout 20 gdb -nx -batch -p $PID -ex 'set auto-solib-add off' -ex "source $TMP/walk.py" >/dev/null 2>&1
  sleep 0.3
done
awk '{printf "0x%s 0x%s 0x0 0x%s %s\n", substr($1,1,index($1,"-")-1), substr($1,index($1,"-")+1), $3, $6}' \
  <(sed -E 's/^([0-9a-f]+-[0-9a-f]+) +([^ ]+) +([0-9a-f]+) +([^ ]+) +([0-9]+) +(.*)$/\1 \2 \3 \4 \5 \6/' /proc/$PID/maps | awk 'NF >= 6') > $TMP/maps
awk '{for (i = 3; i <= NF; i++) print "#" i - 3, $i}' $TMP/stacks > $TMP/frames
cat $TMP/maps $TMP/frames > $TMP/in
python3 "$ROOT/tests/darling-symbolize.py" $TMP/in "$ROOT/.work/vine-overlay/usr/libexec/darling:$ROOT/.work/darling-prefix:$ROOT/.work/darling-root/usr/libexec/darling" > $TMP/sym 2>/dev/null
python3 - "$TMP/stacks" "$TMP/sym" "$PID" >> "$OUT" <<'PY'
import sys, re, collections
stacks = [l.split() for l in open(sys.argv[1])]
syms = [re.sub(r'^\s*#\d+\s+0x[0-9a-f]+\s+', '', l.rstrip()) for l in open(sys.argv[2]) if re.match(r'^\s*#\d+', l)]
pid = sys.argv[3]
k = 0
top, incl = collections.defaultdict(collections.Counter), collections.defaultdict(collections.Counter)
per = collections.Counter()
for s in stacks:
    tid, frames = s[1], s[2:]
    names = syms[k:k + len(frames)]; k += len(frames)
    if not names: continue
    per[tid] += 1
    top[tid][names[0]] += 1
    for n in set(names): incl[tid][n] += 1
for tid in per:
    try: comm = open('/proc/%s/task/%s/comm' % (pid, tid)).read().strip()
    except Exception: comm = '?'
    print('\n# thread %s (%s): %d samples' % (tid, comm, per[tid]))
    print('  where it was (innermost frame):')
    for n, c in top[tid].most_common(8): print('    %3d  %s' % (c, n))
    print('  on the stack (inclusive):')
    for n, c in incl[tid].most_common(15): print('    %3d  %s' % (c, n))
PY
rm -rf $TMP
echo "report: $OUT"; head -16 "$OUT"
