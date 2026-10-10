#!/usr/bin/env python3
"""Make a RobloxPlayer (macOS, x86_64) binary join games over RakNet instead of RbxTransport.

Finding credited to MacOBlox (github.com/aubree-lat/MacOBlox, launcher/macoblox/transport_patches.py):
under Darling, Roblox's newer RbxTransport connection completes its handshake but the channel open
fails ~10 s later ("Rejecting send channel open on failed connection", error 256), while the older
RakNet transport, which servers still accept, works. Vine's own implementation, located by meaning
rather than fixed offsets:

  Each fast flag is found through its registration (`lea rdi, name; lea rsi, flag`), then the code
  that tests it:
  - transport selection: the function starting `push rbp; mov rbp,rsp; and dil, [UseRbxTransportServer]`
    (and also testing UseRbxTransportClient) becomes `xor eax,eax; ret` (RbxTransport: no);
  - the `cmp byte [RakNetConnectionFailureFallbackToRbxTransport], 1; jne` right after the code that
    records "failureFallbackToRbxTransport" gets compare value 0xff (no fallback to RbxTransport);
  - both `cmp byte [ConnectDummyServiceClientEarly], imm; jne` become `jmp` (no RbxTransport dummy
    service connection).
  All sites must be found exactly, or nothing is changed.

Usage: raknet_transport.py <RobloxPlayer> [--check | --undo]
Prints one of: patched, original, not-found.
"""
import os, re, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from startup_throttle import sections


def text_of(data):
    secs = sections(data)
    text = next((s for s in secs if s[0] == b'__text'), None)
    return secs, text


def flag_address(data, secs, text, name):
    """Address of the fast flag registered under `name`, or None."""
    m = data.find(b'\0' + name + b'\0')
    if m < 0:
        return None
    sec = next((s for s in secs if s[3] <= m + 1 < s[3] + s[2]), None)
    if not sec:
        return None
    str_va = sec[1] + m + 1 - sec[3]
    _, taddr, tsize, toff = text
    blob = data[toff:toff + tsize]
    found = set()
    for k in re.finditer(rb'\x48\x8d\x3d(.{4})\x48\x8d\x35(.{4})', blob, re.S):
        i = k.start()
        if taddr + i + 7 + struct.unpack('<i', k[1])[0] == str_va:
            found.add(taddr + i + 14 + struct.unpack('<i', k[2])[0])
    return found.pop() if len(found) == 1 else None


def rip_refs(blob, taddr, prefix, length, target):
    """Offsets in blob of `prefix disp32 ...` instructions (total `length` bytes) aimed at target."""
    out = []
    for k in re.finditer(re.escape(prefix), blob):
        i = k.start()
        if i + length > len(blob):
            continue
        disp, = struct.unpack_from('<i', blob, i + len(prefix))
        if taddr + i + length + disp == target:
            out.append(i)
    return out


def find_sites(data):
    """[(file offset, original bytes, patched bytes)] or None."""
    secs, text = text_of(data)
    if not text:
        return None
    _, taddr, tsize, toff = text
    blob = data[toff:toff + tsize]
    f = {n: flag_address(data, secs, text, n.encode()) for n in
         ('UseRbxTransportServer', 'UseRbxTransportClient', 'RakNetConnectionFailureFallbackToRbxTransport',
          'ConnectDummyServiceClientEarly')}
    if None in f.values():
        return None
    sites = []

    # transport selection: prologue + `and dil, [UseRbxTransportServer]` (40 22 3d disp32)
    sel = [i - 4 for i in rip_refs(blob, taddr, b'\x40\x22\x3d', 7, f['UseRbxTransportServer'])
           if blob[i - 4:i] in (b'\x55\x48\x89\xe5', b'\x31\xc0\xc3\x90')]
    sel = [i for i in sel if any(i < j < i + 0x20 for j in rip_refs(blob, taddr, b'\x80\x3d', 7, f['UseRbxTransportClient']))]
    if len(sel) != 1:
        return None
    sites.append((toff + sel[0], b'\x55\x48\x89\xe5', b'\x31\xc0\xc3\x90'))

    # fallback: the `cmp byte [flag], 1` (80 3d disp32 01) + jne rel32 (0f 85) that follows the code
    # recording "failureFallbackToRbxTransport" (the flag is tested at other, unrelated places too)
    m = data.find(b'\0failureFallbackToRbxTransport\0')
    sec = next((s for s in secs if s[3] <= m + 1 < s[3] + s[2]), None) if m >= 0 else None
    if not sec:
        return None
    note = rip_refs(blob, taddr, b'\x48\x8d\x35', 7, sec[1] + m + 1 - sec[3])   # lea rsi, "failureFallback..."
    fb = [i for i in rip_refs(blob, taddr, b'\x80\x3d', 7, f['RakNetConnectionFailureFallbackToRbxTransport'])
          if blob[i + 6] in (0x01, 0xff) and blob[i + 7:i + 9] == b'\x0f\x85' and any(0 < i - j < 0x40 for j in note)]
    if len(fb) != 1:
        return None
    sites.append((toff + fb[0] + 6, b'\x01', b'\xff'))

    # dummy connection: `cmp byte [flag], imm` then a short jne, right after it or after one
    # `movzx r13d, byte [rbp+d8]` (44 0f b6 6d d8)
    dummy = []
    for i in rip_refs(blob, taddr, b'\x80\x3d', 7, f['ConnectDummyServiceClientEarly']):
        for j in (i + 7, i + 12):
            if (j == i + 7 or blob[i + 7:i + 11] == b'\x44\x0f\xb6\x6d') and blob[j] in (0x75, 0xeb):
                dummy.append(j)
                break
    if len(dummy) != 2:
        return None
    sites += [(toff + j, b'\x75', b'\xeb') for j in dummy]
    return sites


def main():
    path = next((a for a in sys.argv[1:] if not a.startswith('--')), None)
    if not path:
        sys.exit(__doc__)
    data = bytearray(open(path, 'rb').read())
    sites = find_sites(data)
    if not sites:
        print('not-found')
        return
    states = {('patched' if data[o:o + len(p)] == p else 'original' if data[o:o + len(a)] == a else 'other')
              for o, a, p in sites}
    if 'other' in states:
        print('not-found')
        return
    if '--check' in sys.argv:
        print(states.pop() if len(states) == 1 else 'mixed')
        return
    undo = '--undo' in sys.argv
    for o, a, p in sites:
        want = a if undo else p
        data[o:o + len(want)] = want
    open(path, 'wb').write(data)
    print('original' if undo else 'patched')


if __name__ == '__main__':
    main()
