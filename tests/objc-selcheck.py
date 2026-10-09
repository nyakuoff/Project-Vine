#!/usr/bin/env python3
"""Selectors a Mach-O references that neither it nor any Darling framework implements.

Approximate (selector names only, not per class), but a good predictor of
"unrecognized selector" crashes before running anything.
Usage: tests/objc-selcheck.py <binary> <root>[:<root>...]
"""
import os, re, subprocess, sys

def run(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout

def implemented(path):
    """Method names in class/category/protocol method lists."""
    out = run('llvm-objdump', '--macho', '--arch=x86_64', '--objc-meta-data', path)
    names = set(re.findall(r'^\s+name\s+0x[0-9a-f]+\s+(\S+)$', out, re.M))
    # llvm-objdump omits category class methods; Darling keeps local symbols like +[NSNumber(Cat) numberWithBool:]
    syms = run('llvm-nm', '--arch=x86_64', '-j', path)
    return names | set(re.findall(r'^[-+]\[\S+ (\S+)\]$', syms, re.M))

def methnames(path):
    """Strings of __objc_methname (all selectors the image mentions)."""
    data = subprocess.run(['llvm-objcopy', '--dump-section=__TEXT,__objc_methname=/dev/stdout', path, '/dev/null'],
                          capture_output=True).stdout
    return {s.decode() for s in data.split(b'\0') if s}

def darling_images(roots):
    for r in roots:
        for top in ('System/Library/Frameworks', 'System/Library/PrivateFrameworks', 'usr/lib'):
            for d, _, files in os.walk(os.path.join(r, top)):
                for f in files:
                    p = os.path.join(d, f)
                    if not os.path.islink(p) and ('.' not in f or f.endswith(('.dylib', '.darling'))):
                        yield p

def main():
    binary, roots = sys.argv[1], sys.argv[2].split(':')
    refs = methnames(binary)
    have = implemented(binary)
    for p in darling_images(roots):
        with open(p, 'rb') as fh:
            if fh.read(4) not in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe'):
                continue
        have |= implemented(p)
    missing = sorted(refs - have)
    print('\n'.join(missing))
    print(f'# {len(missing)} of {len(refs)} referenced selectors have no implementation', file=sys.stderr)

if __name__ == '__main__':
    main()
