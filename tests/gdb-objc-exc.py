# gdb python: break on objc_exception_throw in a Darling process and print each exception.
# Needs env VINE_OBJC_OFFS="objc_exception_throw=0x..,objc_msgSend=0x..,sel_registerName=0x.."
# (offsets in libobjc.A.dylib's x86_64 slice; tests/darling-exc.sh computes them).
import gdb, os, re

offs = dict(kv.split('=') for kv in os.environ['VINE_OBJC_OFFS'].split(','))
maps = gdb.execute('info proc mappings', to_string=True)
base = min(int(m[1], 16) for m in re.finditer(r'^\s*(0x[0-9a-f]+)\s.*libobjc\.A\.dylib\s*$', maps, re.M))
addr = {k: base + int(v, 16) for k, v in offs.items()}
seen = [0]

def cstr(obj):
    if not obj:
        return '(nil)'
    sel = gdb.parse_and_eval(f'((void*(*)(const char*)){addr["sel_registerName"]})("UTF8String")')
    p = gdb.parse_and_eval(f'((char*(*)(void*,void*)){addr["objc_msgSend"]})((void*){obj}, (void*){int(sel)})')
    return p.string() if int(p) else '?'

class Throw(gdb.Breakpoint):
    def stop(self):
        exc = int(gdb.parse_and_eval('$rdi'))
        inf = gdb.selected_inferior()
        name, reason = (int.from_bytes(inf.read_memory(exc + 8 * i, 8), 'little') for i in (1, 2))
        th = gdb.selected_thread().name
        print(f'OBJC-EXCEPTION thread="{th}" name={cstr(name)!r} reason={cstr(reason)!r}', flush=True)
        seen[0] += 1
        return seen[0] >= int(os.environ.get('VINE_EXC_STOP_AFTER', '1'))   # stop (for bt) after N

Throw(f'*{addr["objc_exception_throw"]}', internal=False)
