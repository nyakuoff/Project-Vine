# gdb python: on the first hit of VINE_PEEK_ADDR_OFF (offset in the image named VINE_PEEK_IMAGE),
# print the thread, registers rdi/rsi and VINE_PEEK_WORDS qwords at rdi, then detach.
import gdb, os, re
maps = gdb.execute('info proc mappings', to_string=True)
img = os.environ['VINE_PEEK_IMAGE']
base = min(int(m[1], 16) for m in re.finditer(r'^\s*(0x[0-9a-f]+)\s.*/' + re.escape(img) + r'\s*$', maps, re.M))
gdb.Breakpoint(f'*{base + int(os.environ["VINE_PEEK_ADDR_OFF"], 16)}')
gdb.execute('continue')
print('PEEK thread', gdb.selected_thread().name, 'rdi', gdb.parse_and_eval('$rdi'), 'rsi', gdb.parse_and_eval('$rsi'))
print(gdb.execute(f'x/{os.environ.get("VINE_PEEK_WORDS", "12")}gx $rdi', to_string=True))
gdb.execute('delete'); gdb.execute('detach')
