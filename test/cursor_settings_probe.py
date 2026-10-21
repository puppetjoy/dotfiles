#!/usr/bin/env python3
"""Read cursor settings and loaded images without changing the desktop."""
import ctypes as C
import hashlib
import json
import os


class Image(C.Structure):
    _fields_ = [(name, C.c_uint) for name in
                ('version', 'size', 'width', 'height', 'xhot', 'yhot', 'delay')] + [
                    ('pixels', C.POINTER(C.c_uint32))]


def main():
    x11 = C.CDLL('libX11.so.6')
    cursor = C.CDLL('libXcursor.so.1')
    x11.XOpenDisplay.argtypes = [C.c_char_p]
    x11.XOpenDisplay.restype = C.c_void_p
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError('Cannot open X display')
    cursor.XcursorGetTheme.argtypes = [C.c_void_p]
    cursor.XcursorGetTheme.restype = C.c_char_p
    cursor.XcursorGetDefaultSize.argtypes = [C.c_void_p]
    cursor.XcursorGetDefaultSize.restype = C.c_int
    cursor.XcursorLibraryLoadImage.argtypes = [C.c_char_p, C.c_char_p, C.c_int]
    cursor.XcursorLibraryLoadImage.restype = C.POINTER(Image)
    cursor.XcursorImageDestroy.argtypes = [C.POINTER(Image)]
    theme = cursor.XcursorGetTheme(display)
    size = cursor.XcursorGetDefaultSize(display)
    result = {'environment': {key: os.environ.get(key) for key in
                             ('XCURSOR_THEME', 'XCURSOR_SIZE', 'GDK_SCALE', 'GDK_DPI_SCALE')},
              'xcursor': {'theme': theme.decode() if theme is not None else None, 'size': size}}
    images = {}
    for name, value in [('resolved', theme), ('empty', b''), ('Breeze', b'breeze_cursors')]:
        image = cursor.XcursorLibraryLoadImage(b'left_ptr', value, size)
        if image:
            obj = image.contents
            pixels = C.string_at(obj.pixels, obj.width * obj.height * 4)
            images[name] = {'width': obj.width, 'height': obj.height,
                            'sha256': hashlib.sha256(pixels).hexdigest()}
            cursor.XcursorImageDestroy(image)
        else:
            images[name] = None
    result['images'] = images
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk, Gdk
    settings = Gtk.Settings.get_default()
    result['gtk'] = {key: settings.get_property(key) for key in
                     ('gtk-cursor-theme-name', 'gtk-cursor-theme-size', 'gtk-xft-dpi')}
    gdk_cursor = Gdk.Cursor.new_from_name(Gdk.Display.get_default(), 'left_ptr')
    pixbuf = gdk_cursor.get_image()
    result['gtk']['image'] = {'width': pixbuf.get_width(), 'height': pixbuf.get_height(),
                               'sha256': hashlib.sha256(pixbuf.get_pixels()).hexdigest()} if pixbuf else None
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    main()
