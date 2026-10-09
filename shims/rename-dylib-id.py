#!/usr/bin/env python3
"""Give a Mach-O dylib (thin or fat) a different install name of the SAME length, in place.

dyld de-duplicates images by install name, so a re-exported copy of a framework must not
share its id with the wrapper that re-exports it. Same length = no load-command resizing.
Usage: rename-dylib-id.py <dylib>   ("/System/..." -> "/Vystem/...", "/usr/..." -> "/Vsr/...")
"""
import struct, sys

LC_ID_DYLIB = 0xd

def patch_slice(buf, off):
    magic, = struct.unpack_from('<I', buf, off)
    assert magic == 0xfeedfacf or magic == 0xfeedface, hex(magic)
    ncmds, = struct.unpack_from('<I', buf, off + 16)
    p = off + (32 if magic == 0xfeedfacf else 28)
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', buf, p)
        if cmd == LC_ID_DYLIB:
            name_off, = struct.unpack_from('<I', buf, p + 8)
            s = p + name_off
            assert buf[s] == ord('/') and buf[s + 1] != ord('V'), bytes(buf[s:s + 40])
            buf[s + 1] = ord('V')
            return True
        p += size
    return False

def main(path):
    buf = bytearray(open(path, 'rb').read())
    magic, = struct.unpack_from('>I', buf, 0)
    if magic == 0xcafebabe:  # fat: big-endian header, slice offsets
        n, = struct.unpack_from('>I', buf, 4)
        offs = [struct.unpack_from('>IIIII', buf, 8 + 20 * i)[2] for i in range(n)]
    else:
        offs = [0]
    assert all(patch_slice(buf, o) for o in offs), 'no LC_ID_DYLIB'
    open(path, 'wb').write(buf)

if __name__ == '__main__':
    main(sys.argv[1])
