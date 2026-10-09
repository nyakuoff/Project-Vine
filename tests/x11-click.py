#!/usr/bin/env python3
"""Move the pointer and click via XTest. Usage: x11-click.py :90 X Y [button=1] [--focus]
--focus: first give input focus to the top-level window under X,Y (what a window manager does on
click; Xvfb runs without one, so apps would otherwise never become active)."""
import ctypes, ctypes.util, sys, time

x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library('X11'))
xtst = ctypes.cdll.LoadLibrary(ctypes.util.find_library('Xtst'))
x11.XOpenDisplay.restype = ctypes.c_void_p
d = ctypes.c_void_p(x11.XOpenDisplay(sys.argv[1].encode()))
if not d:
    sys.exit('cannot open display')
args = [a for a in sys.argv[1:] if a != '--focus']
x, y = int(args[1]), int(args[2])
button = int(args[3]) if len(args) > 3 else 1
if '--focus' in sys.argv:
    x11.XDefaultRootWindow.restype = ctypes.c_ulong
    root = x11.XDefaultRootWindow(d)
    child, cx, cy = ctypes.c_ulong(), ctypes.c_int(), ctypes.c_int()
    x11.XTranslateCoordinates(d, ctypes.c_ulong(root), ctypes.c_ulong(root), x, y, ctypes.byref(cx), ctypes.byref(cy), ctypes.byref(child))
    if child.value:
        x11.XSetInputFocus(d, ctypes.c_ulong(child.value), 2, 0)   # RevertToParent, CurrentTime
        x11.XRaiseWindow(d, ctypes.c_ulong(child.value))
        x11.XFlush(d); time.sleep(0.3)
        print(f'focused 0x{child.value:x}')
xtst.XTestFakeMotionEvent(d, -1, x, y, 0)
x11.XFlush(d); time.sleep(0.15)
xtst.XTestFakeButtonEvent(d, button, 1, 0)
x11.XFlush(d); time.sleep(0.08)
xtst.XTestFakeButtonEvent(d, button, 0, 0)
x11.XFlush(d)
print(f'clicked button {button} at {x},{y}')
