#!/usr/bin/env python3
"""List X11 windows (recursively) with geometry, map state and name. Usage: x11-windows.py :90"""
import ctypes, ctypes.util, sys

x = ctypes.cdll.LoadLibrary(ctypes.util.find_library('X11'))
x.XOpenDisplay.restype = ctypes.c_void_p
x.XDefaultRootWindow.restype = ctypes.c_ulong
x.XDefaultRootWindow.argtypes = [ctypes.c_void_p]

class Attrs(ctypes.Structure):   # XWindowAttributes prefix we need (layout per Xlib.h)
    _fields_ = [('x', ctypes.c_int), ('y', ctypes.c_int), ('width', ctypes.c_int), ('height', ctypes.c_int),
                ('border_width', ctypes.c_int), ('depth', ctypes.c_int), ('visual', ctypes.c_void_p),
                ('root', ctypes.c_ulong), ('c_class', ctypes.c_int), ('bit_gravity', ctypes.c_int),
                ('win_gravity', ctypes.c_int), ('backing_store', ctypes.c_int), ('backing_planes', ctypes.c_ulong),
                ('backing_pixel', ctypes.c_ulong), ('save_under', ctypes.c_int), ('colormap', ctypes.c_ulong),
                ('map_installed', ctypes.c_int), ('map_state', ctypes.c_int), ('all_event_masks', ctypes.c_long),
                ('your_event_mask', ctypes.c_long), ('do_not_propagate_mask', ctypes.c_long),
                ('override_redirect', ctypes.c_int), ('screen', ctypes.c_void_p)]

d = x.XOpenDisplay(sys.argv[1].encode())
if not d:
    sys.exit(f'cannot open {sys.argv[1]}')
STATE = {0: 'unmapped', 1: 'unviewable', 2: 'VIEWABLE'}

def walk(w, depth):
    root, parent, kids, n = ctypes.c_ulong(), ctypes.c_ulong(), ctypes.POINTER(ctypes.c_ulong)(), ctypes.c_uint()
    if not x.XQueryTree(ctypes.c_void_p(d), ctypes.c_ulong(w), ctypes.byref(root), ctypes.byref(parent), ctypes.byref(kids), ctypes.byref(n)):
        return
    for i in range(n.value):
        c = kids[i]
        a = Attrs()
        x.XGetWindowAttributes(ctypes.c_void_p(d), ctypes.c_ulong(c), ctypes.byref(a))
        name = ctypes.c_char_p()
        x.XFetchName(ctypes.c_void_p(d), ctypes.c_ulong(c), ctypes.byref(name))
        print(f'{"  " * depth}0x{c:x} {a.width}x{a.height}+{a.x}+{a.y} {STATE.get(a.map_state)} class={"InputOutput" if a.c_class == 1 else "InputOnly"} depth={a.depth} {name.value.decode(errors="replace") if name.value else ""}')
        walk(c, depth + 1)

walk(x.XDefaultRootWindow(ctypes.c_void_p(d)), 0)
