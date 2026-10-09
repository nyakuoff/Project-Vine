#!/usr/bin/env python3
"""Turn off Roblox's start-up render throttle in a RobloxPlayer (macOS, x86_64) binary.

Finding credited to MacOBlox (github.com/aubree-lat/MacOBlox): under Darling the start-up throttle
set in RenderJob::setStartupThrottle is never released early (the preRenderJob it waits for does not
exist), so the menu renders slowly until the throttle's ~10 s timeout. Vine's own implementation:

  The function is located through the log string it formats ("...RenderJob::setStartupThrottle: {}"):
  the code that loads that string, the function prologue before it (push rbp; mov rbp,rsp), and a
  single `mov ebx, esi` (89 f3, saving the bool argument) followed by `movzx eax, bl` (0f b6 c3, the
  logged value) before the string load. That instruction becomes `xor ebx, ebx` (31 db): throttle off.
  Anything that doesn't match exactly is left alone.

Usage: startup_throttle.py <RobloxPlayer> [--check | --undo]
Prints one of: patched, original, not-found.
"""
import re, struct, sys

LOG = b'SurfaceController::RenderJob::setStartupThrottle: {}'
ORIG, PATCH = b'\x89\xf3', b'\x31\xdb'


def sections(data):
    ncmds, = struct.unpack_from('<I', data, 16)
    p, out = 32, []
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', data, p)
        if cmd == 0x19:   # LC_SEGMENT_64
            nsects, = struct.unpack_from('<I', data, p + 64)
            for i in range(nsects):
                q = p + 72 + 80 * i
                name = data[q:q + 16].rstrip(b'\0')
                addr, size_, off = struct.unpack_from('<QQI', data, q + 32)
                out.append((name, addr, size_, off))
        p += size
    return out


def find_site(data):
    secs = sections(data)
    m = data.find(LOG)
    if m < 0:
        return None
    start = data.rfind(b'\0', 0, m) + 1
    sec = next((s for s in secs if s[3] <= start < s[3] + s[2]), None)
    text = next((s for s in secs if s[0] == b'__text'), None)
    if not sec or not text:
        return None
    str_va = sec[1] + start - sec[3]
    _, taddr, tsize, toff = text
    blob = data[toff:toff + tsize]
    sites = []
    for k in re.finditer(rb'[\x48\x4c]\x8d[\x05\x0d\x15\x1d\x25\x2d\x35\x3d]', blob):
        i = k.start()
        disp, = struct.unpack_from('<i', blob, i + 3)
        if taddr + i + 7 + disp != str_va:
            continue
        fn = blob.rfind(b'\x55\x48\x89\xe5', max(0, i - 0x200), i)          # prologue before the load
        if fn < 0:
            continue
        body = blob[fn:i]
        hits = [h.start() for h in re.finditer(re.escape(ORIG) + b'|' + re.escape(PATCH), body[:0x40])]
        if len(hits) == 1 and b'\x0f\xb6\xc3' in body[hits[0]:]:              # movzx eax, bl follows
            sites.append(toff + fn + hits[0])
    return sites[0] if len(sites) == 1 else None


def main():
    path = next((a for a in sys.argv[1:] if not a.startswith('--')), None)
    if not path:
        sys.exit(__doc__)
    data = bytearray(open(path, 'rb').read())
    off = find_site(data)
    if off is None:
        print('not-found')
        return
    state = 'patched' if data[off:off + 2] == PATCH else 'original'
    if '--check' in sys.argv:
        print(state)
        return
    want = ORIG if '--undo' in sys.argv else PATCH
    if data[off:off + 2] != want:
        data[off:off + 2] = want
        open(path, 'wb').write(data)
    print('original' if want == ORIG else 'patched')


if __name__ == '__main__':
    main()
