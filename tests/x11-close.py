#!/usr/bin/env python3
"""Ask a top-level window to close, like a window manager's close button (WM_DELETE_WINDOW).
Usage: x11-close.py :90 [window-name=Roblox]"""
import ctypes, ctypes.util, sys

x = ctypes.cdll.LoadLibrary(ctypes.util.find_library('X11'))
x.XOpenDisplay.restype = ctypes.c_void_p
x.XDefaultRootWindow.restype = ctypes.c_ulong
x.XInternAtom.restype = ctypes.c_ulong
d = ctypes.c_void_p(x.XOpenDisplay(sys.argv[1].encode()))
want = (sys.argv[2] if len(sys.argv) > 2 else 'Roblox').encode()

def find(w):
    root, parent, kids, n = ctypes.c_ulong(), ctypes.c_ulong(), ctypes.POINTER(ctypes.c_ulong)(), ctypes.c_uint()
    x.XQueryTree(d, ctypes.c_ulong(w), ctypes.byref(root), ctypes.byref(parent), ctypes.byref(kids), ctypes.byref(n))
    for i in range(n.value):
        name = ctypes.c_char_p()
        x.XFetchName(d, ctypes.c_ulong(kids[i]), ctypes.byref(name))
        if name.value == want:
            return kids[i]
    return None

class ClientMessage(ctypes.Structure):
    _fields_ = [('type', ctypes.c_int), ('serial', ctypes.c_ulong), ('send_event', ctypes.c_int),
                ('display', ctypes.c_void_p), ('window', ctypes.c_ulong), ('message_type', ctypes.c_ulong),
                ('format', ctypes.c_int), ('data', ctypes.c_long * 5), ('pad', ctypes.c_long * 12)]

w = find(x.XDefaultRootWindow(d))
if not w:
    sys.exit('window not found')
ev = ClientMessage(type=33, send_event=1, window=w, message_type=x.XInternAtom(d, b'WM_PROTOCOLS', 0), format=32)
ev.data[0] = x.XInternAtom(d, b'WM_DELETE_WINDOW', 0)
x.XSendEvent(d, ctypes.c_ulong(w), 0, 0, ctypes.byref(ev))
x.XFlush(d)
print(f'sent WM_DELETE_WINDOW to 0x{w:x}')
