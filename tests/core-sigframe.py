#!/usr/bin/env python3
"""Recover the real fault from a Darling core whose SIGSEGV is SI_USER.

Darling turns a fault into a Mach exception; if nobody handles it the process is later killed,
so the core's "crashing" thread is innocent. The faulting thread is still inside the signal
handler, though, so its kernel rt_sigframe (x86_64) is in memory:
    frame+0   pretcode
    frame+8   struct ucontext (304 bytes): uc_flags, uc_link, uc_stack[24], sigcontext[256], sigmask
    frame+312 siginfo: si_signo=11, si_errno, si_code=1|2 (MAPERR/ACCERR), pad, si_addr
sigcontext gregs: r8..r15, rdi, rsi, rbp, rbx, rdx, rax, rcx, rsp, rip, eflags, csgsfs, err, trapno, oldmask, cr2
Prints gdb-like lines ("#0 0x<rip>", "0x...: <stack words>") for darling-symbolize.py.
Usage: core-sigframe.py <core> [stack-words=512]
"""
import struct, sys

NAMES = 'r8 r9 r10 r11 r12 r13 r14 r15 rdi rsi rbp rbx rdx rax rcx rsp rip eflags csgsfs err trapno oldmask cr2'.split()

def loads(core):
    data = open(core, 'rb').read()
    phoff, = struct.unpack_from('<Q', data, 0x20)
    phentsize, phnum = struct.unpack_from('<HH', data, 0x36)
    segs = []
    for i in range(phnum):
        ptype, _, off, vaddr, _, filesz, _, _ = struct.unpack_from('<IIQQQQQQ', data, phoff + i * phentsize)
        if ptype == 1 and filesz:
            segs.append((vaddr, off, filesz))
    return data, segs

def read(data, segs, addr, n):
    for va, off, sz in segs:
        if va <= addr and addr + n <= va + sz:
            return data[off + addr - va: off + addr - va + n]
    return None

def main():
    data, segs = loads(sys.argv[1])
    words = int(sys.argv[2]) if len(sys.argv) > 2 else 512
    found = 0
    for va, off, sz in segs:
        blob = data[off:off + sz]
        for code in (1, 2):
            pat = struct.pack('<iii', 11, 0, code)
            i = blob.find(pat)
            while i >= 0:
                frame = va + i - 312
                ctx = read(data, segs, frame + 48, 8 * len(NAMES))
                si_addr = struct.unpack_from('<Q', blob, i + 16)[0]
                if ctx:
                    r = dict(zip(NAMES, struct.unpack('<' + 'Q' * len(NAMES), ctx)))
                    if r['cr2'] == si_addr and r['rip'] > 0x1000:
                        found += 1
                        print(f'SIGFRAME #{found}: fault addr 0x{si_addr:x} code {code} rip 0x{r["rip"]:x} rsp 0x{r["rsp"]:x}')
                        print('  ' + ' '.join(f'{k}=0x{r[k]:x}' for k in ('rax', 'rbx', 'rcx', 'rdx', 'rdi', 'rsi', 'rbp')))
                        print(f'#0  0x{r["rip"]:016x}')
                        stack = read(data, segs, r['rsp'], 8 * words) or b''
                        for j in range(0, len(stack), 16):
                            vals = struct.unpack_from('<' + 'Q' * (len(stack[j:j + 16]) // 8), stack, j)
                            print(f'0x{r["rsp"] + j:x}:\t' + '\t'.join(f'0x{v:016x}' for v in vals))
                i = blob.find(pat, i + 1)
    if not found:
        print('no fault signal frame found')

if __name__ == '__main__':
    main()
