#!/usr/bin/env python3
"""Symbolize raw frame addresses in gdb output using the process's own mappings.

gdb knows the ELF side (mldr, host .so) but not Darwin images. For each "#N 0xADDR" frame,
find the mapping that contains it, locate the Mach-O file under the given roots, and ask
llvm-symbolizer (x86_64 slice) for the function at (ADDR - image base).
Usage: darling-symbolize.py <gdb-output> <root>[:<root>...]
"""
import os, re, subprocess, sys

def main():
    text = open(sys.argv[1]).read()
    roots = sys.argv[2].split(':')
    maps = []   # (start, end, offset, path)
    for m in re.finditer(r'^\s*(0x[0-9a-f]+)\s+(0x[0-9a-f]+)\s+0x[0-9a-f]+\s+(0x[0-9a-f]+)\s+(?:[rwxps-]{4}\s+)?(/\S.*)$', text, re.M):
        maps.append((int(m[1], 16), int(m[2], 16), int(m[3], 16), m[4].strip()))
    # image base = lowest mapping of each file (its __TEXT, at the slice's file offset)
    base = {}
    for s, e, off, p in maps:
        if p not in base or s < base[p][0]:
            base[p] = (s, off)

    def host(p):   # mapping path as seen by the process -> file on the host
        cands = []
        if p.startswith('/libexec/darling/'):      # Darling's mount namespace: /usr is mounted at /
            cands += [r + p[len('/libexec/darling'):] for r in roots]
        cands += [r + p for r in roots] + ['/usr' + p, p]
        for anchor in ('/System/Library/', '/usr/lib/', '/Applications/'):   # Darling prefix overlay paths
            i = p.find(anchor)
            if i > 0:
                cands += [r + p[i:] for r in roots]
        return next((c for c in cands if os.path.isfile(c)), None)

    vmcache = {}
    def text_vmaddr(f):   # llvm-symbolizer wants VM addresses: add __TEXT's vmaddr (0x100000000 for executables)
        if f not in vmcache:
            out = subprocess.run(['llvm-objdump', '--macho', '--arch=x86_64', '--private-headers', f],
                                 capture_output=True, text=True).stdout
            m = re.search(r'segname __TEXT\s+vmaddr (0x[0-9a-f]+)', out)
            vmcache[f] = int(m[1], 16) if m else 0
        return vmcache[f]

    cache = {}
    def sym(addr):
        for s, e, off, p in maps:
            if s <= addr < e:
                f = host(p)
                if not f:
                    return f'{os.path.basename(p)}+?'
                rel = addr - base[p][0] + text_vmaddr(f)
                key = (f, rel)
                if key not in cache:
                    r = subprocess.run(['llvm-symbolizer', '--default-arch=x86_64', f'--obj={f}', hex(rel)],
                                       capture_output=True, text=True).stdout.split('\n')[0]
                    cache[key] = f'{os.path.basename(p)}!{r if r and r != "??" else ""} [{hex(rel)}]'
                return cache[key]
        return '?'

    execmaps = [(s0, e0) for s0, e0, _, p0 in maps]
    # Stack scan ("x/Ngx $rsp" lines): code addresses found on the stack = heuristic return addresses
    scanned = []
    for m in re.finditer(r'^0x[0-9a-f]+:\s+(.*)$', text, re.M):
        for v in re.findall(r'0x[0-9a-f]{9,16}', m[1]):
            a = int(v, 16)
            if any(s0 <= a < e0 for s0, e0 in execmaps):
                r = sym(a)
                if r != '?' and (not scanned or scanned[-1] != r):
                    scanned.append(r)
    if scanned:
        print('stack scan (heuristic, innermost first):')
        for r in scanned[:80]:
            print('   ', r)

    for line in text.splitlines():
        if line.startswith('Thread '):
            print(line[:120])
        m = re.match(r'#(\d+)\s+(0x[0-9a-f]+)', line)
        if m:
            print(f'  #{m[1]:<3} {m[2]}  {sym(int(m[2], 16))}')

if __name__ == '__main__':
    main()
