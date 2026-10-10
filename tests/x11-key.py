#!/usr/bin/env python3
"""Press and release keys via XTest. Usage: x11-key.py :90 KEYSYM [KEYSYM...]  (e.g. w space Return)"""
import ctypes, ctypes.util, sys, time
x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library('X11'))
xtst = ctypes.cdll.LoadLibrary(ctypes.util.find_library('Xtst'))
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XStringToKeysym.restype = ctypes.c_ulong
d = ctypes.c_void_p(x11.XOpenDisplay(sys.argv[1].encode()))
for name in sys.argv[2:]:
    code = x11.XKeysymToKeycode(d, ctypes.c_ulong(x11.XStringToKeysym(name.encode())))
    xtst.XTestFakeKeyEvent(d, code, 1, 0); x11.XFlush(d); time.sleep(0.08)
    xtst.XTestFakeKeyEvent(d, code, 0, 0); x11.XFlush(d); time.sleep(0.08)
    print(f'key {name} (X keycode {code})')
