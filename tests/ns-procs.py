#!/usr/bin/env python3
"""Print pids whose user namespace is <ns> or nested (at any depth) inside it.

Darling puts launchd in a user namespace nested under Vine's holder namespace, so matching the
holder's namespace exactly misses it. Walks each process's user-ns ancestry with NS_GET_PARENT.
Optional --prefix DIR: also pids (outside the caller's namespace) whose cwd is inside DIR or whose
DPREFIX is DIR -- Darling processes of this prefix that ended up outside the holder's tree.
Never prints a pid in the caller's own user namespace.
Usage: ns-procs.py 'user:[4026533156]' [--prefix DIR]
"""
import fcntl, os, sys

NS_GET_PARENT = 0xb702
target = sys.argv[1]
prefix = sys.argv[sys.argv.index('--prefix') + 1].rstrip('/') if '--prefix' in sys.argv else None

def of_prefix(pid):
    if not prefix:
        return False
    try:
        cwd = os.readlink(f'/proc/{pid}/cwd')
        if cwd == prefix or cwd.startswith(prefix + '/'):
            return True
        env = open(f'/proc/{pid}/environ', 'rb').read().split(b'\0')
        return ('DPREFIX=' + prefix).encode() in env
    except OSError:
        return False
mine = os.readlink('/proc/self/ns/user')

def nested_in(pid):
    try:
        fd = os.open(f'/proc/{pid}/ns/user', os.O_RDONLY)
    except OSError:
        return False
    try:
        for _ in range(32):
            name = f'user:[{os.fstat(fd).st_ino}]'
            if name == target:
                return True
            if name == mine:
                return False
            try:
                parent = fcntl.ioctl(fd, NS_GET_PARENT)
            except OSError:
                return False   # reached a namespace we may not inspect (or the root)
            os.close(fd)
            fd = parent
        return False
    finally:
        os.close(fd)

for p in os.listdir('/proc'):
    if p.isdigit() and int(p) != os.getpid():
        try:
            if os.readlink(f'/proc/{p}/ns/user') != mine and (nested_in(p) or of_prefix(p)):
                print(p)
        except OSError:
            pass
