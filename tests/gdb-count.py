# gdb python: count calls to functions in Darwin images of a live Darling process.
# env VINE_COUNT="image|symbol|offset;..." (offsets from llvm-nm, x86_64 slice, dylib vmaddr 0),
#     VINE_COUNT_SECONDS (default 10). Prints "COUNT <image>!<symbol> <hits> [threads]" then detaches.
import gdb, os, re, threading, time

maps = gdb.execute('info proc mappings', to_string=True)
def base_of(image):
    starts = [int(m[1], 16) for m in re.finditer(r'^\s*(0x[0-9a-f]+)\s.*/' + re.escape(image) + r'\s*$', maps, re.M)]
    return min(starts) if starts else None

counts = {}
class Counter(gdb.Breakpoint):
    def __init__(self, spec, key):
        super().__init__(spec, internal=True)
        self.key = key
    def stop(self):
        n, threads = counts[self.key]
        counts[self.key] = (n + 1, threads | {gdb.selected_thread().name})
        return False

for item in filter(None, os.environ['VINE_COUNT'].split(';')):
    image, sym, off = item.split('|')
    b = base_of(image)
    if b is None:
        print(f'COUNT {image}!{sym} image-not-mapped', flush=True)
        continue
    counts[f'{image}!{sym}'] = (0, set())
    Counter(f'*{b + int(off, 16)}', f'{image}!{sym}')

secs = float(os.environ.get('VINE_COUNT_SECONDS', '10'))
def stopper():
    time.sleep(secs)
    gdb.post_event(lambda: gdb.execute('interrupt'))
threading.Thread(target=stopper, daemon=True).start()
gdb.execute('continue')
for k, (n, th) in counts.items():
    print(f'COUNT {k} {n} {sorted(th)[:4]}', flush=True)
gdb.execute('detach')
