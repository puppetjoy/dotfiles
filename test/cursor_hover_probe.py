#!/usr/bin/env python3
"""Briefly sample root/bar cursor pixels, restoring the pointer in finally.

Use only on an authorized live X11 canary. No desktop images or window titles
are captured. The pointer moves twice; no buttons or keyboard events are sent.
"""
import ctypes as C
import hashlib
import json
import subprocess
import time


class CursorImage(C.Structure):
    _fields_ = [('x', C.c_short), ('y', C.c_short), ('width', C.c_ushort),
                ('height', C.c_ushort), ('xhot', C.c_ushort), ('yhot', C.c_ushort),
                ('serial', C.c_ulong), ('pixels', C.POINTER(C.c_ulong)),
                ('atom', C.c_ulong), ('name', C.c_char_p)]


def command(*args):
    return subprocess.check_output(['xdotool', *args], text=True).strip()


def fields(value):
    return dict(line.split('=', 1) for line in value.splitlines() if '=' in line)


def main():
    x11 = C.CDLL('libX11.so.6')
    fixes = C.CDLL('libXfixes.so.3')
    x11.XOpenDisplay.argtypes = [C.c_char_p]
    x11.XOpenDisplay.restype = C.c_void_p
    x11.XFree.argtypes = [C.c_void_p]
    fixes.XFixesGetCursorImage.argtypes = [C.c_void_p]
    fixes.XFixesGetCursorImage.restype = C.POINTER(CursorImage)
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError('Cannot open X display')
    position = fields(command('getmouselocation', '--shell'))
    bar = fields(command('search', '--class', 'taffybar', 'getwindowgeometry', '--shell'))
    width, height = map(int, command('getdisplaygeometry').split())
    result = {}
    try:
        for name, x, y in [('root', width - 1, height - 1),
                           ('bar', int(bar['X']) + int(bar['WIDTH']) // 2,
                            int(bar['Y']) + int(bar['HEIGHT']) // 2)]:
            command('mousemove', '--sync', str(x), str(y))
            time.sleep(0.1)
            pointer = fields(command('getmouselocation', '--shell'))
            image = fixes.XFixesGetCursorImage(display)
            if not image:
                raise RuntimeError('Cannot read cursor image')
            obj = image.contents
            # Xlib uses unsigned long pixels even on 64-bit hosts
            pixels = b''.join((int(obj.pixels[i]) & 0xffffffff).to_bytes(4, 'little')
                              for i in range(obj.width * obj.height))
            result[name] = {'width': obj.width, 'height': obj.height,
                            'name': obj.name.decode() if obj.name else None,
                            'window': pointer['WINDOW'],
                            'sha256': hashlib.sha256(pixels).hexdigest()}
            x11.XFree(image)
    finally:
        command('mousemove', '--sync', position['X'], position['Y'])
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    main()
