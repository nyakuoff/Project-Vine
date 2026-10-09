#!/usr/bin/env python3
"""List a Mach-O's imported symbols that a Darling root does not export.

Resolves two-level-namespace imports the way dyld does: the symbol must be exported
by the named library or by a library it re-exports (LC_REEXPORT_DYLIB, recursively).
Usage: tests/macho-symcheck.py <binary> <root>[:<root>...] [--all]   (first root containing a path wins)
"""
import re, subprocess, sys, os
from functools import lru_cache

def run(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout

def imports(binary):
    """{library install name: [(symbol, weak)]} from `llvm-nm -m -u`."""
    libs = {n.rsplit('/', 1)[-1].split('.')[0]: n for n in deps(binary)}
    out = {}
    for line in run('llvm-nm', '-m', '-u', binary).splitlines():
        m = re.search(r'external (\S+)(?: \(weak ref\))? \(from ([^)]+)\)', line)
        if m:
            sym, short = m.groups()
            out.setdefault(libs.get(short, short), []).append((sym, '(weak ref)' in line))
    return out

def deps(path, cmd='LC_LOAD|LC_LOAD_WEAK'):
    """Install names from load commands matching cmd."""
    names, cur = [], None
    for line in run('llvm-objdump', '--macho', '--private-headers', path).splitlines():
        s = line.split()
        if s[:1] == ['cmd']:
            cur = s[1]
        elif s[:1] == ['name'] and cur and re.match(cmd + r'_DYLIB$', cur):
            names.append(s[1])
    return names

@lru_cache(None)
def exports(root, install_name):
    p = next((os.path.realpath(r + install_name) for r in root.split(':') if os.path.exists(r + install_name)), None)
    if p is None:
        return None
    syms = {l.split()[-1] for l in run('llvm-nm', '-g', '--defined-only', '-j', p).splitlines() if l}
    syms |= {l.split()[-1] for l in run('llvm-nm', '-g', '-j', '-m', p).splitlines() if '(indirect' in l}
    for sub in deps(p, 'LC_REEXPORT'):
        syms |= exports(root, sub) or set()
    return frozenset(syms)

def main():
    binary, root = sys.argv[1], sys.argv[2]
    show_all = '--all' in sys.argv
    total = 0
    for lib, syms in sorted(imports(binary).items()):
        ex = exports(root, lib) if lib.startswith('/') else frozenset()
        if ex is None:
            print(f'MISSING LIBRARY {lib} ({len(syms)} symbols)')
            continue
        miss = [(s, w) for s, w in syms if s not in ex]
        total += sum(1 for _, w in miss if not w)
        if miss:
            print(f'{lib}: {len(miss)}/{len(syms)} missing')
            for s, w in miss[: None if show_all else 8]:
                print(f'    {s}{"  (weak)" if w else ""}')
    print(f'non-weak missing symbols in present libraries: {total}')

if __name__ == '__main__':
    main()
