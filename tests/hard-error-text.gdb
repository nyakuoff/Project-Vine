# Read the text Hyperion passes to NtRaiseHardError (Wine stubs it, so it is never shown).
# Passive: breakpoint + memory read only. Run via tests/hard-error-text.sh.
set pagination off
set confirm off
set breakpoint pending on
handle SIGSYS SIGSEGV SIGUSR1 SIGUSR2 SIGILL SIGBUS SIGFPE SIGQUIT SIGPIPE nostop noprint pass
break NtRaiseHardError
commands
  silent
  python
import gdb
inf = gdb.selected_inferior()
rd = lambda a, n: bytes(inf.read_memory(a, n))
u64 = lambda a: int.from_bytes(rd(a, 8), 'little')
status = int(gdb.parse_and_eval('$rdi')) & 0xffffffff
count = int(gdb.parse_and_eval('$rsi'))
mask = int(gdb.parse_and_eval('$rdx'))
params = int(gdb.parse_and_eval('$rcx'))
print(f'HARDERROR status=0x{status:08x} count={count} mask=0x{mask:x}')
for i in range(count):
    p = u64(params + 8 * i)
    if mask & (1 << i) and p:
        ln = int.from_bytes(rd(p, 2), 'little')
        buf = u64(p + 8)
        print(f'HARDERROR param[{i}] string: {rd(buf, ln).decode("utf-16-le", "replace")!r}')
    else:
        print(f'HARDERROR param[{i}] = 0x{p:x}')
  end
  continue
end
run
quit
