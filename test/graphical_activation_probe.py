#!/usr/bin/env python3
"""Probe the existing user bus without opening windows or reading application data.

Requires dbus-python and libX11. Temporary activation files are removed on exit.
Only the explicitly listed display/session values are reported.
"""
import ctypes
import ctypes.util
import json
import os
from pathlib import Path

import tempfile
import time
import uuid

KEYS = ('DISPLAY', 'XAUTHORITY', 'WAYLAND_DISPLAY', 'XDG_SESSION_TYPE',
        'XCURSOR_THEME', 'XCURSOR_SIZE', 'GDK_SCALE', 'GDK_DPI_SCALE')


def activated(output, name):
    import dbus
    bus = dbus.SessionBus()
    result = {key: os.environ.get(key) for key in KEYS}
    x11 = ctypes.CDLL(ctypes.util.find_library('X11'))
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    display = x11.XOpenDisplay(None)
    result['x_connection'] = bool(display)
    if display:
        x11.XCloseDisplay(display)
    Path(output).write_text(json.dumps(result))
    bus.request_name(name)
    time.sleep(2)


def main():
    import dbus
    name = 'org.joy.GraphicalProbe.p' + uuid.uuid4().hex
    services = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'dbus-1/services'
    services.mkdir(parents=True, exist_ok=True)
    scratch = Path(os.environ.get('TMPDIR', str(Path.home() / '.cache')))
    scratch.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='graphical-probe-', dir=scratch) as work:
        script = Path(work) / 'probe.py'
        script.write_text(Path(__file__).read_text())
        output = Path(work) / 'result.json'
        service = services / (name + '.service')
        try:
            service.write_text('[D-BUS Service]\nName=' + name + '\nExec=/usr/bin/python3 ' + str(script) + ' ' + str(output) + ' ' + name + '\n')
            bus = dbus.SessionBus()
            bus.call_blocking('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'ReloadConfig', '', ())
            bus.start_service_by_name(name)
            print(output.read_text())
            time.sleep(2.2)
        finally:
            service.unlink(missing_ok=True)


if __name__ == '__main__':
    import sys
    if len(sys.argv) == 3:
        activated(*sys.argv[1:])
    else:
        main()
