# gdb python: count calls (per thread) to ELF functions by name for VINE_COUNT_SECONDS, and record
# return values of VINE_RET_FUNCS (e.g. eglSwapBuffers) plus eglGetError after failures. Then detach.
import gdb, os, threading, time
funcs = os.environ['VINE_FUNCS'].split(',')
retf = set(filter(None, os.environ.get('VINE_RET_FUNCS', '').split(',')))
counts, rets = {}, {}
class Ret(gdb.FinishBreakpoint):
    def __init__(self, f, key): super().__init__(f, internal=True); self.key = key
    def stop(self):
        v = int(gdb.parse_and_eval("$rax")) & 0xffffffff
        if v == 0 and self.key.startswith('egl'):   # EGL_FALSE: fetch the EGL error code in the inferior
            v = 'EGL_FALSE err=0x%x' % (int(gdb.parse_and_eval('((int(*)(void))eglGetError)()')) & 0xffffffff)
        rets[(self.key, v)] = rets.get((self.key, v), 0) + 1
        return False
    def out_of_scope(self): pass
class B(gdb.Breakpoint):
    def __init__(self, name): super().__init__(name, internal=True); self.name = name
    def stop(self):
        k = (self.name, gdb.selected_thread().name)
        counts[k] = counts.get(k, 0) + 1
        if self.name in retf and sum(n for (f, _), n in rets.items() if f == self.name) < 50:
            Ret(gdb.newest_frame(), self.name)
        return False
for f in funcs: B(f)
def stopper():
    time.sleep(float(os.environ.get('VINE_COUNT_SECONDS', '10')))
    gdb.post_event(lambda: gdb.execute('interrupt'))
threading.Thread(target=stopper, daemon=True).start()
gdb.execute('continue')
for (f, t), n in sorted(counts.items()): print(f'ELFCOUNT {f} thread={t!r} {n}', flush=True)
for (f, v), n in sorted(rets.items(), key=str): print(f'ELFRET {f} -> {v} x{n}', flush=True)
gdb.execute('delete'); gdb.execute('detach')
